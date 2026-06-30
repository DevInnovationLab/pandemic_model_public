function estimate_unmitigated_losses(run_config_path, varargin)
    % Estimate unmitigated pandemic losses.
    %
    %   estimate_unmitigated_losses(run_config_path)
    %   estimate_unmitigated_losses(run_config_path, 'num_chunks', 10, 'array_task_id', 5)
    %
    %   Parameters
    %   ----------
    %   run_config_path : char
    %       Path to the job configuration YAML file.
    %
    %   Optional name-value pairs
    %   ------------------------
    %   num_chunks : numeric
    %       Number of chunks to split simulations into (default: 1).
    %   array_task_id : numeric
    %       SLURM array task ID; when set, only this chunk is run (default: nan).
    %
    %   This function simulates unmitigated pandemic losses using the
    %   configuration provided in the YAML file at run_config_path.
    %   When num_chunks > 1, each chunk writes to raw/chunk_<id>/; if not
    %   running as an array task, chunks are then aggregated into
    %   unmitigated_losses.mat in the job output directory.
    %
    %   Saved vectors (per simulation or per outbreak) use names of the form
    %   *_usd_*: monetized components in dollars. Horizon sums are over simulation
    %   years. social_pv uses weights (1+y)^t/(1+r)^t; growth_path uses (1+y)^t
    %   only; flat_weights uses 1 each year (no r, no y on the path).

    validateattributes(run_config_path, {'char', 'string'}, {'nonempty'});
    run_config_path = char(run_config_path);

    p = inputParser;
    addParameter(p, 'num_chunks', 1, @isnumeric);
    addParameter(p, 'array_task_id', nan, @isnumeric);
    parse(p, varargin{:});
    num_chunks = p.Results.num_chunks;
    array_task_id = p.Results.array_task_id;
    is_array_task = ~isnan(array_task_id);

    % Load job config
    run_config = yaml.loadFile(run_config_path);

    % Create output dir (optional dated subfolder only when add_datetime_to_outdir is true)
    [~, run_config_name, ~] = fileparts(run_config_path);

    if isfield(run_config, 'add_datetime_to_outdir') && run_config.add_datetime_to_outdir
        currentDateTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
        foldername = run_config_name + "_" + char(currentDateTime);
        sim_results_path = fullfile(run_config.outdir, foldername);
    else
        sim_results_path = fullfile(run_config.outdir, run_config_name);
    end

    % Set results paths
    raw_results_path = fullfile(sim_results_path, "raw");
    figure_path = fullfile(sim_results_path, "figures");
    run_config.outdirpath = sim_results_path;
    run_config.rawoutpath = raw_results_path;

    create_folders_recursively(raw_results_path);
    create_folders_recursively(figure_path);

    if isfield(run_config, 'response_threshold') && isfield(run_config, 'response_threshold_path')
        warning('Both ''response_threshold'' and ''response_threshold_path'' are set in the job config. Defaulting to ''response_threshold''.');
    elseif ~isfield(run_config, 'response_threshold') && isfield(run_config, 'response_threshold_path')
        response_threshold_dict = yaml.loadFile(run_config.response_threshold_path);
        run_config.response_threshold = response_threshold_dict.response_threshold;
        run_config.response_threshold_type = response_threshold_dict.response_threshold_type;
    end

    % Get highest false positive rate. Will later have to address if we vary this across scenarios we want to compare.
    run_config.highest_false_positive_rate = max(1 - run_config.improved_ew_precision, 1 - run_config.base_ew_precision);

    [chunks_to_process, chunk_starts, chunk_ends] = get_chunk_boundaries(run_config.num_simulations, num_chunks, array_task_id);

    % Load shared inputs once (same as run_model.m)
    arrival_rates = readtable(run_config.arrival_rates, "TextType", "string");
    pathogen_info = readtable(run_config.pathogen_info, "TextType", "string");
    econ_loss_model = load_econ_loss_model(run_config.econ_loss_model_config);
    pathogen_info = convert_logical_columns(pathogen_info);
    arrival_rates = convert_logical_columns(arrival_rates);

    for i = 1:length(chunks_to_process)
        chunk_idx = chunks_to_process(i);
        if ~is_array_task
            fprintf('Processing chunk %d/%d...\n', chunk_idx, num_chunks);
        end
        chunk_start = chunk_starts(chunk_idx);
        chunk_end = chunk_ends(chunk_idx);
        chunk_range = chunk_start:chunk_end;
        num_simulations = length(chunk_range);

        % Load distributions for this chunk only
        arrival_dist = load_arrival_dist(run_config.arrival_dist_config, [chunk_start, chunk_end]);
        assert(strcmp(arrival_dist.measure, "severity"), ...
               "Please use an arrival distribution estimated on pandemic severities.");
        duration_dist = load_duration_dist(run_config.duration_dist_config, [chunk_start, chunk_end]);

        % Generate base simulation table for this chunk (sim_num 1:num_simulations within chunk)
        [simulation_table, ~, ~] = get_base_simulation_table(arrival_dist, duration_dist, arrival_rates, pathogen_info, run_config.seed + chunk_idx, num_simulations, run_config);
        % False positives are excluded from loss attribution (Lorenz uses outbreak totals below).
        simulation_table = simulation_table(~simulation_table.is_false, :);

        sim_idx = simulation_table.sim_num;
        yr_start = simulation_table.yr_start;
        yr_end = simulation_table.yr_end;
        severity = simulation_table.eff_severity;

        % Index active pandemic years (simulation row, calendar column).
        T = run_config.sim_periods;
        n_sim = num_simulations;
        pandemic_lengths = yr_end - yr_start + 1;
        row_idx = repelem(sim_idx, pandemic_lengths);
        val = repelem(severity, pandemic_lengths);
        col_idx = arrayfun(@(s, e) (s:e)', yr_start, yr_end, 'UniformOutput', false);
        col_idx = vertcat(col_idx{:});
        ind = sub2ind([n_sim, T], row_idx, col_idx);

        duration_rep = repelem(pandemic_lengths, pandemic_lengths);
        deaths = zeros(n_sim, T);
        deaths(ind) = (run_config.P0 / 10000) .* (val ./ duration_rep);

        learning_frac = 10 / 13.8;
        w_social_pv = ((1 + run_config.y) ./ (1 + run_config.r)) .^ (1:T);
        w_productivity_growth = (1 + run_config.y) .^ (1:T);
        w_flat = ones(1, T);

        % Stage 1: annual dollar losses before time weights (same units as discounted model).
        annual_mortality_usd = deaths .* run_config.value_of_death;
        annual_output_usd = zeros(n_sim, T);
        annual_output_usd(ind) = econ_loss_model.predict(val, "severity") .* (run_config.Y0 .* run_config.P0);
        annual_learning_usd = annual_output_usd .* learning_frac;

        % Stage 2: social present-value weights (discount relative to productivity growth).
        annual_mortality_usd_social_pv = annual_mortality_usd .* w_social_pv;
        annual_output_usd_social_pv = annual_output_usd .* w_social_pv;
        annual_learning_usd_social_pv = annual_learning_usd .* w_social_pv;

        sim_horizon_mortality_usd_social_pv = sum(annual_mortality_usd_social_pv, 2);
        sim_horizon_output_usd_social_pv = sum(annual_output_usd_social_pv, 2);
        sim_horizon_learning_usd_social_pv = sum(annual_learning_usd_social_pv, 2);
        sim_horizon_total_usd_social_pv = sim_horizon_mortality_usd_social_pv + sim_horizon_output_usd_social_pv ...
            + sim_horizon_learning_usd_social_pv;

        % Horizon totals under alternative year weights (single core loss path).
        annual_core_usd = annual_mortality_usd + annual_output_usd + annual_learning_usd;
        sim_horizon_total_usd_growth_path = sum(annual_core_usd .* w_productivity_growth, 2);
        sim_horizon_total_usd_flat_weights = sum(annual_core_usd, 2);

        outbreak_yr_start = simulation_table.yr_start;
        outbreak_yr_end = simulation_table.yr_end;
        outbreak_years_active = outbreak_yr_end - outbreak_yr_start + 1;

        sum_w_social_pv = outbreak_year_weight_sum(w_social_pv, outbreak_yr_start, outbreak_yr_end);
        sum_w_flat = outbreak_year_weight_sum(w_flat, outbreak_yr_start, outbreak_yr_end);

        % Per-outbreak totals (same weight-sum logic as annual matrices; see outbreak_year_weight_sum).
        mort_usd_per_pandemic_year = (run_config.P0 / 10000) .* severity .* run_config.value_of_death;
        output_usd_per_pandemic_year = econ_loss_model.predict(severity, "severity") .* (run_config.Y0 .* run_config.P0);

        outbreak_mort_usd_social_pv = mort_usd_per_pandemic_year .* (sum_w_social_pv ./ outbreak_years_active);
        outbreak_output_usd_social_pv = output_usd_per_pandemic_year .* sum_w_social_pv;
        outbreak_learning_usd_social_pv = outbreak_output_usd_social_pv .* learning_frac;
        outbreak_total_usd_social_pv = outbreak_mort_usd_social_pv + outbreak_output_usd_social_pv ...
            + outbreak_learning_usd_social_pv;

        outbreak_mort_usd_flat_weights = mort_usd_per_pandemic_year;
        outbreak_output_usd_flat_weights = output_usd_per_pandemic_year .* sum_w_flat;
        outbreak_learning_usd_flat_weights = outbreak_output_usd_flat_weights .* learning_frac;
        outbreak_total_usd_flat_weights = outbreak_mort_usd_flat_weights + outbreak_output_usd_flat_weights ...
            + outbreak_learning_usd_flat_weights;

        sim_total_deaths = sum(deaths, 2);

        if num_chunks == 1
            % Single chunk: write directly to job output dir
            chunk_outdir = run_config.outdir;
        else
            % Multiple chunks: write to raw/chunk_<id>/
            chunk_outdir = fullfile(raw_results_path, sprintf('chunk_%d', chunk_idx));
            create_folders_recursively(chunk_outdir);
        end

        mat_filename = fullfile(chunk_outdir, 'unmitigated_losses.mat');
        if num_chunks == 1
            save(mat_filename, ...
                'sim_total_deaths', ...
                'sim_horizon_mortality_usd_social_pv', ...
                'sim_horizon_output_usd_social_pv', ...
                'sim_horizon_learning_usd_social_pv', ...
                'sim_horizon_total_usd_social_pv', ...
                'sim_horizon_total_usd_growth_path', ...
                'sim_horizon_total_usd_flat_weights', ...
                'outbreak_total_usd_social_pv', ...
                'outbreak_total_usd_flat_weights', ...
                '-v7.3');
        else
            save(mat_filename, ...
                'sim_total_deaths', ...
                'sim_horizon_mortality_usd_social_pv', ...
                'sim_horizon_output_usd_social_pv', ...
                'sim_horizon_learning_usd_social_pv', ...
                'sim_horizon_total_usd_social_pv', ...
                'sim_horizon_total_usd_growth_path', ...
                'sim_horizon_total_usd_flat_weights', ...
                'outbreak_total_usd_social_pv', ...
                'outbreak_total_usd_flat_weights', ...
                'chunk_idx', ...
                'chunk_start', ...
                'chunk_end', ...
                '-v7.3');
        end

        if ~is_array_task
            fprintf('Completed chunk %d/%d (%.1f%%)\n', chunk_idx, num_chunks, 100 * i / length(chunks_to_process));
        end
    end

    % Save job config once (in job output dir)
    yaml.dumpFile(fullfile(run_config.outdir, "run_config.yaml"), run_config);

    % Aggregate chunk results into single file when not array task and multiple chunks
    if num_chunks > 1 && ~is_array_task
        aggregate_unmitigated_losses(sim_results_path);
        fprintf('Saved aggregated unmitigated losses to %s\n', fullfile(run_config.outdir, 'unmitigated_losses.mat'));
    elseif num_chunks == 1
        fprintf('Saved unmitigated losses to %s\n', fullfile(run_config.outdir, 'unmitigated_losses.mat'));
    elseif is_array_task
        fprintf('Array task %d complete. Run aggregate_unmitigated_losses on each scenario outdir after all tasks finish.\n', array_task_id);
    end
end

function wsum = outbreak_year_weight_sum(w_1_by_T, yr_start, yr_end)
    % Column vector of sums of w(t) over simulation years t = yr_start,...,yr_end (inclusive).
    %
    % Args:
    %   w_1_by_T (1,:): Weight per simulation year (length sim_periods).
    %   yr_start, yr_end (:,1): Integer year indices (same length, one row per outbreak).

    cumw = [0, cumsum(w_1_by_T, 2)];
    wsum = cumw(yr_end).' - cumw(yr_start - 1).';
end

