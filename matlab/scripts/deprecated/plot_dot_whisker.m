function plot_dot_whisker(out_dir)
    % PLOT_DOT_WHISKER
    % Plot dot-whisker of net value (mean and raw 5--95%% sample range)
    % for each scenario. Y-axis: two levels (advance intervention outer, accent inner).
    %
    % Args:
    %   out_dir (string): Job output directory containing 'processed' and 'figures'.

    result = 'net_value_pv';
    col_name = [result '_full'];

    investment_tags = {'improved_early_warning', 'advance_capacity', 'neglected_pathogen_rd', ...
                       'universal_flu_rd', 'combined_invest'};
    investment_labels = {'Improved early warning', 'Advance capacity', 'Neglected pathogen R&D', ...
                         'Universal flu vaccine R&D', 'Combined'};
    col_accents = {'BCR', 'Surplus'};

    processed_dir = fullfile(out_dir, 'processed');
    figure_path = fullfile(out_dir, 'figures');
    if ~exist(figure_path, 'dir'), mkdir(figure_path); end

    job_config = yaml.loadFile(fullfile(out_dir, 'job_config.yaml'));
    all_scenarios = string(fieldnames(job_config.scenarios));
    all_scenarios = all_scenarios(~strcmp(all_scenarios, 'baseline'));

    % Build ordered list: (row, col) -> scenario name and labels
    scenarios_ordered = {};
    outer_labels = {};
    inner_labels = {};
    for i = 1:numel(investment_tags)
        for j = 1:numel(col_accents)
            for si = 1:numel(all_scenarios)
                scen = all_scenarios(si);
                [row_tag, accent] = parse_grid_scenario_tag(scen);
                if strcmp(row_tag, investment_tags{i}) && strcmpi(accent, col_accents{j})
                    sum_file = fullfile(processed_dir, scen + "_relative_sums.mat");
                    if exist(sum_file, 'file')
                        scenarios_ordered{end+1} = scen;
                        outer_labels{end+1} = investment_labels{i}; 
                        inner_labels{end+1} = col_accents{j};
                    end
                    break;
                end
            end
        end
    end

    n = numel(scenarios_ordered);
    if n == 0
        warning('plot_dot_whisker: no scenarios found in %s', out_dir);
        return;
    end

    mean_val = nan(n, 1);
    perc_range = nan(n, 2);

    for k = 1:n
        sum_file = fullfile(processed_dir, scenarios_ordered{k} + "_relative_sums.mat");
        load(sum_file, 'all_relative_sums');
        data = all_relative_sums.(col_name);
        mean_val(k) = mean(data);
        perc_range(k, :) = prctile(data, [5, 95]);
    end

    % Figure: horizontal dot-whisker, scenarios on y
    fig = figure('Visible', 'off', 'Position', [100 100 750 520]);
    ax = axes('Position', [0.25 0.14 0.58 0.82]);
    hold(ax, 'on');

    y_pos = (1:n)';
    % Whiskers and dots
    h_raw = gobjects(n,1);
    for k = 1:n
        h_raw(k)  = plot(ax, perc_range(k, :), [y_pos(k) y_pos(k)], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 2.4);
    end

    % Plot mean as dots (no confidence intervals)
    h_mean = plot(ax, mean_val, y_pos, 'o', ...
        'MarkerFaceColor', 'k', ...
        'MarkerEdgeColor', [0.05 0.07 0.13], ...
        'MarkerSize', 6.5);

    ax.YDir = 'reverse';
    ax.YLim = [0.5, n + 0.5];
    ax.YTick = 1:n;
    ax.YTickLabel = inner_labels;
    ax.TickLabelInterpreter = 'none';
    ax.FontSize = 10;
    ax.TickDir = 'out';
    ax.Box = 'off';
    ax.YAxisLocation = 'left';
    xlabel(ax, 'Net value (PV, $)', 'FontSize', 11);

    x_range = max(mean_val) - min(mean_val);
    if x_range < 1e-6, x_range = 1; end
    x_lo = min([mean_val; perc_range(:)]) - 0.08 * x_range;
    x_hi = max([mean_val; perc_range(:)]) + 0.05 * x_range;
    ax.XLim = [x_lo, x_hi];

    % Outer y labels (advance intervention) in left margin
    [~, ~, grp_id] = unique(outer_labels, 'stable');
    ax_pos = ax.Position;
    for g = 1:max(grp_id)
        idx = find(grp_id == g);
        y_center = mean(idx);

        if n == 1
            group_frac = 0.5;
        else
            group_frac = (n - y_center)/(n-1);
        end
        fig_y = ax_pos(2) + ax_pos(4) * group_frac;
        annotation(fig, 'textbox', [0.01 fig_y - 0.022 0.13 0.045], ...
            'String', outer_labels{idx(1)}, 'EdgeColor', 'none', ...
            'FontWeight', 'bold', 'FontSize', 10, 'VerticalAlignment', 'middle', ...
            'HorizontalAlignment', 'right', 'Interpreter', 'none');
    end

    % Legend
    legend(ax, ...
        [h_raw(1), h_mean], ...
        {'5--95% sample percentiles', 'Mean'}, ...
        'Location', 'best', ...
        'FontSize', 9, 'Interpreter','none');

    title(ax, 'Net value across scenarios', 'FontSize', 12);
    print(fig, fullfile(figure_path, 'net_value_dot_whisker'), '-djpeg', '-r600');
    close(fig);

end

function [row_tag, accent] = parse_grid_scenario_tag(scen_name)
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
