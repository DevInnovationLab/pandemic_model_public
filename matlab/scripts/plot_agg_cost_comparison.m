function plot_agg_cost_comparison(job_dir)
    % Plots aggregate cost comparison figures showing total costs relative to baseline for each scenario
    % Args:
    %   job_dir: Directory containing job configuration and results

    get_total_costs(job_dir); % Make sure we have calculated total nominal costs.

    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    processed_dir = fullfile(job_dir, "processed");

    % Get scenarios and put combined last
    delta_scenarios = scenarios(~strcmp(scenarios, 'baseline'));
    
    % Create figure
    fig = figure('Position', [100 100 1200 800], 'Visible', 'off');
    hold on;
    
    % Professional color scheme
    colors = {[0, 0.4470, 0.7410], ... % Blue
              [0.8500, 0.3250, 0.0980], ... % Orange
              [0.4660, 0.6740, 0.1880], ... % Green
              [0.4940, 0.1840, 0.5560], ... % Purple
              [0.3010, 0.7450, 0.9330], ... % Light blue
              [0.6350, 0.0780, 0.1840]}; % Dark red
              
    % Load baseline costs
    baseline_costs = readmatrix(fullfile(processed_dir, "baseline_nominal_costs.csv"));
    
    % Plot costs relative to baseline for each scenario
    for i = 1:length(delta_scenarios)
        scenario = delta_scenarios(i);
        
        % Load scenario costs
        scenario_costs = readmatrix(fullfile(processed_dir, strcat(scenario, "_nominal_costs.csv")));
        
        % Calculate mean costs relative to baseline (in billions)
        mean_rel = mean(scenario_costs - baseline_costs, 1) / 1e9;
        
        % Plot with professional styling
        plot(1:length(mean_rel), mean_rel, 'Color', colors{mod(i-1, length(colors))+1}, ...
             'LineWidth', 2, 'DisplayName', convert_varnames(scenario));
    end
    
    % Add labels and styling
    title('Total Costs Relative to Baseline', 'FontSize', 14)
    xlabel('Year', 'FontSize', 12)
    ylabel('Difference in Total Costs ($ billions)', 'FontSize', 12, 'Interpreter', 'none')
    grid on
    box on
    set(gca, 'FontSize', 10)
    set(gca, 'Box', 'on', 'XGrid', 'on', 'YGrid', 'on')
    
    % Add legend
    legend('Location', 'northwest', 'FontSize', 10, 'Box', 'off');
    
    % Save figure
    comparisons_dir = fullfile(job_dir, "figures", "comparison");
    create_folders_recursively(comparisons_dir);
    figpath = fullfile(comparisons_dir, "total_costs_relative_comparison.png");
    saveas(fig, figpath);
    close(fig);

end

