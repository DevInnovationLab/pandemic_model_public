function process_total_costs(results_dir)
    %PROCESS_TOTAL_COSTS Aggregate total costs for each scenario.
    %
    %   This script processes the total costs for each scenario by summing
    %   across all cost components.

    config = yaml.loadFile(fullfile(results_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    rawdata_dir = fullfile(results_dir, "raw");
    processed_dir = fullfile(results_dir, "processed");
    create_folders_recursively(processed_dir);

    num_sims = config.num_simulations;
    num_periods = config.sim_periods;

    % List of cost variable names as saved in the .mat file
    cost_var_mat_names = { ...
        'sim_out_arr_costs_adv_cap_nom', ...
        'sim_out_arr_costs_prototype_RD_nom', ...
        'sim_out_arr_costs_ufv_RD_nom', ...
        'sim_out_arr_costs_inp_cap_nom', ...
        'sim_out_arr_costs_inp_marg_nom', ...
        'sim_out_arr_costs_inp_RD_nom', ...
        'sim_out_arr_costs_inp_tailoring_nom', ...
        'sim_out_arr_costs_surveil_nom' ...
    };

    cost_var_mat_names_pv = { ...
        'sim_out_arr_costs_adv_cap_PV', ...
        'sim_out_arr_costs_prototype_RD_PV', ...
        'sim_out_arr_costs_ufv_RD_PV', ...
        'sim_out_arr_costs_inp_cap_PV', ...
        'sim_out_arr_costs_inp_marg_PV', ...
        'sim_out_arr_costs_inp_RD_PV', ...
        'sim_out_arr_costs_inp_tailoring_PV', ...
        'sim_out_arr_costs_surveil_PV' ...
    };

    % Initialize progress bar
    n_scenarios = length(scenarios);
    h = waitbar(0, 'Processing costs...');

    % Process each scenario
    for i = 1:n_scenarios
        scenario = scenarios(i);

        % Load the .mat file for this scenario
        mat_filename = fullfile(rawdata_dir, sprintf('%s_results.mat', scenario));
        mat_data = load(mat_filename);

        % Initialize cost arrays for this scenario
        nominal_cost_array = zeros(num_sims, num_periods);
        pv_cost_array = zeros(num_sims, num_periods);

        % Sum up each cost variable's time series from the .mat file
        for j = 1:length(cost_var_mat_names)
            % Add nominal costs
            if isfield(mat_data, cost_var_mat_names{j})
                nominal_cost_array = nominal_cost_array + mat_data.(cost_var_mat_names{j});
            else
                warning('Field %s not found in %s', cost_var_mat_names{j}, mat_filename);
            end

            % Add present value costs
            if isfield(mat_data, cost_var_mat_names_pv{j})
                pv_cost_array = pv_cost_array + mat_data.(cost_var_mat_names_pv{j});
            else
                warning('Field %s not found in %s', cost_var_mat_names_pv{j}, mat_filename);
            end
        end

        writematrix(nominal_cost_array, fullfile(processed_dir, ...
                   strcat(scenario, "_nominal_costs.csv")));
        writematrix(pv_cost_array, fullfile(processed_dir, ...
                   strcat(scenario, "_pv_costs.csv")));

        % Update progress bar
        waitbar(i / n_scenarios, h, sprintf('Processing costs: %d of %d', i, n_scenarios));
    end

    % Close progress bar
    close(h);

end