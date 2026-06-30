function run_model(run_config_path, varargin)
    % Run a single model config locally or as one SLURM array task.
    %
    % Loads the run config, creates output directories, splits simulations into chunks,
    % and runs the core simulation pipeline for each assigned chunk. For local runs all
    % chunks execute sequentially; for SLURM only the assigned chunk runs.
    %
    % Args:
    %   run_config_path  Path to the single run YAML config file.
    %
    % Name-value parameters:
    %   num_chunks              Number of chunks to split simulations across (default: 1).
    %   array_task_id           SLURM task ID (1-based); if set, processes only that chunk
    %                           (default: NaN -- runs all chunks sequentially).
    %   baseline_mode           Baseline handling mode:
    %                             - 'full' (default): simulate baseline and other scenarios
    %                             - 'baseline_only': simulate baseline only
    %                             - 'skip_baseline': reuse baseline from baseline_reference_raw
    %   baseline_reference_raw  Path to raw directory containing chunk_*/status_quo_annual.mat
    %                           used only when baseline_mode = 'skip_baseline'.
    %
    % Example:
    %   run_model('config/run_configs/base.yaml', 'num_chunks', 10)
    %   run_model('config/run_configs/base.yaml', 'array_task_id', 3, 'num_chunks', 10)
    
    p = inputParser;
    addParameter(p, 'num_chunks', 1, @isnumeric);
    addParameter(p, 'array_task_id', nan, @isnumeric);  % If set, run as array task
    addParameter(p, 'baseline_mode', 'full', @(x) ischar(x) || isStringScalar(x));
    addParameter(p, 'baseline_reference_raw', '', @(x) ischar(x) || isStringScalar(x));
    parse(p, varargin{:});
    
    num_chunks = p.Results.num_chunks;
    array_task_id = p.Results.array_task_id;
    baseline_mode = char(string(p.Results.baseline_mode));
    baseline_reference_raw = char(string(p.Results.baseline_reference_raw));
    validate_baseline_mode_args(baseline_mode, baseline_reference_raw);
    
    is_array_task = ~isnan(array_task_id);
    
    % Load job config
    run_config = yaml.loadFile(run_config_path);
    [~, run_config_name, ~] = fileparts(run_config_path);
    sim_results_path = fullfile(run_config.outdir, run_config_name);
    raw_results_path = fullfile(sim_results_path, "raw");
    figure_path = fullfile(sim_results_path, "figures");
    run_config.outdirpath = sim_results_path;
    run_config.rawoutpath = raw_results_path;

    create_folders_recursively(sim_results_path);
    create_folders_recursively(raw_results_path);
    create_folders_recursively(figure_path);

    % Load scenario configs from directory, explicit list, or regex-expanded list.
    scenario_config_paths = resolve_scenario_config_paths(run_config.scenario_configs);
    scenario_configs = cell(length(scenario_config_paths), 1);
    for i = 1:length(scenario_config_paths)
        scenario_config_path = scenario_config_paths{i};
        scenario_config = yaml.loadFile(scenario_config_path);
        scenario_configs{i} = clean_scenario_config(scenario_config);
        [~, scenario_name, ~] = fileparts(scenario_config_path);
        scenario_configs{i}.name = scenario_name;
    end
    
    % Get highest false positive rate. Will later have to address if we vary this across scenarios we want to compare.
    run_config.highest_false_positive_rate = max(1 - run_config.improved_ew_precision, 1 - run_config.base_ew_precision);

    % Get chunk boundaries
    [chunks_to_process, chunk_starts, chunk_ends] = get_chunk_boundaries(run_config.num_simulations, num_chunks, array_task_id);
    
    % Process chunks
    for i = 1:length(chunks_to_process)
        chunk_idx = chunks_to_process(i);
        if ~is_array_task
            fprintf('Processing chunk %d/%d...\n', chunk_idx, num_chunks);
        end
        chunk_config = run_config;
        chunk_config.seed = run_config.seed + chunk_idx;
        
        run_chunk(chunk_idx, chunk_starts(chunk_idx), chunk_ends(chunk_idx), ...
                    chunk_config, scenario_configs, raw_results_path, baseline_mode, baseline_reference_raw);
        
        if ~is_array_task
            fprintf('Completed chunk %d/%d (%.1f%%)\n', chunk_idx, num_chunks, 100*chunk_idx/num_chunks);
        end
    end

    % Add scenarios to config
    scenarios = struct();
    for i = 1:length(scenario_configs)
	    scenarios.(scenario_configs{i}.name) = scenario_configs{i};
    end
    
    run_config.scenarios = scenarios;
    run_config.scenario_config_paths_resolved = scenario_config_paths;
    yaml.dumpFile(fullfile(sim_results_path, 'run_config.yaml'), run_config);
    if ~is_array_task
	    fprintf('All chunks completed!\n');
    end
end


function run_chunk(chunk_idx, chunk_start, chunk_end, run_config, scenario_configs, ...
    raw_results_path, baseline_mode, baseline_reference_raw)

    % Load chunk-specific distributions from files
    chunk_dir = fullfile(raw_results_path, sprintf('chunk_%d', chunk_idx));
    create_folders_recursively(chunk_dir);
    chunk_range = chunk_start:chunk_end;
    num_simulations = length(chunk_range);

    arrival_dist = load_arrival_dist(run_config.arrival_dist_config, [chunk_start, chunk_end]);
    duration_dist = load_duration_dist(run_config.duration_dist_config, [chunk_start, chunk_end]);

    arrival_rates = readtable(run_config.arrival_rates, "TextType", "string");
    pathogen_info = readtable(run_config.pathogen_info, "TextType", "string");
    ptrs_pathogen = readtable(run_config.ptrs_pathogen, "TextType", "string");
    prototype_effect_ptrs = readtable(run_config.prototype_effect_ptrs, "TextType", "string");
    econ_loss_model = load_econ_loss_model(run_config.econ_loss_model_config);

    % Convert logical columns in both arrival_rates and pathogen_info tables
    pathogen_info = convert_logical_columns(pathogen_info);
    arrival_rates = convert_logical_columns(arrival_rates);

    response_threshold_dict = yaml.loadFile(run_config.response_threshold_path);
    run_config.response_threshold = response_threshold_dict.response_threshold;
    run_config.response_threshold_type = response_threshold_dict.response_threshold_type;

    % Generate base simulation table for this chunk (sim_num is 1:num_simulations within chunk)
    [base_simulation_table, total_removed, total_trimmed] = ...
        get_base_simulation_table(arrival_dist, duration_dist, ...
                                  arrival_rates, pathogen_info, ...
                                  run_config.seed, num_simulations, run_config);

    response_simulation_table = base_simulation_table(base_simulation_table.response_outbreak, :);

    % Save base table with global sim_num for compare_exceedances; simulation uses local sim_num
    base_simulation_table.sim_num = base_simulation_table.sim_num + chunk_start - 1;
    chunk_base_path = fullfile(chunk_dir, 'base_simulation_table.mat');
    save(chunk_base_path, 'base_simulation_table', 'total_removed', 'total_trimmed');
    clear base_simulation_table;
    clear total_removed;
    clear total_trimmed;

    % Process status quo first
    status_quo_idx = find(strcmp(cellfun(@(x) x.name, scenario_configs, 'UniformOutput', false), 'status_quo'), 1);
    if isempty(status_quo_idx)
        error('Status-quo scenario required but not found');
    end
    
    if strcmp(baseline_mode, 'skip_baseline')
        annual_results_baseline = load_reused_baseline_chunk(baseline_reference_raw, chunk_idx);
    else
        % Update params for status-quo scenario
        simulation_params = update_params(run_config, scenario_configs{status_quo_idx}, arrival_rates);
        
        % Get scenario simulation table
        scenario_simulation_table = get_scenario_simulation_table(response_simulation_table, ...
            ptrs_pathogen, prototype_effect_ptrs, simulation_params);

        % Run status-quo simulation
        [annual_results_baseline, scenario_pandemic_table] = ...
            event_list_simulation(scenario_simulation_table, econ_loss_model, num_simulations, simulation_params);
        
        % Use global sim_num so compare_exceedances can merge chunks correctly
        scenario_pandemic_table.sim_num = scenario_pandemic_table.sim_num + chunk_start - 1;
        
        status_quo_chunk_path = fullfile(chunk_dir, 'status_quo_annual.mat');
        save(status_quo_chunk_path, 'annual_results_baseline', '-v7.3');

        % Save status-quo sums in a table (same layout as relative_sums); aggregate_results vertcats across chunks
        baseline_sums = get_baseline_sums_table(annual_results_baseline, num_simulations);
        bs_mat = fullfile(chunk_dir, 'status_quo_sums.mat');
        save(bs_mat, 'baseline_sums', '-v7.3');
        
        save_pandemic_table(scenario_pandemic_table, 'status_quo', chunk_dir, run_config.pandemic_table_out);
    end

    if strcmp(baseline_mode, 'baseline_only')
        return;
    end

    % Process other scenarios
    for i = 1:length(scenario_configs)
        scenario_name = scenario_configs{i}.name;
        
        if strcmp(scenario_name, 'status_quo')
            continue;
        end

        % Run simulation
        simulation_params = update_params(run_config, scenario_configs{i}, arrival_rates);
        scenario_simulation_table = get_scenario_simulation_table(response_simulation_table, ...
            ptrs_pathogen, prototype_effect_ptrs, simulation_params);
        
        [annual_results, scenario_pandemic_table] = ...
            event_list_simulation(scenario_simulation_table, econ_loss_model, num_simulations, simulation_params);

        % Use global sim_num so downstream scripts can merge chunks correctly
        scenario_pandemic_table.sim_num = scenario_pandemic_table.sim_num + chunk_start - 1;

        [scenario_sum_table, relative_annual_results] = get_relative_results(...
            annual_results, annual_results_baseline, num_simulations, run_config.tolerance);

        % Save chunk results
        chunk_sum_path = fullfile(chunk_dir, sprintf('%s_relative_sums.mat', scenario_name));
        save(chunk_sum_path, 'scenario_sum_table', '-v7.3');

        if ~strcmp(run_config.save_mode, "light")
            annual_rel_path = fullfile(chunk_dir, ...
                sprintf('%s_relative_annual.mat', scenario_name));
            save(annual_rel_path, '-struct', 'relative_annual_results', '-v7.3');

            save_pandemic_table(scenario_pandemic_table, scenario_name, chunk_dir, run_config.pandemic_table_out);
        end
    end
end


function annual_results_baseline = load_reused_baseline_chunk(baseline_reference_raw, chunk_idx)
    % Load status-quo annual results from a previously completed raw/chunk_* directory.
    chunk_dir = fullfile(baseline_reference_raw, sprintf('chunk_%d', chunk_idx));
    fp = fullfile(chunk_dir, 'status_quo_annual.mat');
    if ~isfile(fp)
        error('Baseline reference chunk file not found: %s', fp);
    end
    S = load(fp, 'annual_results_baseline');
    annual_results_baseline = S.annual_results_baseline;
end


function validate_baseline_mode_args(baseline_mode, baseline_reference_raw)
    allowed_modes = {'full', 'baseline_only', 'skip_baseline'};
    if ~any(strcmp(baseline_mode, allowed_modes))
        error('Invalid baseline_mode "%s" (use full, baseline_only, or skip_baseline).', baseline_mode);
    end

    if strcmp(baseline_mode, 'skip_baseline')
        if isempty(baseline_reference_raw)
            error('baseline_reference_raw is required when baseline_mode is skip_baseline.');
        end
        if ~isfolder(baseline_reference_raw)
            error('baseline_reference_raw directory not found: %s', baseline_reference_raw);
        end
    end
end


function [scenario_sum_table, relative_annual_results] = ...
    get_relative_results(annual_results, annual_results_baseline, num_simulations, tolerance)
    result_names = fieldnames(annual_results);
    relative_annual_results = struct();
    for j = 1:length(result_names)
        result = result_names{j};
        diff = annual_results.(result) - annual_results_baseline.(result);
        diff(abs(diff) < tolerance) = 0; % Addressing numerical noise
        relative_annual_results.(result) = diff;
    end
    scenario_sum_table = make_horizon_sums_table(relative_annual_results, [10, 30, 50], num_simulations);
end


function save_pandemic_table(pandemic_table, scenario_name, outdir, outstyle)

    if strcmp(outstyle, "none")
        return;
    elseif strcmp(outstyle, "skinny")
        remove_cols = {'mrna_vax_state', 'trad_vax_state', 'ufv_vax_state', ...
                       'sampled_duration_years', 'sampled_duration_months', ...
                       'yr_end', 'severity', 'rd_state', 'u_deaths'};
        pandemic_table(:, remove_cols) = [];
    elseif strcmp(outstyle, "full")
        % Do nothing
    else
        error("Invalid pandemic_table_out: '%s' (use none, skinny, or full).", outstyle);
    end

    fp = fullfile(outdir, sprintf('%s_pandemic_table.mat', scenario_name));
    save(fp, 'pandemic_table', '-v7.3');
end


function baseline_sums = get_baseline_sums_table(annual_results_baseline, num_simulations)
    % Build horizon-sums table for baseline annual results.
    % Same column layout as get_relative_results. aggregate_results vertcats across chunks.
    baseline_sums = make_horizon_sums_table(annual_results_baseline, [10, 30, 50], num_simulations);
end


function updated_params = update_params(run_config, scenario_config, arrival_rates)

    % New parameters override base parameters
    updated_params = run_config;
    if ~isempty(scenario_config)
        fns = fieldnames(scenario_config);
        for k=1:numel(fns)
            updated_params.(fns{k}) = scenario_config.(fns{k});
        end
    end

    % Set pathogen family params.
    invest_strategy = scenario_config.neglected_pathogen_rd.strategy;
    updated_params.num_pathogens_researched = scenario_config.neglected_pathogen_rd.num;
    [pathogens_with_baseline_prototype, new_invested_pathogens] = parse_neglected_pathogen_rd(scenario_config.neglected_pathogen_rd, arrival_rates);
    updated_params.pathogens_with_baseline_prototype = pathogens_with_baseline_prototype;
    updated_params.new_invested_pathogens = new_invested_pathogens;

    if strcmp(invest_strategy, "top") || strcmp(invest_strategy, "random")
        updated_params.prototype_RD = true;
    else
        updated_params.prototype_RD = false;
    end

    updated_params.prototype_RD_spend = updated_params.advance_RD_cost_per_pathogen .* updated_params.num_pathogens_researched;
    updated_params.ufv_spend = updated_params.advance_RD_cost_per_pathogen .* updated_params.univ_flu_cost_multiplier;

    % Set advance capacy)
    if updated_params.advance_capacity.share_target_advance_capacity == 0
        updated_params.theta = 0;
    end

    [z_m, z_o] = get_adv_capacity(updated_params);
    updated_params.z_m = z_m;
    updated_params.z_o = z_o;

    % Scenario structs carry activation and program shape only; precision, recall, and
    % initial_share_ufv are read from the merged params via helpers where used.
    updated_params.improved_early_warning = scenario_config.improved_early_warning;
    updated_params.universal_flu_rd = scenario_config.universal_flu_rd;
end

