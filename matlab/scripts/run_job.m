function run_job(job_config_path)

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);
    
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

    create_folders_recursively(raw_results_path);
    create_folders_recursively(figure_path);

    % Handle folderpath input for scenario configs
    if isfolder(job_config.scenario_configs)
        scenario_config_paths = dir(fullfile(job_config.scenario_configs, '*.yaml'));
    elseif isfile(job_config.scenario_configs)
        scenario_config_paths = dir(fullfile(job_config.scenario_configs));
    else
        print("Improper scenario config")
    end

    % Clean scenario configs
    scenario_configs = cell(length(scenario_config_paths), 1);
    for i = 1:length(scenario_config_paths)
        scenario_config_path = fullfile(scenario_config_paths(i).folder, scenario_config_paths(i).name);
        scenario_config = yaml.loadFile(scenario_config_path);
        scenario_configs{i} = clean_scenario_config(scenario_config);
        [~, scenario_name, ~] = fileparts(scenario_config_path);
        scenario_configs{i}.name = scenario_name;
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

    % Load inputs from files
    arrival_dist = load_arrival_dist(job_config.arrival_dist_config, highest_false_positive_rate);
    duration_dist = load_duration_dist(job_config.duration_dist_config);
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

    % Generate base simulation to be used across scenarios
    [base_simulation_table, total_removed, total_trimmed] = get_base_simulation_table(arrival_dist, duration_dist, ...
                                                                                      arrival_rates, pathogen_info, ...
                                                                                      job_config.seed, job_config);

    base_simulation_table_path = fullfile(raw_results_path, "base_simulation_table.mat");
    save(base_simulation_table_path, 'base_simulation_table');

    % Save trim and remove amounts
    job_config.total_removed = total_removed;
    job_config.total_trimmed = total_trimmed;

    % Plot diagnostics for base simulation table 
    plot_base_simulation_table_diagnostics(base_simulation_table, figure_path, job_config);

    % Create object storing job and scenario configurations that we will save.
    out_params = job_config;
    out_params.scenarios = {};

    for i = 1:length(scenario_configs)
        % Load scenario config
        scenario_config_path = fullfile(scenario_config_paths(i).folder, scenario_config_paths(i).name);
        [~, scenario_name, ~] = fileparts(scenario_config_path);
        disp(['Running configuration from file: ', scenario_config_path]);
        scenario_config = scenario_configs{i};
        out_params.scenarios.(scenario_name) = scenario_config;

        % Add scenario specific parameter configurations
        simulation_params = update_params(job_config, scenario_config, arrival_rates);
        simulation_params.scenario_name = scenario_name;

        %Update scenarion simulation table
        scenario_simulation_table = get_scenario_simulation_table(base_simulation_table, ...
                                                                  ptrs_pathogen, ...
                                                                  prototype_effect_ptrs, ...
                                                                  response_rd_timelines, ...
                                                                  simulation_params);

        scenario_simulation_table_path = fullfile(raw_results_path, sprintf('%s_simulation_table.mat', scenario_name));
        save(scenario_simulation_table_path, 'scenario_simulation_table');

        % Run scenario
        event_list_simulation(scenario_simulation_table, econ_loss_model, simulation_params);
    end

    % Save job and scenario params
    config_outpath = fullfile(sim_results_path, "job_config.yaml");
    yaml.dumpFile(config_outpath, out_params);
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

% Helper function to convert 'TRUE'/'FALSE'/NA columns to numeric 1/0/NaN
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