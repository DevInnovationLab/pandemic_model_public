function plot_raw_ts(results_dir)
    %PLOT_RAW_TS Plot raw time series from simulation MAT files.
    %
    %   This function loads simulation results saved by save_to_file_fast.m
    %   and generates time series plots for costs, losses, and benefits for
    %   each scenario. Plots are saved to the figures/raw_ts directory.
    %
    %   Parameters
    %   ----------
    %   results_dir : char
    %       Path to the results directory containing job_config.yaml and raw MAT files.

    % Load config and scenario list
    config = yaml.loadFile(fullfile(results_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    rawdata_dir = fullfile(results_dir, "raw");

    % Create output folders
    raw_ts_fig_dir = fullfile(results_dir, "figures", "raw_ts");
    create_folders_recursively(raw_ts_fig_dir);

    % Define variable names as saved in MAT files by save_to_file_fast
    cost_vars = {'adv_cap', 'prototype_RD', 'ufv_RD', 'inp_cap', 'inp_marg', 'inp_RD', 'inp_tailoring', 'surveil'};
    cost_mat_names_n = { ...
        'costs_adv_cap_nom', ...
        'costs_prototype_RD_nom', ...
        'costs_ufv_RD_nom', ...
        'costs_inp_cap_nom', ...
        'costs_inp_marg_nom', ...
        'costs_inp_RD_nom', ...
        'costs_inp_tailoring_nom', ...
        'costs_surveil_nom' ...
    };
    cost_mat_names_p = { ...
        'costs_adv_cap_PV', ...
        'costs_prototype_RD_PV', ...
        'costs_ufv_RD_PV', ...
        'costs_inp_cap_PV', ...
        'costs_inp_marg_PV', ...
        'costs_inp_RD_PV', ...
        'costs_inp_tailoring_PV', ...
        'costs_surveil_PV' ...
    };

    loss_vars = {'m_learning_losses', 'm_mortality_losses', 'm_output_losses', 'u_deaths', 'm_deaths', 'benefits'};
    loss_mat_names = { ...
        'learning_losses', ...
        'm_mortality_losses', ...
        'm_output_losses', ...
        'u_deaths', ...
        'm_deaths', ...
        'tot_benefits_pv' ...
    };

    % Plot cumulative expenditure time series
    disp("Creating cumulative expenditure time series.")
    discounting = {'n', 'p'};
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        mat_filename = fullfile(rawdata_dir, sprintf('%s_results.mat', scenario));
        mat_data = load(mat_filename);

        for j = 1:length(cost_vars)
            for k = 1:length(discounting)
                if discounting{k} == 'n'
                    mat_field = cost_mat_names_n{j};
                else
                    mat_field = cost_mat_names_p{j};
                end
                if isfield(mat_data, mat_field)
                    ts_array = mat_data.(mat_field);
                else
                    warning('Field %s not found in %s', mat_field, mat_filename);
                    continue
                end

                var = strcat(cost_vars{j}, "_", discounting{k});
                fig = plot_timeseries(ts_array, var, ...
                                     'cumulative', true, ...
                                     'plot_samples', 2e2);
                figpath = fullfile(raw_ts_fig_dir, strcat(scenario, "_", var));
                print(fig, figpath, '-dpng', '-r600');
                close(fig);
            end
        end
    end

    % Plot cumulative losses and benefits time series
    disp("Creating cumulative losses and benefits time series.")
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        mat_filename = fullfile(rawdata_dir, sprintf('%s_results.mat', scenario));
        mat_data = load(mat_filename);

        for j = 1:length(loss_vars)
            mat_field = loss_mat_names{j};
            if isfield(mat_data, mat_field)
                ts_array = mat_data.(mat_field);
            else
                warning('Field %s not found in %s', mat_field, mat_filename);
                continue
            end

            var = loss_vars{j};
            fig = plot_timeseries(ts_array, var, ...
                                 'cumulative', true, ...
                                 'plot_samples', 2e2);
            figpath = fullfile(raw_ts_fig_dir, strcat(scenario, "_", var));
            print(fig, figpath, '-dpng', '-r600');
            close(fig);
        end
    end

    % Create mean cost time series plot
    disp("Creating mean cost time series plot")
    fig = figure('Position', [100 100 1200 800]);
    hold on;

    for i = 1:length(scenarios)
        scenario = scenarios(i);
        mat_filename = fullfile(rawdata_dir, sprintf('%s_results.mat', scenario));
        mat_data = load(mat_filename);

        % Create subplot for each scenario
        subplot(1, length(scenarios), i);
        hold on;

        for j = 1:length(cost_vars)
            mat_field = cost_mat_names_n{j}; % Use nominal costs for plotting
            if isfield(mat_data, mat_field)
                ts_array = mat_data.(mat_field);
            else
                warning('Field %s not found in %s', mat_field, mat_filename);
                continue
            end

            mean_costs = mean(ts_array, 1);
            disp(cost_vars{j})
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
    figpath = fullfile(raw_ts_fig_dir, "mean_costs_over_time");
    print(fig, figpath, '-dpng', '-r600');
    close(fig);
end