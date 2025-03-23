function get_npv(job_dir)
    % Get total costs first
    get_total_costs(job_dir);

    % Load config and get scenarios
    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    
    % Set up paths
    rawdata_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");
    
    num_sims = config.num_simulations;
    num_periods = config.sim_periods;
    
    % Initialize arrays to store NPV results
    absolute_npv = zeros(num_sims, num_periods, length(scenarios));
    absolute_npv_nom = zeros(num_sims, num_periods, length(scenarios));
    relative_npv = zeros(num_sims, num_periods, length(scenarios));
    relative_npv_nom = zeros(num_sims, num_periods, length(scenarios));
    
    % Ensure baseline is first scenario
    baseline_idx = find(scenarios == "baseline");
    if isempty(baseline_idx)
        error('No baseline scenario found');
    end
    
    % Calculate NPV for each scenario (both present value and nominal)
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        
        % Load PV costs and benefits
        pv_costs = readmatrix(fullfile(processed_dir, strcat(scenario, "_pv_costs.csv")));
        pv_benefits = readmatrix(fullfile(rawdata_dir, strcat(scenario, "_ts_benefits.csv")));
        
        % Load nominal costs and benefits 
        nom_costs = readmatrix(fullfile(processed_dir, strcat(scenario, "_nominal_costs.csv")));
        nom_benefits = readmatrix(fullfile(rawdata_dir, strcat(scenario, "_ts_benefits_nom.csv")));
        
        % Calculate absolute NPV (benefits - costs) for both PV and nominal
        absolute_npv(:,:,i) = pv_benefits - pv_costs;
        absolute_npv_nom(:,:,i) = nom_benefits - nom_costs;
        
        % Save absolute NPV results
        writematrix(absolute_npv(:,:,i), fullfile(processed_dir, strcat(scenario, "_absolute_npv.csv")));
        writematrix(absolute_npv_nom(:,:,i), fullfile(processed_dir, strcat(scenario, "_absolute_npv_nom.csv")));
    end
    
    % Calculate relative NPV using confirmed baseline (for both PV and nominal)
    baseline_npv = absolute_npv(:,:,baseline_idx);
    baseline_nom = absolute_npv_nom(:,:,baseline_idx);
    
    for i = 1:length(scenarios)
        % Calculate and save relative NPV
        relative_npv(:,:,i) = absolute_npv(:,:,i) - baseline_npv;
        relative_npv_nom(:,:,i) = absolute_npv_nom(:,:,i) - baseline_nom;
        
        % Save relative NPV results
        writematrix(relative_npv(:,:,i), fullfile(processed_dir, strcat(scenarios(i), "_relative_npv.csv")));
        writematrix(relative_npv_nom(:,:,i), fullfile(processed_dir, strcat(scenarios(i), "_relative_npv_nom.csv")));
    end

    plot_npv_histograms(job_dir);
    plot_npv_timeseries(job_dir, false);
    plot_npv_boxplots(processed_dir, fullfile(job_dir, "figures"), scenarios, "baseline");
    plot_baseline_npv_ts(job_dir);
    create_npv_summary_table(job_dir);
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


function plot_npv_boxplots(processed_dir, figures_dir, scenarios, baseline)
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
    mean_npv = mean(baseline_npv, 1) / 1e12; % Convert to trillions
    mean_nom = mean(baseline_nom, 1) / 1e12;
    
    % Create figure
    fig = figure('Position', [100 100 1200 800], 'Visible', 'off');
    hold on;
    
    % Plot both lines
    plot(1:length(mean_npv), mean_npv, 'LineWidth', 2, 'Color', [0, 0.4470, 0.7410], ...
         'DisplayName', 'Discounted');
    plot(1:length(mean_nom), mean_nom, 'LineWidth', 2, 'Color', [0.8500, 0.3250, 0.0980], ...
         'DisplayName', 'Nominal');
         
    % Add value labels at year 160
    total_npv = sum(mean_npv);
    total_nom = sum(mean_nom);
    text(160, mean_npv(160), ['Total: $' num2str(total_npv,'%.1f') 'T'], ...
         'VerticalAlignment', 'bottom', 'FontSize', 14, 'Color', [0, 0.4470, 0.7410]);
    text(160, mean_nom(160) + 0.1, ['Total: $' num2str(total_nom,'%.1f') 'T'], ...
         'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', 'FontSize', 14, 'Color', [0.8500, 0.3250, 0.0980]);
    
    % Add labels and styling
    title('Baseline net value over time', 'FontSize', 20)
    xlabel('Year', 'FontSize', 16)
    ylabel('Net value ($ trillions)', 'FontSize', 16)
    grid on
    set(gca, 'FontSize', 14)
    set(gca, 'XGrid', 'on', 'YGrid', 'on')
    
    % Add legend
    legend('Location', 'northwest', 'FontSize', 14)
    
    % Save figure
    figure_dir = fullfile(job_dir, "figures");
    create_folders_recursively(figure_dir);
    figpath = fullfile(figure_dir, "baseline_npv_ts.png");
    saveas(fig, figpath);
    close(fig);
end


function create_npv_summary_table(job_dir)
    % Creates a table summarizing costs and NPV differences from baseline for each scenario
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results
    
    % Load baseline data
    processed_dir = fullfile(job_dir, "processed");
    baseline_npv = readmatrix(fullfile(processed_dir, "baseline_absolute_npv.csv"));
    baseline_costs = readmatrix(fullfile(processed_dir, "baseline_pv_costs.csv"));
    
    % Calculate total baseline values
    total_baseline_npv = sum(mean(baseline_npv, 1));
    total_baseline_costs = sum(mean(baseline_costs, 1));
    
    % Get scenarios from config
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, 'baseline'));
    % Move combined_invest to end
    combined_idx = find(strcmp(scenarios, 'combined_invest'));
    if ~isempty(combined_idx)
        scenarios = [scenarios(1:(combined_idx-1)); 
                    scenarios((combined_idx+1):end);
                    scenarios(combined_idx)];
    end
    
    % Initialize table with baseline row
    summary_table = table('Size', [length(scenarios) 5], ...
        'VariableTypes', {'string', 'string', 'double', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'Value', 'NPVDiff', 'BenefitDiff', 'CostDiff'};
    
    % Process each scenario
    for i = 1:length(scenarios)
        scen_name = scenarios(i);
        
        % Load scenario data
        scen_npv = readmatrix(fullfile(processed_dir, strcat(scen_name, "_absolute_npv.csv")));
        scen_costs = readmatrix(fullfile(processed_dir, strcat(scen_name, "_pv_costs.csv")));
        scen_benefits = scen_npv + scen_costs; % Benefits = NPV + Costs
        
        % Calculate differences from baseline
        total_scen_npv = sum(mean(scen_npv, 1));
        total_scen_costs = sum(mean(scen_costs, 1));
        total_scen_benefits = sum(mean(scen_benefits, 1));
        
        npv_diff = total_scen_npv - total_baseline_npv;
        cost_diff = total_scen_costs - total_baseline_costs;
        benefit_diff = total_scen_benefits - (total_baseline_npv + total_baseline_costs);
        
        % Add to table
        summary_table(i,:) = {scen_name, '', npv_diff, benefit_diff, cost_diff};
    end
    
    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'npv_summary.csv'));
    
    % Write to LaTeX
    write_advance_investment_table_latex(summary_table, fullfile(processed_dir, 'advance_investment_npv_summary.tex'));
end


function write_advance_investment_table_latex(summary_data, outpath)
    % Convert to appropriate units
    summary_data.NPVDiff = summary_data.NPVDiff / 1e12; % Convert to trillions
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e12; % Convert to trillions
    summary_data.CostDiff = summary_data.CostDiff / 1e8; % Convert to hundreds of millions
    
    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');
    
    % Write LaTeX table header
    fprintf(fileID, '\\begin{table}[h]\n\\centering\n');
    fprintf(fileID, '\\caption{Net present value and cost relative to baseline}\n');
    fprintf(fileID, '\\begin{tabular}{l r r r}\n');
    fprintf(fileID, '\\toprule\n');
    fprintf(fileID, 'Scenario & \\multicolumn{3}{c}{Difference from baseline scenario} \\\\\n');
    fprintf(fileID, '\\cmidrule{2-4}\n');
    fprintf(fileID, '& Costs & Benefits & Net present value \\\\\n');
    fprintf(fileID, '& (hundred millions \\$) & (trillion \\$) & (trillion \\$) \\\\\n');
    fprintf(fileID, '\\midrule\n');
    
    % Write data rows
    for i = 1:height(summary_data)
        fprintf(fileID, '%s & %.0f & %.1f & %.1f \\\\\n', ...
            summary_data.Scenario{i}, ...
            summary_data.CostDiff(i), ...
            summary_data.BenefitDiff(i), ...
            summary_data.NPVDiff(i));
     end
    
    % Write LaTeX table footer
    fprintf(fileID, '\\bottomrule\n\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:npv_summary}\n');
    fprintf(fileID, '\\end{table}\n');
    
    % Close the file
    fclose(fileID);
end
