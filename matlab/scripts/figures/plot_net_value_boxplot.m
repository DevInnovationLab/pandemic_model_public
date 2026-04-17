function plot_net_value_boxplot(out_dir)
    % Plot net value (PV) from raw results as a manual boxplot per scenario.
    % The box shows the interquartile range, the vertical line shows the median,
    % the whiskers show the 10th and 90th percentiles, and the dot shows the mean.
    % Y-axis: surplus-only investment programs in a single layer of labels.
    % Uses only raw sample data (no bootstrap).
    %
    % Writes `processed/net_value_boxplot_moments_surplus.csv` and
    % `processed/net_value_boxplot_moments_baseline.csv` with distribution
    % moments (mean, median, 10th--90th percentiles, plus 15th and 20th; units in headers).
    %
    % Args:
    %   out_dir (string): Job output directory containing 'processed' and 'figures'.

    result = 'net_value_pv';
    col_name = [result '_full'];

    % Order of programs on the y-axis (top to bottom when plotted):
    % advance capacity, prototype vaccine R&D, universal flu vaccine R&D,
    % early warning, then combined.
    investment_tags = {'advance_capacity', 'neglected_pathogen_rd', 'universal_flu_rd', ...
                       'improved_early_warning', 'combined_invest'};
    investment_labels = {'Advance capacity', 'Prototype vaccine R&D', 'Universal flu vaccine R&D', ...
                         'Early warning', 'Combined'};

    processed_dir = fullfile(out_dir, 'processed');
    figure_path = fullfile(out_dir, 'figures');
    if ~exist(figure_path, 'dir'), mkdir(figure_path); end

    run_config = yaml.loadFile(fullfile(out_dir, 'run_config.yaml'));
    all_scenarios = string(fieldnames(run_config.scenarios));
    all_scenarios = all_scenarios(~strcmp(all_scenarios, 'baseline'));

    % Build ordered list: one surplus scenario per investment program
    scenarios_ordered = {};
    y_labels = {};
    for i = 1:numel(investment_tags)
        for si = 1:numel(all_scenarios)
            scen = all_scenarios(si);
            [row_tag, accent] = parse_grid_scenario_tag(scen);
            if strcmp(row_tag, investment_tags{i}) && strcmpi(accent, "Surplus")
                sum_file = fullfile(processed_dir, scen + "_relative_sums.mat");
                if exist(sum_file, 'file')
                    scenarios_ordered{end+1} = scen; %#ok<AGROW>
                    y_labels{end+1} = investment_labels{i}; %#ok<AGROW>
                end
                break;
            end
        end
    end

    n = numel(scenarios_ordered);
    if n == 0
        warning('plot_net_value_raw: no scenarios found in %s', out_dir);
        return;
    end

    mean_val = nan(n, 1);
    all_data = cell(n, 1);

    for k = 1:n
        sum_file = fullfile(processed_dir, scenarios_ordered{k} + "_relative_sums.mat");
        load(sum_file, 'all_relative_sums');
        data = all_relative_sums.(col_name);
        mean_val(k) = mean(data) / 1e12;
        all_data{k} = data(:) / 1e12; % Convert to trillions
    end

    y_pos = (1:n)';

    % --- Manual boxplot: whiskers 10--90%, box IQR, median line, mean dot ---
    q1 = nan(n, 1);
    med = nan(n, 1);
    q3 = nan(n, 1);
    perc_10_90 = nan(n, 2);
    perc_15 = nan(n, 1);
    perc_20 = nan(n, 1);
    for k = 1:n
        d = all_data{k};
        if ~isempty(d)
            p = prctile(d, [10, 15, 20, 25, 50, 75, 90]);
            perc_10_90(k, :) = [p(1), p(7)];
            perc_15(k) = p(2);
            perc_20(k) = p(3);
            q1(k) = p(4);
            med(k) = p(5);
            q3(k) = p(6);
        end
    end

    box_hw = 0.32;
    face_color = [0.88 0.92 0.97];
    edge_color = [0.35 0.45 0.65];
    whisker_color = [0.5 0.5 0.5];

    fig = figure('Visible', 'off', 'Position', [100 100 750 520]);
    ax = axes();
    hold(ax, 'on');

    h_whisker = [];
    h_box = [];
    h_median = [];
    % Draw in overlay order: 10/90 percentiles (back), IQR box, median line, then mean (on top).
    for k = 1:n
        if isnan(q1(k))
            plot(ax, mean_val(k), y_pos(k), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 5);
            continue;
        end
        y = y_pos(k);
        % 1. Whisker: 10th to 90th with caps (drawn first, at back)
        hw = plot(ax, [perc_10_90(k, 1), perc_10_90(k, 2)], [y, y], '-', 'Color', whisker_color, 'LineWidth', 1.6);
        plot(ax, [perc_10_90(k, 1), perc_10_90(k, 1)], [y - 0.08, y + 0.08], '-', 'Color', whisker_color, 'LineWidth', 1.2);
        plot(ax, [perc_10_90(k, 2), perc_10_90(k, 2)], [y - 0.08, y + 0.08], '-', 'Color', whisker_color, 'LineWidth', 1.2);
        % 2. Box: interquartile range (Q1 to Q3)
        xb = [q1(k), q3(k), q3(k), q1(k)];
        yb = [y - box_hw, y - box_hw, y + box_hw, y + box_hw];
        hb = patch(ax, xb, yb, face_color, 'EdgeColor', edge_color, 'LineWidth', 1.0);
        % 3. Median line at x = median
        hm = plot(ax, [med(k), med(k)], [y - box_hw, y + box_hw], '-', 'Color', edge_color, 'LineWidth', 2.2);
        if isempty(h_whisker)
            h_whisker = hw;
            h_box = hb;
            h_median = hm;
        end
    end

    % 4. Mean (on top)
    h_mean = plot(ax, mean_val, y_pos, 'o', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', [0.05 0.07 0.13], 'MarkerSize', 6.5);

    ax.YDir = 'reverse';
    ax.YLim = [0.5, n + 0.5];
    ax.YTick = 1:n;
    ax.YTickLabel = y_labels;
    ax.TickLabelInterpreter = 'none';
    ax.FontSize = 10;
    ax.TickDir = 'out';
    ax.Box = 'off';
    ax.YAxisLocation = 'left';
    ax.XGrid = 'on';
    xlabel(ax, 'Net present value (trillion $)', 'FontSize', 11);

    % X-axis limits and ticks at every trillion dollars, based on whisker endpoints
    valid_whiskers = ~isnan(perc_10_90(:, 1));
    if any(valid_whiskers)
        global_min = min(perc_10_90(valid_whiskers, 1));
        global_max = max(perc_10_90(valid_whiskers, 2));
        x_lo = floor(global_min);
        x_hi = ceil(global_max);
        if x_lo == x_hi
            x_hi = x_lo + 1;
        end
        ax.XLim = [x_lo, x_hi];
        ax.XTick = x_lo:1:x_hi;
    end

    % No legend in the advance investment panel (legend only in baseline panel).
    % Export main net value boxplot as vector PDF
    exportgraphics(fig, fullfile(figure_path, 'net_value_boxplot.pdf'));
    close(fig);

    % Distribution moments matching the figure (trillions $), for tables / paper
    moment_names = {'Scenario', 'Investment program', 'Mean (trillion $)', 'Median (trillion $)', ...
                    '10th percentile (trillion $)', '15th percentile (trillion $)', ...
                    '20th percentile (trillion $)', '25th percentile (trillion $)', ...
                    '75th percentile (trillion $)', '90th percentile (trillion $)'};
    out_table = table(string(scenarios_ordered'), string(y_labels'), mean_val, med, ...
        perc_10_90(:, 1), perc_15, perc_20, q1, q3, perc_10_90(:, 2), 'VariableNames', moment_names);
    writetable(out_table, fullfile(processed_dir, "net_value_boxplot_moments_surplus.csv"));

    %% --- Baseline vaccine scenario: standalone net value boxplot (absolute, not relative) ---
    baseline_file = fullfile(processed_dir, 'baseline_annual_sums.mat');
    S_base = load(baseline_file, 'all_baseline_sums');
    baseline_tbl = S_base.all_baseline_sums;

    data_base = baseline_tbl.net_value_pv_full(:) / 1e12; % Convert to trillions

    % Compute distribution statistics
    p = prctile(data_base, [10, 15, 20, 25, 50, 75, 90]);
    perc_10_90_b = [p(1), p(7)];
    perc_15_b = p(2);
    perc_20_b = p(3);
    q1_b = p(4);
    med_b = p(5);
    q3_b = p(6);

    % Baseline plot: single box at y = 1.
    y_base = 1;

    % Make the baseline figure a bit less tall than the advance
    % investment figure so it is visually shorter in panels.
    fig_b = figure('Visible', 'off', 'Position', [100 100 750 300]);
    ax_b = axes();
    hold(ax_b, 'on');

    % Whisker: 10th to 90th with caps
    hw_b = plot(ax_b, [perc_10_90_b(1), perc_10_90_b(2)], [y_base, y_base], '-', ...
        'Color', whisker_color, 'LineWidth', 1.6);
    plot(ax_b, [perc_10_90_b(1), perc_10_90_b(1)], [y_base - 0.08, y_base + 0.08], '-', ...
        'Color', whisker_color, 'LineWidth', 1.2);
    plot(ax_b, [perc_10_90_b(2), perc_10_90_b(2)], [y_base - 0.08, y_base + 0.08], '-', ...
        'Color', whisker_color, 'LineWidth', 1.2);

    % Box: interquartile range
    single_box_hw = box_hw * 0.5;
    xb_b = [q1_b, q3_b, q3_b, q1_b];
    yb_b = [y_base - single_box_hw, y_base - single_box_hw, y_base + single_box_hw, y_base + single_box_hw];
    hb_b = patch(ax_b, xb_b, yb_b, face_color, 'EdgeColor', edge_color, 'LineWidth', 1.0);

    % Median line
    hm_b = plot(ax_b, [med_b, med_b], [y_base - single_box_hw, y_base + single_box_hw], '-', ...
        'Color', edge_color, 'LineWidth', 2.2);

    % Mean point
    mean_base = mean(data_base);
    hmean_b = plot(ax_b, mean_base, y_base, 'o', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', [0.05 0.07 0.13], 'MarkerSize', 6.5);

    % Axis styling
    ax_b.YDir = 'reverse';
    ax_b.YLim = [0.5, 1.5];
    ax_b.YTick = 1;
    % Two-line y-tick label using TeX interpreter and newline
    ax_b.YTickLabel = {'Status quo response'};
    ax_b.FontSize = 10;
    ax_b.TickDir = 'out';
    ax_b.Box = 'off';
    ax_b.YAxisLocation = 'left';
    ax_b.XGrid = 'on';
    xlabel(ax_b, 'Net present value (trillion $)', 'FontSize', 11);

    % X-axis limits and ticks every 5 trillion dollars
    global_min_b = perc_10_90_b(1);
    global_max_b = perc_10_90_b(2);
    % Round limits to nearest 5
    x_lo_b = floor(global_min_b / 5) * 5;
    x_hi_b = ceil(global_max_b / 5) * 5;
    if x_lo_b == x_hi_b
        x_hi_b = x_lo_b + 5;
    end
    ax_b.XLim = [x_lo_b, x_hi_b];
    ax_b.XTick = x_lo_b:5:x_hi_b;

    % Legend: mean, median, IQR, 10/90 percentiles (baseline panel only)
    h_median_legend_b = plot(ax_b, NaN, NaN, '-', 'LineStyle', 'none', 'Marker', 'none');
    h_legend = legend(ax_b, [hmean_b, h_median_legend_b, hb_b, hw_b], ...
        {'Mean', 'Median', 'Interquartile range', '10/90 percentiles'}, ...
        'FontSize', 9, 'Interpreter', 'none', ...
        'Location', 'northoutside', 'Orientation', 'horizontal', ...
        'Box', 'on');

    % Export baseline net value boxplot as PNG
    exportgraphics(fig_b, fullfile(figure_path, 'net_value_boxplot_baseline.pdf'));
    exportgraphics(fig_b, fullfile(figure_path, 'net_value_boxplot_baseline.png'), ...
        'ContentType', 'image', 'Resolution', 600);
    close(fig_b);

    baseline_table = table("baseline", "Status quo response", mean_base, med_b, ...
        perc_10_90_b(1), perc_15_b, perc_20_b, q1_b, q3_b, perc_10_90_b(2), 'VariableNames', moment_names);
    writetable(baseline_table, fullfile(processed_dir, "net_value_boxplot_moments_baseline.csv"));

end

function [row_tag, accent] = parse_grid_scenario_tag(scen_name)
    % Parse scenario name into investment row tag and BCR or surplus accent.
    scen = char(scen_name);
    accent = "";
    row_tag = "";

    if startsWith(scen, "improved_early_warning") && ~contains(scen, "and_")
        row_tag = "improved_early_warning";
        if contains(scen, "high_threshold") || contains(scen, "bcr")
            accent = "BCR";
        elseif contains(scen, "low_threshold") || contains(scen, "surplus")
            accent = "Surplus";
        end
    elseif startsWith(scen, "advance_capacity") && ~contains(scen, "and_")
        row_tag = "advance_capacity";
        if contains(scen, "9_month") || contains(scen, "bcr")
            accent = "BCR";
        elseif contains(scen, "6_month") || contains(scen, "surplus")
            accent = "Surplus";
        end
    elseif startsWith(scen, "neglected_pathogen_rd") && ~contains(scen, "and_")
        row_tag = "neglected_pathogen_rd";
        if contains(scen, "single") || contains(scen, "bcr")
            accent = "BCR";
        elseif contains(scen, "all") || contains(scen, "surplus")
            accent = "Surplus";
        end
    elseif startsWith(scen, "universal_flu_rd") && ~contains(scen, "and_")
        row_tag = "universal_flu_rd";
        if contains(scen, "single") || contains(scen, "bcr")
            accent = "BCR";
        elseif contains(scen, "both") || contains(scen, "surplus")
            accent = "Surplus";
        end
    elseif startsWith(scen, "combined_invest")
        row_tag = "combined_invest";
        if contains(scen, "bcr")
            accent = "BCR";
        elseif contains(scen, "surplus")
            accent = "Surplus";
        end
    end
end
