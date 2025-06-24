function process_benefit_cost(job_dir, recalculate_costs)
    % Get total costs first
    recalculate_costs
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
     
     % Calculate NPV for each scenario (both present value and nominal)
    for i = 1:length(scenarios)
        disp(scenarios(i))
        scenario = scenarios(i);
         
        % Load PV costs and benefits
        pv_costs = readmatrix(fullfile(processed_dir, strcat(scenario, "_pv_costs.csv")));
        pv_benefits = readmatrix(fullfile(rawdata_dir, strcat(scenario, "_ts_benefits.csv")));
         
        % Load nominal costs and benefits 
        nom_costs = readmatrix(fullfile(processed_dir, strcat(scenario, "_nominal_costs.csv")));
        nom_benefits = readmatrix(fullfile(rawdata_dir, strcat(scenario, "_ts_benefits_nom.csv")));
         
        % Calculate absolute NPV (benefits - costs) for both PV and nominal
        absolute_npv(:,:,i) = pv_benefits - pv_costs;
        absolute_npv_nom(:,:,i) = nom_benefits - nom_costs;
         
        % Save absolute NPV results
        writematrix(absolute_npv(:,:,i), fullfile(processed_dir, strcat(scenario, "_absolute_npv.csv")));
        writematrix(absolute_npv_nom(:,:,i), fullfile(processed_dir, strcat(scenario, "_absolute_npv_nom.csv")));
    end
     
    % Calculate relative NPV using confirmed baseline (for both PV and nominal)
    baseline_npv = absolute_npv(:,:,baseline_idx);
    baseline_nom = absolute_npv_nom(:,:,baseline_idx);
     
    for i = 1:length(scenarios)
        % Calculate and save relative NPV
        relative_npv(:,:,i) = absolute_npv(:,:,i) - baseline_npv;
        relative_npv_nom(:,:,i) = absolute_npv_nom(:,:,i) - baseline_nom;
         
        % Save relative NPV results
        writematrix(relative_npv(:,:,i), fullfile(processed_dir, strcat(scenarios(i), "_relative_npv.csv")));
        writematrix(relative_npv_nom(:,:,i), fullfile(processed_dir, strcat(scenarios(i), "_relative_npv_nom.csv")));
    end
end