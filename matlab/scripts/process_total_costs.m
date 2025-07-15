function process_total_costs(results_dir)

    config = yaml.loadFile(fullfile(results_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    rawdata_dir = fullfile(results_dir, "raw");
    processed_dir = fullfile(results_dir, "processed");
    create_folders_recursively(processed_dir);

    num_sims = config.num_simulations;
    num_periods = config.sim_periods;

    % Define cost variables
    cost_vars = {'adv_cap', 'prototype_RD', 'ufv_RD', 'inp_cap', 'inp_marg', 'inp_RD', 'inp_tail', 'surveil'};

    % Process each scenario
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        
        % Initialize cost arrays for this scenario
        nominal_cost_array = zeros(num_sims, num_periods);
        pv_cost_array = zeros(num_sims, num_periods);
        
        % Sum up each cost variable's time series
        for j = 1:length(cost_vars)
            % Load and add nominal costs
            nominal_array_path = strcat(scenario, "_ts_", cost_vars{j}, "_n.csv");
            nominal_ts = readmatrix(fullfile(rawdata_dir, nominal_array_path));
            nominal_cost_array = nominal_cost_array + nominal_ts;
            
            % Load and add present value costs
            pv_array_path = strcat(scenario, "_ts_", cost_vars{j}, "_p.csv");
            pv_ts = readmatrix(fullfile(rawdata_dir, pv_array_path));
            pv_cost_array = pv_cost_array + pv_ts;
        end
             
        writematrix(nominal_cost_array, fullfile(processed_dir, ...
                   strcat(scenario, "_nominal_costs.csv")));
        writematrix(pv_cost_array, fullfile(processed_dir, ...
                   strcat(scenario, "_pv_costs.csv")));
    end

end