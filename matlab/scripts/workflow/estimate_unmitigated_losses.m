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

    validateattributes(run_config_path, {'char', 'string'}, {'nonempty'});
    run_config_path = char(run_config_path);

    p = inputParser;
    addParameter(p, 'num_chunks', 1, @isnumeric);
    addParameter(p, 'array_task_id', nan, @isnumeric);
    parse(p, varargin{:});
    num_chunks = p.Results.num_chunks;
    array_task_id = p.Results.array_task_id;
    is_array_task = ~isnan(array_task_id);

    % Load and validate job config
    run_config = yaml.loadFile(run_config_path);
    validate_run_config(run_config, 'estimate_unmitigated_losses');

    % Create output dir
    [~, run_config_name, ~] = fileparts(run_config_path);

    foldername = run_config_name;
    if isfield(run_config, 'add_datetime_to_outdir') && run_config.add_datetime_to_outdir
        currentDateTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
        foldername = foldername + "_" + char(currentDateTime);
    end

    % Set results paths 
    sim_results_path = fullfile(run_config.outdir, foldername);
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
        arrival_dist = load_arrival_dist(run_config.arrival_dist_config, 0, [chunk_start, chunk_end]);
        assert(strcmp(arrival_dist.measure, "severity"), ...
               "Please use an arrival distribution estimated on pandemic severities.");
        duration_dist = load_duration_dist(run_config.duration_dist_config, [chunk_start, chunk_end]);

        % Generate base simulation table for this chunk (sim_num 1:num_simulations within chunk)
        [simulation_table, ~, ~] = get_base_simulation_table(arrival_dist, duration_dist, arrival_rates, pathogen_info, run_config.seed + chunk_idx, num_simulations, run_config);

        sim_idx = simulation_table.sim_num;
        yr_start = simulation_table.yr_start;
        yr_end = simulation_table.yr_end;
        severity = simulation_table.eff_severity;

        % Build severity matrix
        severity_mat = zeros([num_simulations, run_config.sim_periods]);
        pandemic_lengths = yr_end - yr_start + 1;
        row_idx = repelem(sim_idx, pandemic_lengths);
        val = repelem(severity, pandemic_lengths);
        col_idx = arrayfun(@(s, e) (s:e)', yr_start, yr_end, 'UniformOutput', false);
        col_idx = vertcat(col_idx{:});
        ind = sub2ind(size(severity_mat), row_idx, col_idx);
        severity_mat(ind) = val;

        % Compute deaths using intensity, without allocating another matrix.
        duration_rep = repelem(pandemic_lengths, pandemic_lengths);
        deaths = zeros(size(severity_mat));
        deaths(ind) = (run_config.P0 / 10000) .* (val ./ duration_rep);

        discount_factor = ((1 + run_config.y) ./ (1 + run_config.r)) .^ (1:run_config.sim_periods);

        mortality_losses = deaths .* run_config.value_of_death .* discount_factor;

        output_losses = zeros(size(severity_mat));
        output_losses(ind) = econ_loss_model.predict(val, "severity") .* (run_config.Y0 .* run_config.P0);
        output_losses = output_losses .* discount_factor;

        learning_losses = output_losses .* (10 / 13.8);
        total_losses = mortality_losses + output_losses + learning_losses;

        % Undiscounted social losses (no discount factor applied)
        growth_factor = (1 + run_config.y) .^ (1:run_config.sim_periods);
        mortality_losses_undiscounted = deaths .* run_config.value_of_death .* growth_factor;
        output_losses_undiscounted = zeros(size(severity_mat));
        output_losses_undiscounted(ind) = econ_loss_model.predict(val, "severity") .* (run_config.Y0 .* run_config.P0);
        output_losses_undiscounted = output_losses_undiscounted .* growth_factor;
        learning_losses_undiscounted = output_losses_undiscounted .* (10 / 13.8);
        total_losses_undiscounted = mortality_losses_undiscounted + output_losses_undiscounted + learning_losses_undiscounted;

        % Outbreak-level total losses (for Lorenz curve etc.)
        outbreak_is_false_positive = simulation_table.is_false;
        outbreak_yr_start = simulation_table.yr_start;
        outbreak_yr_end = simulation_table.yr_end;
        outbreak_actual_dur = outbreak_yr_end - outbreak_yr_start + 1;

        % Vectorized discount-factor sums over each outbreak's active years
        disc_cum = [0, cumsum(discount_factor)];
        disc_sum = disc_cum(outbreak_yr_end)' - disc_cum(outbreak_yr_start - 1)';

        % Mortality component: matches annual matrix logic aggregated over years
        mortality_total_per_outbreak = (run_config.P0 / 10000) .* severity .* run_config.value_of_death .* (disc_sum ./ outbreak_actual_dur);

        % Output component: per-year loss from econ_loss_model, summed over years
        output_per_year = econ_loss_model.predict(severity, "severity") .* (run_config.Y0 .* run_config.P0);
        output_total_per_outbreak = output_per_year .* disc_sum;

        % Learning component: proportional to output losses
        learning_total_per_outbreak = output_total_per_outbreak .* (10 / 13.8);

        outbreak_total_loss = mortality_total_per_outbreak + output_total_per_outbreak + learning_total_per_outbreak;

        % Simulation-wide sums (sum over years) for aggregation and downstream; avoids storing full annual matrices.
        sim_total_deaths = sum(deaths, 2);
        sim_mortality_loss = sum(mortality_losses, 2);
        sim_output_loss = sum(output_losses, 2);
        sim_learning_loss = sum(learning_losses, 2);
        sim_total_loss = sum(total_losses, 2);
        sim_total_loss_undiscounted = sum(total_losses_undiscounted, 2);

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
                'sim_mortality_loss', ...
                'sim_output_loss', ...
                'sim_learning_loss', ...
                'sim_total_loss', ...
                'sim_total_loss_undiscounted', ...
                'outbreak_is_false_positive', ...
                'outbreak_total_loss', ...
                '-v7.3');
        else
            save(mat_filename, ...
                'sim_total_deaths', ...
                'sim_mortality_loss', ...
                'sim_output_loss', ...
                'sim_learning_loss', ...
                'sim_total_loss', ...
                'sim_total_loss_undiscounted', ...
                'outbreak_is_false_positive', ...
                'outbreak_total_loss', ...
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

