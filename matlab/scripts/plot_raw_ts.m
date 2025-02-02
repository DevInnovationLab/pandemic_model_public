function plot_raw_ts(results_dir)
    % Load config
    config = yaml.loadFile(fullfile(results_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    rawdata_dir = fullfile(results_dir, "raw");

    % Create out folders
    raw_ts_fig_dir = fullfile(results_dir, "figures", "raw_ts");
    create_folders_recursively(raw_ts_fig_dir);

    %% Single outcome plots
    disp("Creating cumulative expenditure time series.")
    cost_vars = {'adv_cap', 'adv_RD', 'inp_cap', 'inp_marg', 'inp_RD', 'inp_tail', 'surveil'};
    discounting = ['n', 'p'];
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        for j = 1:length(cost_vars)
            for k = 1:length(discounting)
                var = strcat(cost_vars{j}, "_", discounting(k));
                array_path = strcat(scenario, "_ts_", var, ".csv");
                ts_array = readmatrix(fullfile(rawdata_dir, array_path));

                fig = plot_timeseries(ts_array, var, 'cumulative', true, 'samples', 1e3);
                figpath = fullfile(raw_ts_fig_dir, strcat(scenario, "_", var, ".png"));
                saveas(fig, figpath);
            end
        end
    end

    disp("Creating cumulative losses and benefits time series.")
    loss_vars = {'m_learning_losses', 'm_mortality_losses', 'm_output_losses', 'u_deaths', 'm_deaths', 'benefits'};
    for i = 1:length(scenarios) % Consider joining scenario loops.
        scenario = scenarios(i);
        for j = 1:length(loss_vars)
            var = loss_vars{j};
            array_path = strcat(scenario, "_ts_", var, ".csv");
            ts_array = readmatrix(fullfile(rawdata_dir, array_path));

            fig = plot_timeseries(ts_array, var, 'cumulative', true, 'samples', 1e3);
            figpath = fullfile(raw_ts_fig_dir, strcat(scenario, "_", var, ".png"));
            saveas(fig, figpath);
        end
    end

    %% Create mean cost time series plot
    disp("Creating mean cost time series plot")
    fig = figure('Position', [100 100 1200 800]);
    hold on;

    % Plot each cost variable
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        
        % Create subplot for each scenario
        subplot(1, length(scenarios), i);
        hold on;
        
        % Plot each cost variable
        for j = 1:length(cost_vars)
            var = strcat(cost_vars{j}, "_n"); % Use present value costs
            array_path = strcat(scenario, "_ts_", var, ".csv");
            ts_array = readmatrix(fullfile(rawdata_dir, array_path));
            
            % Calculate mean across simulations for each time period
            mean_costs = mean(ts_array, 1);
            
            % Plot mean costs over time
            plot(1:length(mean_costs), mean_costs, 'LineWidth', 2, 'DisplayName', convert_varnames(cost_vars{j}));
        end
        
        title(['Mean costs over time - ' escape_chars(scenario)])
        xlabel('Time period')
        ylabel('Cost ($)')
        legend('Location', 'northwest')
        grid on
        set(gca, 'YScale', 'log')
    end

    % Save figure
    figpath = fullfile(raw_ts_fig_dir, "mean_costs_over_time.png");
    saveas(fig, figpath);
    close(fig);
end