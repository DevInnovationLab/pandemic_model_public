function run_simulations(job_config_path)

    % Add libraries to path
    addpath(genpath('./yaml'));
    addpath(genpath('./pandemic_model'));

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);
    job_config = clean_job_config(job_config);
    rng(job_config.seed);

    % Create output dir
    [~, job_config_name, ~] = fileparts(job_config_path);

    foldername = job_config_name;
    if job_config.add_datetime_to_outdir
        currentDateTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
        foldername = foldername + "_" + char(currentDateTime);
    end
    
    outdirpath = fullfile(job_config.outdir, foldername, "raw");
    create_folders_recursively(outdirpath);
    job_config.outdirpath = outdirpath;

    % Generate simulations
    arrival_dist = load_arrival_dist(job_config.arrival_dist_config);
    duration_dist = load_duration_dist(job_config.duration_dist_config);
    viral_family_data = readtable(job_config.viral_family_data);
    base_simulation_table = get_base_simulation_table(arrival_dist, duration_dist, viral_family_data, job_config);

    % Save the simulation table using the name of the job config
    simulation_table_path = fullfile(outdirpath, "base_simulation_table.mat");
    save(simulation_table_path, 'base_simulation_table');
    
    % Log the save operation
    fprintf('Simulation table saved to: %s\n', simulation_table_path);

    % Create object storing job and scenario configurations that we will save.
    out_params = job_config;
    out_params.scenarios = {};
    
    % Handle folderpath input for scenario configs
    scenario_config_paths = dir(fullfile(job_config.scenario_configs, '*.yaml'));
    for i = 1:length(scenario_config_paths)
        % Load scenario config
        scenario_config_path = fullfile(scenario_config_paths(i).folder, scenario_config_paths(i).name);
        [~, scenario_name, ~] = fileparts(scenario_config_path);
        disp(['Running configuration from file: ', scenario_config_path]);
        scenario_params = yaml.loadFile(scenario_config_path);
        out_params.scenarios.(scenario_name) = scenario_params;

        % Add scenario specific parameter configucations
        simulation_params = update_params(job_config, scenario_params);
        simulation_params.scenario_name = scenario_name;

        % Run scenario
        scenario_simulation_table = get_scenario_simulation_table(base_simulation_table, simulation_params);

        % Save scenario simulation table so you can inspect
        save(fullfile(outdirpath, "scenario_simulation_table.mat"), 'scenario_simulation_table');

        simulate_scenario(scenario_simulation_table, simulation_params);
    end

    % Handle filepath list input for scenario configs
    % TO DO 

    % Save job and scenario params
    config_outpath = fullfile(outdirpath, "job_config.yaml");
    yaml.dumpFile(config_outpath, out_params);

end

function config = clean_job_config(config)

    config.surveillance_thresholds = cell2mat(config.surveillance_thresholds);
end 


function updated_params = update_params(base_params, new_params)

    % New parameters override base parameters
    updated_params = base_params;
    if ~isempty(new_params)
        fns = fieldnames(new_params);
        for k=1:numel(fns)
            updated_params.(fns{k}) = new_params.(fns{k});
        end
    end

    % Set pathogen family params. Should maybe do this elsewhere
    updated_params.viral_families_researched = parse_rd_investments(scenario_params.rd_investments, viral_family_data);
    num_vfs_researched = length(update_params.viral_families_researched) % Check dimensions here

    updated_params.adv_RD_spend = updated_params.adv_RD_cost_per_pathogen * ...
        updated_params.pathogens_per_family * ... 
        num_vfs_researched;

    % Set advance capacity
    [z_m, z_o] = get_adv_capacity(updated_params); % get target advance capacity
    updated_params.z_m = updated_params.share_target_advanced_capacity * z_m;
    updated_params.z_o = updated_params.share_target_advanced_capacity * z_o;

    validate_params(updated_params);

end

function validate_params(params)

    assert(params.RD_speedup_months <= params.tau_A); % R&D speedup must be less or equal than baseline time.
    assert(params.RD_success_rate_increase_per_platform * 4 <= 1 - params.p_b - params.p_m - params.p_o);
    assert(sum(params.pandemic_dur_probs)==1);

end