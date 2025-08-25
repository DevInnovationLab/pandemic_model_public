function process_benefit_cost(job_dir, recalculate_costs)
    %PROCESS_BENEFIT_COST Calculate and save absolute and relative NPV for all scenarios.
    %
    %   This function processes benefit and cost data for each scenario,
    %   calculating both absolute and relative net present value (NPV) for
    %   present value (PV) and nominal costs/benefits.
    %
    %   Inputs:
    %       job_dir           - Directory containing job_config.yaml and data folders
    %       recalculate_costs - Boolean, whether to recalculate total costs

    if recalculate_costs
        process_total_costs(job_dir);
    end

    % Load config and get scenarios
    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
     
    % Set up paths
    rawdata_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");
     
    num_sims = config.num_simulations;
    num_periods = config.sim_periods;
     
    % Initialize arrays to store NPV results
    absolute_npv = zeros(num_sims, num_periods, length(scenarios));
    absolute_npv_nom = zeros(num_sims, num_periods, length(scenarios));
    relative_npv = zeros(num_sims, num_periods, length(scenarios));
    relative_npv_nom = zeros(num_sims, num_periods, length(scenarios));
     
    % Ensure baseline is first scenario
    baseline_idx = find(scenarios == "baseline");
    if isempty(baseline_idx)
        error('No baseline scenario found');
    end
     
    % Add progress bar for absolute NPV calculation
    n_scenarios = length(scenarios);
    h_abs = waitbar(0, 'Calculating absolute NPV for scenarios...');
    
    % Calculate NPV for each scenario (both present value and nominal)
    for i = 1:n_scenarios
        scenario = scenarios(i);
        
        % Load from .mat file (produced by save_to_file_fast)
        mat_filename = fullfile(rawdata_dir, sprintf('%s_results.mat', scenario));

        % Only load the required benefit arrays from the .mat file
        S = load(mat_filename, 'sim_out_arr_benefits_vaccine', 'sim_out_arr_benefits_vaccine_nom');

        % Costs: processed_dir (csv), Benefits: from .mat file
        pv_costs = readmatrix(fullfile(processed_dir, strcat(scenario, "_pv_costs.csv")));
        nom_costs = readmatrix(fullfile(processed_dir, strcat(scenario, "_nominal_costs.csv")));

        % Benefits: from loaded struct
        if isfield(S, 'sim_out_arr_benefits_vaccine')
            pv_benefits = S.sim_out_arr_benefits_vaccine;
        else
            error('PV benefits not found in %s', mat_filename);
        end
        if isfield(S, 'sim_out_arr_benefits_vaccine_nom')
            nom_benefits = S.sim_out_arr_benefits_vaccine_nom;
        else
            error('Nominal benefits not found in %s', mat_filename);
        end
        
        % Calculate absolute NPV (benefits - costs) for both PV and nominal
        absolute_npv(:,:,i) = pv_benefits - pv_costs;
        absolute_npv_nom(:,:,i) = nom_benefits - nom_costs;
        
        % Save absolute NPV results
        writematrix(absolute_npv(:,:,i), fullfile(processed_dir, strcat(scenario, "_absolute_npv.csv")));
        writematrix(absolute_npv_nom(:,:,i), fullfile(processed_dir, strcat(scenario, "_absolute_npv_nom.csv")));
        
        % Update progress bar
        waitbar(i/n_scenarios, h_abs, ...
            sprintf('Calculating absolute NPV: %d of %d', i, n_scenarios));
    end
    close(h_abs);
    
    % Calculate relative NPV using confirmed baseline (for both PV and nominal)
    baseline_npv = absolute_npv(:,:,baseline_idx);
    baseline_nom = absolute_npv_nom(:,:,baseline_idx);
    
    % Add progress bar for relative NPV calculation
    h_rel = waitbar(0, 'Calculating relative NPV for scenarios...');
    for i = 1:n_scenarios
        % Calculate and save relative NPV
        relative_npv(:,:,i) = absolute_npv(:,:,i) - baseline_npv;
        relative_npv_nom(:,:,i) = absolute_npv_nom(:,:,i) - baseline_nom;
        
        % Save relative NPV results
        writematrix(relative_npv(:,:,i), fullfile(processed_dir, strcat(scenarios(i), "_relative_npv.csv")));
        writematrix(relative_npv_nom(:,:,i), fullfile(processed_dir, strcat(scenarios(i), "_relative_npv_nom.csv")));
        
        % Update progress bar
        waitbar(i/n_scenarios, h_rel, ...
            sprintf('Calculating relative NPV: %d of %d', i, n_scenarios));
    end
    close(h_rel);
end