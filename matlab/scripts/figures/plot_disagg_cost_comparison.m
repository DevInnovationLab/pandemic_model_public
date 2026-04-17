function plot_disagg_cost_comparison(job_dir)
    % Plot per-cost-component comparisons relative to baseline for each scenario.
    %
    % Produces bar charts showing how each cost category (advance capacity, R&D,
    % surveillance, response) changes relative to baseline. Combines tailoring with
    % response capacity and places the combined scenario last.
    %
    % Args:
    %   job_dir  Path to the job output directory (contains run_config.yaml and raw/).

    config = yaml.loadFile(fullfile(job_dir, "run_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    rawdata_dir = fullfile(job_dir, "raw");

    %% Plot cost variables relative to baseline for each scenario
    comparisons_dir = fullfile(job_dir, "figures", "comparison");
    create_folders_recursively(comparisons_dir);
    
    % Get scenarios and put combined last
    delta_scenarios = scenarios(~strcmp(scenarios, 'baseline'));
    combined_idx = find(strcmp(delta_scenarios, 'combined_invest'));
    if ~isempty(combined_idx)
        delta_scenarios = [delta_scenarios(1:(combined_idx-1));
                           delta_scenarios((combined_idx+1):end);
                           delta_scenarios(combined_idx)];
    end
    
    % Define cost variables (nominal only)
    cost_vars = {"adv_cap_n", "prototype_RD_n", "ufv_RD_n", "inp_cap_n", "inp_marg_n", "inp_RD_n", "surveil_n"};
    
    % Calculate number of rows and columns for subplots
    n_scenarios = length(delta_scenarios);
    n_rows = floor(sqrt(n_scenarios));
    n_cols = ceil(n_scenarios/n_rows);
    % Create wide figure with space for legend at bottom
    fig = figure('Position', [100 100 1800 1000], 'Visible', 'off');
    
    % Professional color scheme
    colors = {[0, 0.4470, 0.7410], ... % Blue
              [0.8500, 0.3250, 0.0980], ... % Orange
              [0.4660, 0.6740, 0.1880], ... % Green
              [0.4940, 0.1840, 0.5560], ... % Purple
              [0.3010, 0.7450, 0.9330], ... % Light blue
              [0.6350, 0.0780, 0.1840], ... % Dark red
              [0.9290, 0.6940, 0.1250]}; % Yellow
    
    % Create subplot layout with space at bottom for legend
    tiledlayout(n_rows, n_cols, 'TileSpacing', 'compact', 'Padding', 'compact');
    sgtitle('Nominal costs (relative to baseline)', 'FontSize', 20)
    
    % Track axis limits to make them equal later
    y_min = Inf;
    y_max = -Inf;

    % Map cost_vars to field names in .mat files
    mat_field_map = struct( ...
        'adv_cap_n', 'costs_adv_cap_nom', ...
        'prototype_RD_n', 'costs_prototype_RD_nom', ...
        'ufv_RD_n', 'costs_ufv_RD_nom', ...
        'inp_cap_n', 'costs_inp_cap_nom', ...
        'inp_marg_n', 'costs_inp_marg_nom', ...
        'inp_RD_n', 'costs_inp_RD_nom', ...
        'surveil_n', 'costs_surveil_nom', ...
        'inp_tail_n', 'costs_inp_tailoring_nom' ...
    );

    % First pass to get axis limits
    for i = 1:n_scenarios
        scenario = delta_scenarios(i);
        scenario_mat = load(fullfile(rawdata_dir, sprintf('%s_results.mat', scenario)));
        baseline_mat = load(fullfile(rawdata_dir, 'baseline_results.mat'));
        for j = 1:length(cost_vars)
            var = cost_vars{j};
            baseline_array = baseline_mat.(mat_field_map.(var));
            scenario_array = scenario_mat.(mat_field_map.(var));

            % Add tailoring costs to response capacity if applicable
            if strcmp(var, "inp_cap_n")
                baseline_tail = baseline_mat.(mat_field_map.('inp_tail_n'));
                scenario_tail = scenario_mat.(mat_field_map.('inp_tail_n'));
                baseline_array = baseline_array + baseline_tail;
                scenario_array = scenario_array + scenario_tail;
            end

            mean_rel = mean(scenario_array - baseline_array, 1) / 1e9;
            y_min = min(y_min, min(mean_rel));
            y_max = max(y_max, max(mean_rel));
        end
    end

    % Plot each scenario
    for i = 1:n_scenarios
        scenario = delta_scenarios(i);
        scenario_mat = load(fullfile(rawdata_dir, sprintf('%s_results.mat', scenario)));
        baseline_mat = load(fullfile(rawdata_dir, 'baseline_results.mat'));
        nexttile
        hold on;

        % Plot each cost variable
        for j = 1:length(cost_vars)
            var = cost_vars{j};

            % Load baseline and scenario data from .mat
            baseline_array = baseline_mat.(mat_field_map.(var));
            scenario_array = scenario_mat.(mat_field_map.(var));

            % Add tailoring costs to response capacity if applicable
            if strcmp(var, "inp_cap_n")
                baseline_tail = baseline_mat.(mat_field_map.('inp_tail_n'));
                scenario_tail = scenario_mat.(mat_field_map.('inp_tail_n'));
                baseline_array = baseline_array + baseline_tail;
                scenario_array = scenario_array + scenario_tail;
            end

            % Calculate means
            mean_rel = mean(scenario_array - baseline_array, 1) / 1e9;
            
            % Plot with professional styling
            line_label = convert_varnames(var);
            line_label = strrep(line_label, ' (nominal value)', '');
            plot(1:length(mean_rel), mean_rel, 'Color', colors{j}, 'LineWidth', 2, 'DisplayName', line_label);
        end
        title(convert_varnames(scenario), 'Interpreter', 'None', 'FontSize', 14)
        
        % Only add x labels to bottom row
        if i > n_scenarios - n_cols
            xlabel('Year', 'FontSize', 12)
        end
        
        % Only add y labels to leftmost column
        if mod(i-1, n_cols) == 0
            ylabel('Costs ($ billions)', 'FontSize', 12, "Interpreter", 'none')
        end
        
        % Set consistent axis limits and appearance
        ylim([y_min y_max])
        grid on
        box off
        set(gca, 'FontSize', 11)
        set(gca, 'Box', 'on', 'XGrid', 'on', 'YGrid', 'on')
    end

    % Add legend at bottom with good spacing
    leg = legend('NumColumns', 3, ...
           'Orientation', 'horizontal', ...
           'FontSize', 11, ...
           'Box', 'off');
    leg.Layout.Tile = 'south'; % Place legend below plots
    % Save figure with adjusted dimensions
    figpath = fullfile(comparisons_dir, "cost_vars_relative_comparison.png");
    exportgraphics(fig, figpath, 'Resolution', 400);
    close(fig);
end