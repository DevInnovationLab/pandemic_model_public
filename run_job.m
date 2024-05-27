function run_job(job_config_path)

    addpath(genpath('./pandemic_model'));
    % Need to put this elsewhere
    i_COVID = 0.32;	% COVID intensity (annual deaths per thousand)
    i_star_threshold = i_COVID / 2; % min intensity for next pandemic

    % Load job config
    job_config = jsondecode(fileread(job_config_path));
    % Later want to make config loader more flexible

    % Create output dir
    [~, job_config_name, ~] = fileparts(job_config_path);

    foldername = job_config_name;
    if job_config.add_datetime_to_outdir
        currentDateTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
        foldername = foldername + "_" + char(currentDateTime);
    end
    
    outdirpath = fullfile(job_config.outdir, foldername, "raw");
    create_folders_recursively(outdirpath);

    % Load default params
    default_params = params_default();
    default_params.num_simulations = job_config.num_simulations;
    default_params.sim_periods = job_config.sim_periods;

    % Create pandemic scenarios
    rng(job_config.seed);
    if ~isfield(job_config, 'sim_scens_path')
        sim_scens_path = gen_all_sim_scens(default_params.arrival, job_config.include_false_positives, ...
            job_config.num_simulations, i_star_threshold, default_params.RD_family_freq_table, ...
            default_params.sim_periods, outdirpath);  
    else
        sim_scens_path = fullfile(job_config.sim_scens_path);

    end
    
    % Handle folderpath input
    scenario_config_paths = dir(fullfile(job_config.scenario_configs, '*.json')); % Assuming JSON config files
    for i = 1:length(scenario_config_paths)
        config_file = fullfile(scenario_config_paths(i).folder, scenario_config_paths(i).name);
        disp(['Running configuration from file: ', config_file]);
        run_params = update_params(default_params, config_file);
        [~, scenario_name, ~] = fileparts(config_file);
        run_params.include_false_positives = job_config.include_false_positives;
        run_params.scenario_name = scenario_name;
        run_params.endogenous_rental = job_config.endogenous_rental;
        run_params.outdirpath = outdirpath;
        run_model(run_params, sim_scens_path);
    end
end


function updated_params = update_params(params, config_file)

    new_params = jsondecode(fileread(config_file));

    % Sser parameters override defaults
    updated_params = params;
    if ~isempty(new_params)
        fns = fieldnames(new_params);
        for k=1:numel(fns)
            updated_params.(fns{k}) = new_params.(fns{k});
        end
    end

    % Set pathogen family params. Should maybe do this elsewhere
    families_to_invest_idx = 1:updated_params.pathogen_families_to_research;
    updated_params.RD_family_invested = updated_params.RD_family_freq_table(families_to_invest_idx, 1)';
    updated_params.RD_spend = updated_params.adv_RD_cost_per_pathogen * ...
        updated_params.pathogens_per_family * ... 
        updated_params.pathogen_families_to_research; 

    % Set advance capacity
    [z_m, z_o] = get_adv_capacity(updated_params); % get target advance capacity
    updated_params.z_m = updated_params.share_target_advanced_capacity * z_m;
    updated_params.z_o = updated_params.share_target_advanced_capacity * z_o;
    
    validate_params(updated_params);

end

function validate_params(params)

    assert(params.RD_speedup_months <= params.tau_A); % R&D speedup must be less than baseline time.
    assert(params.RD_success_rate_increase_per_platform * 4 <= 1 - params.p_b - params.p_m - params.p_o);
    assert(sum(params.pandemic_dur_probs)==1);

end


function run_model(params, sim_scens_path)
    [net_ws, benefits_ws, costs_ws] = monte_carlo_sims_new(params, sim_scens_path);

end
