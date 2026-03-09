function get_npv(job_dir, recalculate_bc)
    % Run NPV calculations and create figures
    if recalculate_bc
        process_benefit_cost(job_dir, recalculate_bc);
    end

    plot_npv_timeseries(job_dir, false);
    plot_npv_boxplots(job_dir, "baseline");
    plot_baseline_npv_ts(job_dir);
    write_benefits_costs_npv_table(job_dir, "baseline");
end


function plot_npv_histograms(job_dir)
    % Plot histograms of absolute and relative NPV for each scenario
    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    processed_dir = fullfile(job_dir, "processed");
    figures_dir = fullfile(job_dir, "figures");
    
    % Create figures directory if it doesn't exist
    create_folders_recursively(figures_dir);
    
    % Reorder scenarios to put baseline first and combined last
    scenarios_ordered = scenarios;
    combined_idx = find(strcmp(scenarios, 'combined_invest'));
    if ~isempty(combined_idx)
        scenarios_ordered = [scenarios(1:combined_idx-1);
                             scenarios(combined_idx+1:end);
                             scenarios(combined_idx)];
    end
    
    % Create figure for absolute NPV
    fig_abs = figure('Position', [100 100 800 1200], 'Visible', 'off');
    n_scenarios = length(scenarios_ordered);
    
    % Professional color for bars
    bar_color = [0, 0.4470, 0.7410];
    
    % First pass to determine overall x-axis limits
    abs_min = Inf;
    abs_max = -Inf;
    for i = 1:n_scenarios
        scenario = scenarios_ordered(i);
        npv_data = readmatrix(fullfile(processed_dir, strcat(scenario, "_absolute_npv.csv")));
        final_npv = sum(npv_data, 2) / 1e12;
        abs_min = min(abs_min, min(final_npv));
        abs_max = max(abs_max, max(final_npv));
    end
    
    % Plot absolute NPV histograms
    for i = 1:n_scenarios
        scenario = scenarios_ordered(i);
        
        % Load absolute NPV data
        npv_data = readmatrix(fullfile(processed_dir, strcat(scenario, "_absolute_npv.csv")));
        
        % Get final NPV values and convert to trillions
        final_npv = sum(npv_data, 2) / 1e12;
        
        % Create subplot
        subplot(n_scenarios, 1, i)
        histogram(final_npv, 'FaceColor', bar_color, 'EdgeColor', 'none')
        
        title(convert_varnames(scenario), 'Interpreter', 'None', 'FontSize', 11)
        
        % Only add x label to bottom plot
        if i == n_scenarios
            xlabel('Net Present Value ($ trillions)', 'FontSize', 10)
        end
        
        ylabel('Frequency', 'FontSize', 10)
        grid on
        box on
        set(gca, 'FontSize', 9)
        xlim([abs_min abs_max])
    end
    
    sgtitle('Distribution of Absolute Net Present Value by Scenario', 'FontSize', 14)
    
    % Save absolute NPV figure
    saveas(fig_abs, fullfile(figures_dir, "absolute_npv_distributions.png"));
    close(fig_abs);
    
    % Create figure for relative NPV (excluding baseline)
    non_baseline = scenarios_ordered(~strcmp(scenarios_ordered, "baseline"));
    n_non_baseline = length(non_baseline);
    
    fig_rel = figure('Position', [100 100 800 1000], 'Visible', 'off');
    
    % First pass to determine overall x-axis limits for relative plots
    rel_min = Inf;
    rel_max = -Inf;
    for i = 1:n_non_baseline
        scenario = non_baseline(i);
        npv_data = readmatrix(fullfile(processed_dir, strcat(scenario, "_relative_npv.csv")));
        final_npv = sum(npv_data, 2) / 1e12;
        rel_min = min(rel_min, min(final_npv));
        rel_max = max(rel_max, max(final_npv));
    end
    
    % Plot relative NPV histograms
    for i = 1:n_non_baseline
        scenario = non_baseline(i);
        
        % Load relative NPV data
        npv_data = readmatrix(fullfile(processed_dir, strcat(scenario, "_relative_npv.csv")));
        
        % Get final NPV values and convert to trillions
        final_npv = sum(npv_data, 2) / 1e12;
        
        % Create subplot
        subplot(n_non_baseline, 1, i)
        histogram(final_npv, 'FaceColor', bar_color, 'EdgeColor', 'none')
        
        title(convert_varnames(scenario), 'Interpreter', 'None', 'FontSize', 11)
        
        % Only add x label to bottom plot
        if i == n_non_baseline
            xlabel('Net Present Value Relative to Baseline ($ trillions)', 'FontSize', 10)
        end
        
        ylabel('Frequency', 'FontSize', 10)
        grid on
        box on
        set(gca, 'FontSize', 9)
        xlim([rel_min rel_max])
    end
    
    sgtitle('Distribution of Relative Net Present Value by Scenario', 'FontSize', 14)
    
    % Save relative NPV figure
    saveas(fig_rel, fullfile(figures_dir, "relative_npv_distributions.png"));
    close(fig_rel);
end


function plot_npv_timeseries(job_dir, include_ci)
    % Plot time series of absolute and relative NPV for all scenarios
    %
    % Args:
    %   job_dir: Path to job directory containing results
    %   include_ci: Boolean indicating whether to include confidence intervals
    
    % Set up paths and load config
    processed_dir = fullfile(job_dir, "processed");
    figures_dir = fullfile(job_dir, "figures");
    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    
    % Get scenarios and ensure baseline is identified
    scenarios = string(fieldnames(config.scenarios));
    baseline_idx = find(scenarios == "baseline");
    if isempty(baseline_idx)
        error('No baseline scenario found');
    end
    non_baseline = scenarios(scenarios ~= "baseline");
    
    % Set plotting parameters
    num_periods = config.sim_periods;
    time = 1:num_periods;
    
    % Plot absolute NPV over time
    fig_abs = figure('Position', [100 100 800 600], 'Visible', 'off');
    hold on
    
    % Calculate and plot for each scenario
    colors = lines(length(scenarios));
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        npv_data = readmatrix(fullfile(processed_dir, strcat(scenario, "_absolute_npv.csv")));
        
        % Calculate statistics
        avg_npv = mean(npv_data) / 1e12; % Convert to trillions
        
        if include_ci
            ci_lower = prctile(npv_data, 5) / 1e12;
            ci_upper = prctile(npv_data, 95) / 1e12;
            
            % Plot confidence interval with matching color
            fill([time fliplr(time)], [ci_lower fliplr(ci_upper)], ...
                 colors(i,:), 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        
        % Plot mean line
        plot(time, avg_npv, 'LineWidth', 2, 'Color', colors(i,:), 'DisplayName', convert_varnames(scenario));
    end
    
    grid on
    box on
    xlabel('Year', 'FontSize', 14)
    ylabel('Net present vlue ($ trillions)', 'FontSize', 14)
    title('Advance investment program average net present value over time', 'FontSize', 20)
    set(gca, 'FontSize', 912)
    legend('Location', 'best')
    hold off
    
    % Save absolute NPV time series
    saveas(fig_abs, fullfile(figures_dir, "absolute_npv_over_time.png"));
    close(fig_abs);
    
    % Plot relative NPV over time
    fig_rel = figure('Position', [100 100 800 600], 'Visible', 'off');
    hold on
    
    % Calculate and plot for non-baseline scenarios
    colors = lines(length(non_baseline));
    for i = 1:length(non_baseline)
        scenario = non_baseline(i);
        npv_data = readmatrix(fullfile(processed_dir, strcat(scenario, "_relative_npv.csv")));
        
        % Calculate statistics
        avg_npv = mean(npv_data) / 1e12;
        
        if include_ci
            ci_lower = prctile(npv_data, 2.5) / 1e12;
            ci_upper = prctile(npv_data, 97.5) / 1e12;
            
            % Plot confidence interval with matching color
            fill([time fliplr(time)], [ci_lower fliplr(ci_upper)], ...
                 colors(i,:), 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        
        % Plot mean line
        plot(time, avg_npv, 'LineWidth', 2, 'Color', colors(i,:), 'DisplayName', convert_varnames(scenario));
    end
    
    grid on
    box off
    xlabel('Year', 'FontSize', 14)
    ylabel('Net present value ($ trillions)', 'FontSize', 14)
    title('Average NPV of advance investment programs', 'FontSize', 20)
    set(gca, 'FontSize', 12)
    legend('Location', 'best')
    hold off
    
    % Save relative NPV time series
    saveas(fig_rel, fullfile(figures_dir, "relative_npv_over_time.png"));
    close(fig_rel);
end


function plot_npv_boxplots(job_dir, baseline)
    % Creates box plots comparing NPV distributions across scenarios, using total NPVs
    % summed over all simulations
    %
    % Args:
    %   processed_dir (string): Directory containing processed NPV data
    %   figures_dir (string): Directory to save output figures
    %   scenarios (string[]): Array of scenario names
    %   baseline (string): Name of baseline scenario
    %
    % Returns:
    %   None, but saves box plot figures to specified directory

    processed_dir = fullfile(job_dir, "processed");
    figures_dir = fullfile(job_dir, "figures");
    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));

    % Get non-baseline scenarios
    non_baseline = scenarios(~strcmp(scenarios, baseline));
    
    % Sort scenarios with baseline first and combined last
    sorted_scenarios = [baseline];
    for i = 1:length(non_baseline)
        if ~strcmp(non_baseline(i), 'combined_invest')
            sorted_scenarios = [sorted_scenarios, non_baseline(i)];
        end
    end
    sorted_scenarios = [sorted_scenarios, 'combined_invest'];
    
    % Initialize data arrays
    abs_data = [];
    rel_data = [];
    scenario_labels = [];
    
    % Load data for each scenario
    for i = 1:length(sorted_scenarios)
        scenario = sorted_scenarios(i);
        npv_data = readmatrix(fullfile(processed_dir, strcat(scenario, "_absolute_npv.csv")));
        total_npv = sum(npv_data, 2)/1e12; % Sum across time periods for each simulation
        abs_data = [abs_data; total_npv];
        scenario_labels = [scenario_labels; repmat(convert_varnames(scenario), length(total_npv), 1)];
    end
    
    % Load relative NPV data for non-baseline scenarios
    sorted_non_baseline = sorted_scenarios(2:end);
    rel_scenario_labels = [];
    for i = 1:length(sorted_non_baseline)
        scenario = sorted_non_baseline(i);
        npv_data = readmatrix(fullfile(processed_dir, strcat(scenario, "_relative_npv.csv")));
        total_rel_npv = sum(npv_data, 2)/1e12; % Sum across time periods for each simulation
        rel_data = [rel_data; total_rel_npv];
        rel_scenario_labels = [rel_scenario_labels; repmat(convert_varnames(scenario), length(total_rel_npv), 1)];
    end
    
    % Create absolute NPV box plot
    fig_abs = figure('Position', [100 100 800 600], 'Visible', 'off');
    % Create categorical array with ordered categories to prevent alphabetical sorting
    unique_labels = unique(scenario_labels);
    combined_idx = find(strcmp(unique_labels, 'Combined'));
    ordered_labels = [unique_labels(1:combined_idx-1); unique_labels(combined_idx+1:end); unique_labels(combined_idx)];
    labels = categorical(scenario_labels, ordered_labels, 'Ordinal', true);
    boxchart(labels, abs_data)
    grid on
    xlabel('Program', 'FontSize', 14)
    ylabel('Total NPV ($ trillions)', 'FontSize', 14)
    title('Advance investment program net present value across simulations', 'FontSize', 20)
    set(gca, 'FontSize', 12)
    xtickangle(45)
    
    % Save absolute NPV box plot
    saveas(fig_abs, fullfile(figures_dir, "absolute_npv_total.png"));
    close(fig_abs);
    
    % Create relative NPV box plot
    fig_rel = figure('Position', [100 100 800 600], 'Visible', 'off');
    % Create ordered categorical array for relative plot
    unique_rel_labels = unique(rel_scenario_labels);
    combined_idx = find(strcmp(unique_rel_labels, 'Combined'));
    ordered_rel_labels = [unique_rel_labels(1:combined_idx-1); unique_rel_labels(combined_idx+1:end); unique_rel_labels(combined_idx)];
    labels = categorical(rel_scenario_labels, ordered_rel_labels, 'Ordinal', true);
    boxchart(labels, rel_data)
    grid on
    xlabel('Program', 'FontSize', 14)
    ylabel('Total NPV ($ trillions)', 'FontSize', 14)
    title('Advance investment program net present value across simulations', 'FontSize', 14)
    set(gca, 'FontSize', 12)
    xtickangle(45)
    
    % Save relative NPV box plot
    saveas(fig_rel, fullfile(figures_dir, "relative_npv_total.png"));
    close(fig_rel);
end

function write_benefits_costs_npv_table(job_dir, scenario)
    % Mean cumulative sums of benefits, costs, and net present value.

    % Define job directory and processed directory
    raw_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");

    % Load data for the specified scenario
    benefits_file = fullfile(raw_dir, sprintf("%s_results.mat", scenario));
    processed_costs_file = fullfile(processed_dir, sprintf("%s_pv_costs.csv", scenario));
    processed_npv_file = fullfile(processed_dir, sprintf("%s_absolute_npv.csv", scenario));

    % Load benefits
    raw_out = load(benefits_file, "tot_benefits_pv"); % [sim x year]
    benefits = raw_out.tot_benefits_pv;

    % Load costs and NPV
    costs = readmatrix(processed_costs_file); % [sim x year]
    npv = readmatrix(processed_npv_file); % [sim x year]

    % Compute cumulative sums for each simulation
    cumsum_benefits = cumsum(benefits, 2);
    cumsum_costs = cumsum(costs, 2);
    cumsum_npv = cumsum(npv, 2);

    % Compute mean cumulative sums across simulations for each year
    mean_cumsum_benefits = mean(cumsum_benefits, 1);
    mean_cumsum_costs = mean(cumsum_costs, 1);
    mean_cumsum_npv = mean(cumsum_npv, 1);

    % Convert to billions for reporting
    cumsum_benefits_billions = mean_cumsum_benefits / 1e9;
    cumsum_costs_billions = mean_cumsum_costs / 1e9;
    cumsum_npv_billions = mean_cumsum_npv / 1e9;

    % Prepare table for writing
    years = (1:length(cumsum_benefits_billions))';
    scenario_col = repmat(string(scenario), length(years), 1);
    T = table(years, scenario_col, cumsum_benefits_billions', cumsum_costs_billions', cumsum_npv_billions', ...
        'VariableNames', {'Year', 'Scenario', 'CumulativeBenefits_Billions', 'CumulativeCosts_Billions', 'CumulativeNPV_Billions'});

    % Save the table as a CSV file in the processed directory
    outpath = fullfile(processed_dir, sprintf("%s_cumulative_benefits_costs_npv.csv", scenario));
    writetable(T, outpath);
end


function plot_baseline_npv_ts(job_dir)
    % Plots baseline NPV time series showing both nominal and discounted benefits
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results

    % Load baseline NPV data
    processed_dir = fullfile(job_dir, "processed");
    baseline_npv = readmatrix(fullfile(processed_dir, "baseline_absolute_npv.csv"));
    baseline_nom = readmatrix(fullfile(processed_dir, "baseline_absolute_npv_nom.csv"));
    
    % Calculate means
    mean_npv = mean(baseline_npv, 1) / 1e9; % Convert to trillions
    mean_nom = mean(baseline_nom, 1) / 1e9;
    
    % Create figure
    fig = figure('Position', [100 100 1200 800], 'Visible', 'off');
    hold on;
    
    % Plot both lines
    plot(1:length(mean_npv), mean_npv, 'LineWidth', 4, 'Color', [0, 0.4470, 0.7410], ...
         'DisplayName', 'Discounted');
    plot(1:length(mean_nom), mean_nom, 'LineWidth', 4, 'Color', [0.8500, 0.3250, 0.0980], ...
         'DisplayName', 'Nominal');

    % Label lines
    text(30, mean_npv(30), 'Present value', 'VerticalAlignment', 'bottom', 'FontSize', 14, 'Color', [0, 0.4470, 0.7410]);
    text(40, mean_nom(40), 'Nominal', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', 'FontSize', 14, 'Color', [0.8500, 0.3250, 0.0980]);
    
    % Add labels and styling
    title('Baseline net value over time', 'FontSize', 18, 'FontWeight', 'normal')
    xlabel('Year', 'FontSize', 16)
    ylabel('Net value ($ billion)', 'FontSize', 16)
    grid on
    set(gca, 'XGrid', 'on', 'YGrid', 'on')
    
    % Add legend
    legend('off');
    
    % Save figure
    figure_dir = fullfile(job_dir, "figures");
    create_folders_recursively(figure_dir);
    figpath = fullfile(figure_dir, "baseline_npv_ts.png");
    saveas(fig, figpath);
    close(fig);

    % Load config to get discount rate and periods for annualization
    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    r = config.r;
    periods = config.sim_periods;

    % Compute annualization factor (same as in build_sensitivity_loss_tables.m)
    annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);
end
