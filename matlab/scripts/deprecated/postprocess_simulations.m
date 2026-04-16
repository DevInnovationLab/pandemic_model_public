function postprocess_simulations(results_dir)

    config = yaml.loadFile(fullfile(results_dir, "run_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    rawdata_dir = fullfile(results_dir, "raw");

    %% Compare variables across scenarios
    comparisons_dir = fullfile(results_dir, "figures", "comparison");
    create_folders_recursively(comparisons_dir);
    delta_scenarios = scenarios(~strcmp(scenarios, 'baseline'));

    comparison_vars = {"m_learning_losses", "m_mortality_losses", "m_output_losses", "u_deaths", "m_deaths", "benefits", ...
                 "adv_cap_n", "prototype_RD_n", "inp_cap_n", "inp_marg_n", "inp_RD_n", "surveil_n", ...
                 "adv_cap_p", "prototype_RD_p", "inp_cap_p", "inp_marg_p", "inp_RD_p", "surveil_p"};

    for i = 1:length(comparison_vars)
        var = comparison_vars{i};
        array_base_name = strcat("_ts_", var, '.csv');
        
        % Create figure
        fig = figure('Name', strcat(convert_varnames(var), ' comparison'), 'Visible', 'off');
        hold on;
        
        % Plot baseline scenario
        baseline_array = readmatrix(fullfile(rawdata_dir, strcat('baseline', array_base_name)));
        plot_timeseries(baseline_array, var, ...
            'cumulative', true, ...
            'fig', fig, ...
            'mean_linestyle', 'k-', ...
            'pctile_linestyle', 'k--', ...
            'pctile_in_legend', 'off');
        
        % Generate colors based on number of scenarios
        n_scenarios = length(delta_scenarios);
        colors = cell(1, n_scenarios);
        line_colors = ['r', 'b', 'g', 'm', 'c'];  % Basic MATLAB colors. Might need to make more
        for j = 1:n_scenarios
            colors{j} = line_colors(mod(j-1, length(line_colors)) + 1);
        end
        
        % Plot each delta scenario with different colors
        for j = 1:n_scenarios
            delta_scenario = delta_scenarios(j);
            delta_array = readmatrix(fullfile(rawdata_dir, strcat(delta_scenario, array_base_name)));
            
            % Plot with unique color and add to legend
            plot_timeseries(delta_array, var, ...
                'cumulative', true, ...
                'fig', fig, ...
                'mean_linestyle', [colors{j}, '-'], ...
                'pctile_linestyle', [colors{j}, '--'], ...
                'pctile_in_legend', 'off');
        end
        
        % Update legend to show only one entry per scenario
        legend_entries = ['Baseline'; escape_chars(delta_scenarios)];
        legend(legend_entries, 'Location', 'northwest');
        
        % Set title in sentence case
        title(sprintf('Comparison of %s across scenarios', lower(convert_varnames(var))), 'Interpreter', 'none', ...
            'Interpreter', 'none');
        
        % Save figure
        figpath = fullfile(comparisons_dir, strcat(var, "_abs_comparison.png"));
        saveas(fig, figpath);
        close(fig);
    end

    %% Plot differences from baseline for each variable
    for i = 1:length(comparison_vars)
        var = comparison_vars{i};
        array_base_name = strcat("_ts_", var, '.csv');
        
        % Create figure
        fig = figure('Name', strcat(convert_varnames(var), ' difference from baseline'), 'Visible', 'off');
        hold on;
        
        % Load baseline data
        baseline_array = readmatrix(fullfile(rawdata_dir, strcat('baseline', array_base_name)));
        
        % Generate colors based on number of scenarios
        n_scenarios = length(delta_scenarios);
        colors = cell(1, n_scenarios);
        line_colors = ['r', 'b', 'g', 'm', 'c'];  % Basic MATLAB colors
        for j = 1:n_scenarios
            colors{j} = line_colors(mod(j-1, length(line_colors)) + 1);
        end
        
        % Plot each delta scenario relative to baseline
        for j = 1:n_scenarios
            delta_scenario = delta_scenarios(j);
            delta_array = readmatrix(fullfile(rawdata_dir, strcat(delta_scenario, array_base_name)));
            
            % Calculate difference from baseline
            diff_array = delta_array - baseline_array;
            
            % Plot with unique color and add to legend
            plot_timeseries(diff_array, var, ...
                'cumulative', true, ...
                'fig', fig, ...
                'mean_linestyle', [colors{j}, '-'], ...
                'pctile_linestyle', [colors{j}, '--'], ...
                'pctile_in_legend', 'off');
        end
        
        % Add zero line
        yline(0, 'k--', 'HandleVisibility', 'off');
        
        % Update legend
        legend(escape_chars(delta_scenarios), 'Location', 'northwest');
        
        % Set title in sentence case
        title_pos = get(get(gca,'title'),'Position');
        title(sprintf('Difference from baseline: %s', lower(convert_varnames(var))), ...
            'Interpreter', 'none', 'Position', title_pos + [0 10 0]);
        
        % Save figure
        figpath = fullfile(comparisons_dir, strcat(var, "_rel_comparison.png"));
        saveas(fig, figpath);
        close(fig);
    end

    %% Plot ex ante severity against ex post severity
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
    
    % Create logarithmically spaced bins
    min_severity = min([baseline_pandemic_table.eff_severity; baseline_pandemic_table.ex_post_severity]);
    max_severity = max([baseline_pandemic_table.eff_severity; baseline_pandemic_table.ex_post_severity]);
    edges = logspace(log10(min_severity), log10(max_severity), 51);
    
    histogram(baseline_pandemic_table.eff_severity, edges, 'Normalization', 'probability', ...
             'FaceColor', [0 0.4470 0.7410], 'FaceAlpha', 0.6, ...
             'EdgeColor', 'none', 'DisplayName', 'Ex ante');
    hold on;
    histogram(baseline_pandemic_table.ex_post_severity, edges, 'Normalization', 'probability', ...
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