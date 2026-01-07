function run_job(job_config_path, varargin)
    % Run a job config with parameters for a simulation run
    % Job configs are found in ./config/job_configs

    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'num_chunks', nan, @isnumeric);
    addParameter(p, 'parallel', false, @islogical);
    parse(p, varargin{:});
    num_chunks = p.Results.num_chunks;
    use_parallel = p.Results.parallel;

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);
    if isnan(num_chunks)
        num_chunks = 1;
    end

    % Create output dir
    [~, job_config_name, ~] = fileparts(job_config_path);

    foldername = job_config_name;
    if job_config.add_datetime_to_outdir
        currentDateTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
        foldername = foldername + "_" + char(currentDateTime);
    end
    
    % Set results paths 
    sim_results_path = fullfile(job_config.outdir, foldername);
    raw_results_path = fullfile(sim_results_path, "raw");
    figure_path = fullfile(sim_results_path, "figures");
    job_config.outdirpath = sim_results_path;
    job_config.rawoutpath = raw_results_path;
    
    % Delete folders if they already exist
    if exist(sim_results_path, 'dir')
        rmdir(sim_results_path, 's');
    end

    create_folders_recursively(raw_results_path);
    create_folders_recursively(figure_path);

    scenario_config_paths = dir(fullfile(job_config.scenario_configs, '*.yaml'));

    % Clean scenario configs
    scenario_configs = cell(length(scenario_config_paths), 1);
    for i = 1:length(scenario_config_paths)
        scenario_config_path = fullfile(scenario_config_paths(i).folder, scenario_config_paths(i).name);
        scenario_config = yaml.loadFile(scenario_config_path);
        scenario_configs{i} = clean_scenario_config(scenario_config);
        [~, scenario_name, ~] = fileparts(scenario_config_path);
        scenario_configs{i}.name = scenario_name;
    end

    % Sort scenarios so baseline always runs first
    scenario_names = cellfun(@(x) x.name, scenario_configs, 'UniformOutput', false);
    baseline_idx = find(strcmp(scenario_names, 'baseline'));
    if ~isempty(baseline_idx)
        % Move baseline to first position
        baseline_config = scenario_configs{baseline_idx};
        baseline_config_path = scenario_config_paths(baseline_idx);
        scenario_configs(baseline_idx) = [];
        scenario_config_paths(baseline_idx) = [];
        scenario_configs = [{baseline_config}; scenario_configs];
        scenario_config_paths = [baseline_config_path; scenario_config_paths];
    end

    % Get the highest false positive rate to inflate pandemic arrivals
    highest_false_positive_rate = 0;
    for i = 1:length(scenario_configs)
        scenario_improved_early_warning = scenario_configs{i}.improved_early_warning;
        scenario_false_positive_rate = scenario_improved_early_warning.active .* (1 - scenario_improved_early_warning.precision);
        if scenario_false_positive_rate > highest_false_positive_rate
            highest_false_positive_rate = scenario_false_positive_rate;
        end
    end
    job_config.highest_false_positive_rate = highest_false_positive_rate;

    % Calculate chunk boundaries (no need to load master objects)
    if num_chunks > 1
        chunk_size = ceil(job_config.num_simulations / num_chunks);
        chunk_starts = 1:chunk_size:job_config.num_simulations;
        chunk_ends = [chunk_starts(2:end)-1, job_config.num_simulations];
    else
        num_chunks = 1;
        chunk_starts = 1;
        chunk_ends = job_config.num_simulations;
    end

    % Process chunks - pass config paths, not objects
    if use_parallel && num_chunks > 1
        % Assume we are running on SLURM cluster
        pc = parcluster('local');
        parpool(pc, str2num(getenv('SLURM_CPUS_ON_NODE')));

        % Create DataQueue for progress updates
        q = parallel.pool.DataQueue;
        start_time = tic;
        
        % Use persistent variable in callback
        afterEach(q, @(x) progressCallback(x, num_chunks, start_time));

        parfor chunk_idx = 1:num_chunks
            chunk_config = job_config;
            chunk_config.seed = job_config.seed + chunk_idx;

            run_chunk(chunk_idx, chunk_starts(chunk_idx), chunk_ends(chunk_idx), ...
                      chunk_config, scenario_configs, raw_results_path);

            % Send completion update
            send(q, chunk_idx);
        end

        delete(gcp('nocreate'));
    else
        for chunk_idx = 1:num_chunks
            chunk_config = job_config;
            chunk_config.seed = job_config.seed + chunk_idx;

            run_chunk(chunk_idx, chunk_starts(chunk_idx), chunk_ends(chunk_idx), ...
                      job_config, scenario_configs, raw_results_path);
        end
    end

    % Aggregate relative sums from all chunks
    processed_dir = fullfile(sim_results_path, "processed");
    create_folders_recursively(processed_dir);

    chunk_dirs = dir(fullfile(raw_results_path, 'chunk_*'));

    for i = 1:length(scenario_configs)
        scenario_name = scenario_configs{i}.name;
        if strcmp(scenario_name, 'baseline')
            continue;
        end
        scenario_sum_tables = cell(length(chunk_dirs), 1);
        for j = 1:length(chunk_dirs)
            chunk_dir = fullfile(raw_results_path, chunk_dirs(j).name);
            scenario_sum_table = load(fullfile(chunk_dir, sprintf('%s_relative_sums.mat', scenario_name))).scenario_sum_table;
            scenario_sum_tables{j} = scenario_sum_table;
        end
        all_relative_sums = vertcat(scenario_sum_tables{:});
        save(fullfile(processed_dir, sprintf('%s_relative_sums.mat', scenario_name)), 'all_relative_sums');
    end

    % Save job and scenario params
    out_params = job_config;
    out_params.scenarios = struct();
        
    for i = 1:length(scenario_configs)
        % Load scenario config
        scenario_config_path = fullfile(scenario_config_paths(i).folder, scenario_config_paths(i).name);
        [~, scenario_name, ~] = fileparts(scenario_config_path);
        scenario_config = scenario_configs{i};
        out_params.scenarios.(scenario_name) = scenario_config;
    end 

    config_outpath = fullfile(sim_results_path, "job_config.yaml");
    yaml.dumpFile(config_outpath, out_params);
end


% Add this helper function at the end of the file (outside run_job)
function progressCallback(chunk_idx, total_chunks, start_time)
    persistent completed
    if isempty(completed)
        completed = 0;
    end
    
    completed = completed + 1;
    elapsed = toc(start_time);
    if completed > 0
        rate = completed / elapsed;
        remaining = (total_chunks - completed) / rate;
        fprintf('[%s] Chunk %d/%d completed (%.1f%%) - Elapsed: %.1fs, ETA: %.1fs\n', ...
                datestr(now, 'HH:MM:SS'), completed, total_chunks, ...
                100*completed/total_chunks, elapsed, remaining);
    end
end


function run_chunk(chunk_idx, chunk_start, chunk_end, job_config, scenario_configs, raw_results_path)

    % Load chunk-specific distributions from files
    chunk_dir = fullfile(raw_results_path, sprintf('chunk_%d', chunk_idx));
    create_folders_recursively(chunk_dir);
    chunk_range = chunk_start:chunk_end;
    num_simulations = length(chunk_range);
    

    arrival_dist = load_arrival_dist(job_config.arrival_dist_config, ...
                                job_config.highest_false_positive_rate, ...
                                [chunk_start, chunk_end]);
    duration_dist = load_duration_dist(job_config.duration_dist_config, [chunk_start, chunk_end]);

    arrival_rates = readtable(job_config.arrival_rates, "TextType", "string");
    pathogen_info = readtable(job_config.pathogen_info, "TextType", "string");
    ptrs_pathogen = readtable(job_config.ptrs_pathogen, "TextType", "string");
    prototype_effect_ptrs = readtable(job_config.prototype_effect_ptrs, "TextType", "string");
    response_rd_timelines = readtable(job_config.rd_timelines, "TextType", "string"); % Currently deprecated but keeping logic in case we want to return
    econ_loss_model = load_econ_loss_model(job_config.econ_loss_model_config);

    % Convert logical columns in both arrival_rates and pathogen_info tables
    pathogen_info = convert_logical_columns(pathogen_info);
    arrival_rates = convert_logical_columns(arrival_rates);

    response_threshold_dict = yaml.loadFile(job_config.response_threshold_path);
    job_config.response_threshold = response_threshold_dict.response_threshold;

    % Generate base simulation table for this chunk
    [base_simulation_table, total_removed, total_trimmed] = ...
        get_base_simulation_table(arrival_dist, duration_dist, ...
                                  arrival_rates, pathogen_info, ...
                                  job_config.seed, job_config);

    % Save chunk base table
    chunk_base_path = fullfile(chunk_dir, 'base_simulation_table.mat');
    save(chunk_base_path, 'base_simulation_table', 'total_removed', 'total_trimmed');

    % Process baseline first
    baseline_idx = find(strcmp(cellfun(@(x) x.name, scenario_configs, 'UniformOutput', false), 'baseline'), 1);
    if ~isempty(baseline_idx)
        % Update params for this scenario
        simulation_params = update_params(job_config, scenario_configs{baseline_idx}, arrival_rates);
        
        % Get scenario simulation table
        scenario_simulation_table = get_scenario_simulation_table(base_simulation_table, ...
            ptrs_pathogen, prototype_effect_ptrs, response_rd_timelines, simulation_params);
        
        % Run simulation
        [annual_results_baseline, scenario_pandemic_table] = ...
            event_list_simulation(scenario_simulation_table, econ_loss_model, num_simulations, simulation_params);

        baseline_chunk_path = fullfile(chunk_dir, 'baseline_annual.mat');
        save(baseline_chunk_path, 'annual_results_baseline');

        if ~strcmp(job_config.save_mode, "light")
            save_pandemic_table(scenario_pandemic_table, 'baseline', chunk_dir, job_config.pandemic_table_out);
        end
    else
        error('Baseline scenario required but not found');
    end

    % Process other scenarios
    for i = 1:length(scenario_configs)
        scenario_name = scenario_configs{i}.name;
        
        if strcmp(scenario_name, 'baseline')
            continue;
        end

        % Run simulation
        simulation_params = update_params(job_config, scenario_configs{i}, arrival_rates);
        scenario_simulation_table = get_scenario_simulation_table(base_simulation_table, ...
            ptrs_pathogen, prototype_effect_ptrs, response_rd_timelines, simulation_params);
        
        [annual_results, scenario_pandemic_table] = ...
            event_list_simulation(scenario_simulation_table, econ_loss_model, num_simulations, simulation_params);

        [scenario_sum_table, relative_annual_results] = get_relative_results(...
            annual_results, annual_results_baseline, num_simulations);

        % Save chunk results
        chunk_sum_path = fullfile(chunk_dir, ...
            sprintf('%s_relative_sums.mat', scenario_name));
        save(chunk_sum_path, 'scenario_sum_table');
        
        if ~strcmp(job_config.save_mode, "light")
            annual_rel_path = fullfile(chunk_dir, ...
                sprintf('%s_relative_annual.mat', scenario_name));
            save(annual_rel_path, '-struct', 'relative_annual_results');

            save_pandemic_table(scenario_pandemic_table, scenario_name, chunk_dir, job_config.pandemic_table_out);
        end
    end
end


function [scenario_sum_table, relative_annual_results] = ...
    get_relative_results(annual_results, annual_results_baseline, num_simulations)
    % Compute relative results
    result_names = fieldnames(annual_results);
    sum_horizons = [10, 30, 50];
    
    num_results = length(result_names);
    num_horizons = length(sum_horizons) + 1;
    num_cols = num_results * num_horizons;
    scenario_sum_table = table('Size', [num_simulations, num_cols], ...
                            'VariableTypes', repmat({'double'}, 1, num_cols));
    
    relative_annual_results = struct();
    
    for j = 1:length(result_names)
        result = result_names{j};
        relative_annual_result = annual_results.(result) - annual_results_baseline.(result);
        relative_annual_results.(result) = relative_annual_result;
        
        col_idx = (j-1) * num_horizons + 1;
        for k = 1:length(sum_horizons)
            sum_horizon = sum_horizons(k);
            relative_result_sum = sum(relative_annual_result(:, 1:sum_horizon), 2);
            varname = strcat(result, '_', num2str(sum_horizon), '_years');
            scenario_sum_table.Properties.VariableNames{col_idx} = varname;
            scenario_sum_table{:, col_idx} = relative_result_sum;
            col_idx = col_idx + 1;
        end
        
        relative_result_whole_horizon_sum = sum(relative_annual_result, 2);
        varname = strcat(result, '_full');
        scenario_sum_table.Properties.VariableNames{col_idx} = varname;
        scenario_sum_table{:, col_idx} = relative_result_whole_horizon_sum;
    end
end


function save_pandemic_table(pandemic_table, scenario_name, outdir, outstyle)

    if strcmp(outstyle, "none")
        return;
    elseif strcmp(outstyle, "skinny")
        remove_cols = {'mrna_vax_state', 'trad_vax_state', 'ufv_vax_state', ...
                       'natural_dur', 'yr_end', 'severity', 'rd_state', 'u_deaths'};
        pandemic_table(:, remove_cols) = [];
    elseif strcmp(outstyle, "full")
        % Do nothing
    else
        warning("Invalid pandemic_table_out option: %s. Must be 'none', 'skinny', or 'full'.", outstyle);
    end

    fp = fullfile(outdir, sprintf('%s_pandemic_table.mat', scenario_name));
    save(fp, 'pandemic_table', '-v7.3');
    fprintf('Saved pandemic table to %s\n', fp);
end


function updated_params = update_params(job_config, scenario_config, arrival_rates)

    % New parameters override base parameters
    updated_params = job_config;
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

    % Set advance capacity
    if updated_params.advance_capacity.share_target_advance_capacity == 0
        updated_params.theta = 0;
    end

    [z_m, z_o] = get_adv_capacity(updated_params); % get target advance capacity
    updated_params.z_m = z_m;
    updated_params.z_o = z_o;

    % Set improved early warning
    updated_params.improved_early_warning = scenario_config.improved_early_warning;

    % Set universal flu R&D
    updated_params.universal_flu_rd = scenario_config.universal_flu_rd;
end


function tbl = convert_logical_columns(tbl)
    %CONVERT_LOGICAL_COLUMNS Converts 'TRUE'/'FALSE'/NA columns to numeric 1/0/NaN.
    %
    %   tbl = CONVERT_LOGICAL_COLUMNS(tbl) converts any columns in the table tbl
    %   that contain 'TRUE'/'FALSE'/NA values (as strings or logicals) to numeric
    %   columns with 1 for TRUE, 0 for FALSE, and NaN for NA/missing.
    %
    %   This is useful for harmonizing imported CSV data where logical columns
    %   may be read as strings.
    %
    %   Parameters
    %   ----------
    %   tbl : table
    %       Input table with possible logical columns as strings.
    %
    %   Returns
    %   -------
    %   tbl : table
    %       Table with logical columns converted to numeric.
    
    logical_colnames = {'has_prototype', 'airborne'};
    for i = 1:length(logical_colnames)
        col = logical_colnames{i};
        if ismember(col, tbl.Properties.VariableNames)
            col_data = tbl.(col);
            col_str = string(col_data);
            col_numeric = nan(height(tbl), 1);
            col_numeric(strcmpi(col_str, "TRUE")) = 1;
            col_numeric(strcmpi(col_str, "FALSE")) = 0;
            col_numeric(strcmpi(col_str, "NA")) = 0;
            tbl.(col) = col_numeric;
        end
    end
end