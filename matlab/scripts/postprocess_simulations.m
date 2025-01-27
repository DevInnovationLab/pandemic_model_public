function postprocess_simulations(results_dir)

    config = yaml.loadFile(fullfile(results_dir, "job_config.yaml"));
    scenarios = fieldnames(config.scenarios);
    rawdata_dir = fullfile(results_dir, "raw");

    % Create out folders
    raw_ts_fig_dir = fullfile(results_dir, "figures", "raw_ts");
    create_folders_recursively(raw_ts_fig_dir);

    % Later ask AI to improve efficiency
    % Should likely multiprocess
    disp("Creating cumulative expenditure time series.")
    cost_vars = {'adv_cap', 'adv_RD', 'inp_cap', 'inp_marg', 'inp_RD', 'inp_tail', 'surveil'};
    discounting = ['n', 'p'];
    for i = 1:length(scenarios)
        scenario = scenarios{i};
        for j = 1:length(cost_vars)
            for k = 1:length(discounting)
                var = strcat(cost_vars{j}, "_", discounting(k));
                array_path = strcat(scenario, "_ts_", var, ".csv");
                ts_array = readmatrix(fullfile(rawdata_dir, array_path));

                fig = plot_timeseries(ts_array, var, 'cumulative', true);
                figpath = fullfile(raw_ts_fig_dir, strcat(scenario, "_", var, ".png"));
                saveas(fig, figpath);
            end
        end
    end

    disp("Creating cumulative losses and benefits time series.")
    loss_vars = {'m_learning_losses', 'm_mortality_losses', 'm_output_losses', 'u_deaths', 'm_deaths', 'benefits'};
    for i = 1:length(scenarios) % Consider joining scenario loops.
        scenario = scenarios{i};
        for j = 1:length(loss_vars)
            var = loss_vars{j};
            array_path = strcat(scenario, "_ts_", var, ".csv");
            ts_array = readmatrix(fullfile(rawdata_dir, array_path));

            fig = plot_timeseries(ts_array, var, 'cumulative', true);
            figpath = fullfile(raw_ts_fig_dir, strcat(scenario, "_", var, ".png"));
            saveas(fig, figpath);
        end
    end

    

end