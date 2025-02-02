function postprocess_simulations(results_dir)

    config = yaml.loadFile(fullfile(results_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    rawdata_dir = fullfile(results_dir, "raw");

    %% Compare variables across scenarios
    diff_ts_fig_dir = fullfile(results_dir, "figures", "diff_ts");
    create_folders_recursively(diff_ts_fig_dir);
    delta_scenarios = scenarios(~strcmp(scenarios, 'baseline'));

    loss_vars = {'m_learning_losses', 'm_mortality_losses', 'm_output_losses', 'u_deaths', 'm_deaths', 'benefits'};
    for i = 1:length(loss_vars)
        var = loss_vars{i};
        array_base_name = strcat("_ts_", var, '.csv');
        baseline_array = readmatrix(fullfile(rawdata_dir, strcat('baseline', array_base_name)));
        
        % Calculate grid dimensions based on number of scenarios
        n_scenarios = length(delta_scenarios);
        n_cols = 3;
        n_rows = ceil(n_scenarios / n_cols);
        
        % Create figure with subplots
        fig = figure('Name', strcat(convert_varnames(var), ' across scenarios'));
        sgtitle(convert_varnames(var), 'Interpreter', 'none')
        
        % Track axis limits to standardize
        y_min = Inf;
        y_max = -Inf;
        
        % First create all subplots to get axis limits
        ax_handles = gobjects(n_scenarios, 1);
        plot_data = cell(n_scenarios, 1);
        
        % First pass to get axis limits
        for j = 1:n_scenarios
            delta_scenario = delta_scenarios(j);
            delta_array = readmatrix(fullfile(rawdata_dir, strcat(delta_scenario, array_base_name)));
            diff_array = delta_array - baseline_array;
            plot_data{j} = diff_array;
            
            % Get min/max across all data
            y_min = min(y_min, min(diff_array(:)));
            y_max = max(y_max, max(diff_array(:)));
        end
        
        % Second pass to create plots with standardized axes
        for j = 1:n_scenarios
            subplot(n_rows, n_cols, j)
            diff_array = plot_data{j};
            
            % Create plot using plot_timeseries
            plot_timeseries(diff_array, var, 'cumulative', true);
            
            % Override title and axis limits
            title(delta_scenarios(j), 'Interpreter', 'none')
            ylim([y_min y_max])
            
            % Only show y-label for leftmost plots
            if mod(j-1, n_cols) ~= 0
                ylabel('')
            end
            
            % Only show legend for last plot
            if j ~= n_scenarios
                legend('hide')
            end
        end
        
        % Save figure
        figpath = fullfile(diff_ts_fig_dir, strcat(var, "_comparison.png"));
        saveas(fig, figpath);
    end

    % % Plot ex ante severity against ex post severity
    baseline_pandemic_table = readtable(fullfile(rawdata_dir, "baseline_pandemic_table.csv"));

    % Create figure with two subplots
    fig = figure('Position', [100 100 1200 600]);
    
    % Scatter plot with trend line
    subplot(1,2,1);
    pos = get(gca, 'Position');
    pos(2) = 0.15; % Move plot up
    pos(4) = 0.7; % Make plot taller
    set(gca, 'Position', pos);
    
    scatter(baseline_pandemic_table.eff_severity, baseline_pandemic_table.ex_post_severity, 20, ...
           'filled', 'MarkerFaceAlpha', 0.3, 'MarkerEdgeColor', 'none');
    hold on;
    
    % Add trend line
    p = polyfit(log10(baseline_pandemic_table.eff_severity), ...
                log10(baseline_pandemic_table.ex_post_severity), 1);
    x_trend = logspace(log10(min(baseline_pandemic_table.eff_severity)), ...
                      log10(max(baseline_pandemic_table.eff_severity)), 100);
    y_trend = 10.^(p(1)*log10(x_trend) + p(2));
    plot(x_trend, y_trend, 'r-', 'LineWidth', 2);
    
    xlabel('Ex ante severity (deaths per 10,000)');
    ylabel('Ex post severity (deaths per 10,000)');
    set(gca, 'XScale', 'log', 'YScale', 'log');
    grid on;
    grid minor;
    
    % Histogram plot
    subplot(1,2,2);
    pos = get(gca, 'Position');
    pos(2) = 0.15; % Move plot up
    pos(4) = 0.7; % Make plot taller
    set(gca, 'Position', pos);
    
    histogram(baseline_pandemic_table.eff_severity, 50, 'Normalization', 'probability', ...
             'FaceColor', [0 0.4470 0.7410], 'FaceAlpha', 0.6, ...
             'EdgeColor', 'none', 'DisplayName', 'Ex ante');
    hold on;
    histogram(baseline_pandemic_table.ex_post_severity, 50, 'Normalization', 'probability', ...
             'FaceColor', [0.8500 0.3250 0.0980], 'FaceAlpha', 0.6, ...
             'EdgeColor', 'none', 'DisplayName', 'Ex post');
    hold off;
    
    xlabel('Severity (deaths per 10,000)');
    ylabel('Probability');
    legend('Location', 'northeast');
    set(gca, 'XScale', 'log');
    grid on;
    grid minor;
    
    % Adjust layout and formatting
    sgtitle('Ex ante vs ex post pandemic severity', 'FontSize', 14);
    set(gcf, 'Color', 'white');
    
    % Set consistent font sizes
    set(findall(gcf,'-property','FontSize'), 'FontSize', 12);
    set(findall(gcf,'-property','FontName'), 'FontName', 'Arial');

    % Adjust spacing between subplots
    set(gcf, 'Units', 'normalized');
    set(findall(gcf, 'Type', 'axes'), 'Units', 'normalized');
    
    saveas(fig, fullfile(results_dir, "figures", "ex_ante_vs_ex_post_severity_baseline.jpg"));
end