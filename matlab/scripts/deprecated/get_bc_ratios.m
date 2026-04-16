function get_bc_ratios(results_dir)
    % Creates violin plots of absolute and relative benefit-cost ratios
    %
    % Args:
    %   results_dir (string): Path to results directory containing raw data
    
    % Load configuration and set up directories
    config = yaml.loadFile(fullfile(results_dir, "run_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    rawdata_dir = fullfile(results_dir, "raw");
    processed_dir = fullfile(results_dir, "processed");
    figure_dir = fullfile(results_dir, "figures", "bc_ratios");
    create_folders_recursively(figure_dir);

    % Load and process all data first
    [benefits, costs] = load_all_data(scenarios, rawdata_dir, processed_dir);
    
    % Calculate absolute and relative BC ratios
    [abs_bc_ratios, rel_bc_ratios] = calculate_bc_ratios(benefits, costs, scenarios);
    
    % Define time horizons for plotting
    horizons = ["20 Year", "50 Year", "Full"];
    fields = ["yr20", "yr50", "full"];
    
    % Create plots for each time horizon
    for h = 1:length(horizons)
        % Plot absolute BC ratios
        plot_bc_ratios(abs_bc_ratios, scenarios, horizons(h), fields(h), ...
                      figure_dir, "absolute", "Benefit-cost ratio (absolute)");
        
        % Plot relative BC ratios (excluding baseline)
        non_baseline_scenarios = scenarios(~strcmp(scenarios, 'baseline'));
        plot_bc_ratios(rel_bc_ratios, non_baseline_scenarios, horizons(h), fields(h), ...
                      figure_dir, "relative", "Benefit-cost ratio (rel. to baseline)");
    end
end

function [benefits, costs] = load_all_data(scenarios, rawdata_dir, processed_dir)
    % Load all benefits and costs data
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        
        % Load raw data
        benefits.(scenario) = readmatrix(fullfile(rawdata_dir, strcat(scenario, "_ts_benefits.csv")));
        costs.(scenario) = readmatrix(fullfile(processed_dir, strcat(scenario, "_pv_costs.csv")));
    end
end

function [abs_bc_ratios, rel_bc_ratios] = calculate_bc_ratios(benefits, costs, scenarios)
    % Calculate both absolute and relative BC ratios
    
    % First calculate absolute ratios and cumulative values
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        
        % Calculate cumulative values
        cum_benefits.(scenario) = cumsum(benefits.(scenario), 2);
        cum_costs.(scenario) = cumsum(costs.(scenario), 2);
        
        % Calculate absolute BC ratios at different horizons
        abs_bc_ratios.(scenario).yr20 = cum_benefits.(scenario)(:,20) ./ cum_costs.(scenario)(:,20);
        abs_bc_ratios.(scenario).yr50 = cum_benefits.(scenario)(:,50) ./ cum_costs.(scenario)(:,50);
        abs_bc_ratios.(scenario).full = cum_benefits.(scenario)(:,end) ./ cum_costs.(scenario)(:,end);
    end
    
    % Then calculate relative ratios for non-baseline scenarios
    baseline_scenario = 'baseline';
    non_baseline_scenarios = scenarios(~strcmp(scenarios, baseline_scenario));
    
    for i = 1:length(non_baseline_scenarios)
        scenario = non_baseline_scenarios(i);
        
        % Calculate relative values at each horizon
        fields = ["yr20", "yr50", "full"];
        time_points = [20, 50, size(cum_benefits.(scenario), 2)];
        
        for j = 1:length(fields)
            field = fields(j);
            t = time_points(j);
            
            % Calculate incremental benefits and costs relative to baseline
            inc_benefits = cum_benefits.(scenario)(:,t) - cum_benefits.(baseline_scenario)(:,t);
            inc_costs = cum_costs.(scenario)(:,t) - cum_costs.(baseline_scenario)(:,t);
            
            % Calculate relative BC ratio
            rel_bc_ratios.(scenario).(field) = inc_benefits ./ inc_costs;
        end
    end
end

function plot_bc_ratios(bc_ratios, plot_scenarios, horizon, field, figure_dir, type, ylabel_text)
    % Create violin plot for BC ratios
    fig = figure('Position', [100 100 800 600]);
    
    % Prepare plot data
    [plotData, meanValues, percentile5, percentile95] = prepare_plot_data(bc_ratios, plot_scenarios, field);
    
    % Create base violin plot
    x = categorical(escape_chars(plot_scenarios));
    violinplot(x, plotData, 'HandleVisibility', 'off');
    
    % Customize plot appearance
    title([ylabel_text strcat(horizon, " horizon")]);
    ylabel(ylabel_text);
    xlabel('Scenario');
    grid on;
    
    % Add reference line and styling
    hold on;
    yline(1, '--r', 'Break even', 'LineWidth', 1.5, ...
        'HandleVisibility', 'off', 'LabelVerticalAlignment', 'bottom');
    
    % Add percentile spikes
    for i = 1:length(plot_scenarios)
        plot([i i], [percentile5(i) percentile95(i)], 'k-', 'HandleVisibility', 'off');
        plot([i-0.02 i+0.02], [percentile5(i) percentile5(i)], 'k-', 'HandleVisibility', 'off');
        plot([i-0.02 i+0.02], [percentile95(i) percentile95(i)], 'k-', 'HandleVisibility', 'off');
    end
    
    % Add mean markers and labels
    scatter(x, meanValues, 70, 'k', 'filled', 'DisplayName', 'Mean');
    for i = 1:length(plot_scenarios)
        text(i+0.1, meanValues(i), sprintf('%.2f', meanValues(i)), ...
             'Color', 'k', 'FontWeight', 'bold');
    end
    
    % Add legend and save
    legend('Location', 'northeast', 'FontSize', 10);
    hold off;
    
    saveas(fig, fullfile(figure_dir, strcat(type, "_bc_ratios_", field, ".png")));
    close(fig);
end

function [plotData, meanValues, percentile5, percentile95] = prepare_plot_data(bc_ratios, scenarios, field)
    % Prepare data arrays for plotting
    plotData = [];
    meanValues = zeros(1, length(scenarios));
    percentile5 = zeros(1, length(scenarios));
    percentile95 = zeros(1, length(scenarios));
    
    for i = 1:length(scenarios)
        scenarioData = bc_ratios.(scenarios(i)).(field);
        plotData = [plotData, scenarioData];
        meanValues(i) = mean(scenarioData);
        percentile5(i) = prctile(scenarioData, 5);
        percentile95(i) = prctile(scenarioData, 95);
    end
end
