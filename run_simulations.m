function run_simulations(job_config_path)

    % Add libraries to path
    addpath(genpath('./yaml'));
    addpath(genpath('./pandemic_model'));

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);
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

    % Create pandemic scenarios
    if yaml.isNull(job_config.sim_scens_path)
        % Load arrival distribution
        arrival_dist_params = yaml.loadFile(job_config.arrival_dist_config);
        % Create pandemic viral family table
        viral_family_frequency_table = create_viral_family_frequency_table(job_config.num_viral_families);

        % Simulate pandemic arrivals and return path
        sim_scens_path = gen_all_sim_scens(arrival_dist_params, ...
                                           job_config.include_false_positives, ...
                                           job_config.num_simulations, ...
                                           job_config.minimum_pandemic_severity_threshold, ...
                                           viral_family_frequency_table, ...
                                           job_config.sim_periods, ...
                                           outdirpath);
    else
        sim_scens_path = fullfile(job_config.sim_scens_path);

    end
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
        simulate_scenario(simulation_params, sim_scens_path);
    end

    % Handle filepath list input for scenario configs
    % TO DO 

    % Save job and scenario params
    config_outpath = fullfile(outdirpath, "job_config.yaml");
    yaml.dumpFile(config_outpath, out_params);

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
    updated_params.viral_families_researched = 1:updated_params.viral_families_to_research;
    updated_params.adv_RD_spend = updated_params.adv_RD_cost_per_pathogen * ...
        updated_params.pathogens_per_family * ... 
        updated_params.viral_families_to_research;

    if updated_params.viral_families_to_research == 0
        updated_params.has_RD = 0;
        updated_params.inp_RD_cost = updated_params.inp_RD_no_adv_RD;
    else
        updated_params.has_RD = 1;
        updated_params.inp_RD_cost = updated_params.inp_RD_with_adv_RD;
    end

    % Set advance capacity
    [z_m, z_o] = get_adv_capacity(updated_params); % get target advance capacity
    updated_params.z_m = updated_params.share_target_advanced_capacity * z_m;
    updated_params.z_o = updated_params.share_target_advanced_capacity * z_o;

    % Convert cell structs to arrays
    updated_params.pandemic_dur_probs = cell2mat(updated_params.pandemic_dur_probs);
    updated_params.surveillance_thresholds = cell2mat(updated_params.surveillance_thresholds);
    
    validate_params(updated_params);

end

function validate_params(params)

    assert(params.RD_speedup_months <= params.tau_A); % R&D speedup must be less or equal than baseline time.
    assert(params.RD_success_rate_increase_per_platform * 4 <= 1 - params.p_b - params.p_m - params.p_o);
    assert(sum(params.pandemic_dur_probs)==1);

end