function plot_net_value_boxplot(out_dir)
    % Plot net value (PV) from raw results as a manual boxplot per scenario.
    % The box shows the interquartile range, the vertical line shows the median,
    % the whiskers show the 10th and 90th percentiles, and the dot shows the mean.
    % Y-axis: surplus-only investment programs in a single layer of labels.
    % Uses only raw sample data (no bootstrap).
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

    job_config = yaml.loadFile(fullfile(out_dir, 'job_config.yaml'));
    all_scenarios = string(fieldnames(job_config.scenarios));
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
    for k = 1:n
        d = all_data{k};
        if ~isempty(d)
            p = prctile(d, [10, 25, 50, 75, 90]);
            perc_10_90(k, :) = p([1, 5]);
            q1(k) = p(2);
            med(k) = p(3);
            q3(k) = p(4);
        end
    end

    box_hw = 0.32;
    face_color = [0.88 0.92 0.97];
    edge_color = [0.35 0.45 0.65];
    whisker_color = [0.5 0.5 0.5];

    fig = figure('Visible', 'off', 'Position', [100 100 750 520]);
    ax = axes('Position', [0.25 0.14 0.58 0.82]);
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

    % Legend: four entries (reversed order); median label only with no symbol, using a dummy handle.
    if ~isempty(h_whisker)
        h_median_legend = plot(ax, NaN, NaN, '-', ...
            'LineStyle', 'none', 'Marker', 'none');
        legend(ax, [h_mean, h_median_legend, h_whisker, h_box], ...
            {'Mean', 'Median', '10/90 percentiles', 'Interquartile range'}, ...
            'Location', 'northeast', 'FontSize', 9, 'Interpreter', 'none');
    end
    print(fig, fullfile(figure_path, 'net_value_boxplot'), '-djpeg', '-r600');
    close(fig);
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
