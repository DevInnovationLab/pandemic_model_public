function plot_bootstrap_violins(out_dir)
    % PLOT_BOOTSTRAP_VIOLIONS
    % Plot horizontal violin plots of bootstrap means of net value for each scenario.
    %
    % This function uses the same scenario ordering and y-axis layout as
    % plot_dot_whisker, but replaces dot-whisker summaries with violins
    % showing the distribution of bootstrap means across samples.
    %
    % Args:
    %   out_dir (string): Job output directory containing 'processed' and 'figures'.

    result = 'net_value_pv';
    col_name = [result '_full'];
    n_bootstrap = 200;

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
        warning('plot_bootstrap_violions: no scenarios found in %s', out_dir);
        return;
    end

    % Pre-compute bootstrap means for each scenario
    boot_means = cell(n, 1);
    boot_means_min = inf;
    boot_means_max = -inf;
    mean_of_boot = nan(n, 1);

    for k = 1:n
        sum_file = fullfile(processed_dir, scenarios_ordered{k} + "_relative_sums.mat");
        S = load(sum_file, 'all_relative_sums');
        data = S.all_relative_sums.(col_name);

        this_boot = bootstrp(n_bootstrap, @mean, data);
        boot_means{k} = this_boot;
        mean_of_boot(k) = mean(this_boot);

        boot_means_min = min(boot_means_min, min(this_boot));
        boot_means_max = max(boot_means_max, max(this_boot));
    end

    if ~isfinite(boot_means_min) || ~isfinite(boot_means_max) || boot_means_min == boot_means_max
        range_pad = max(1, abs(boot_means_min));
        boot_means_min = boot_means_min - 0.5 * range_pad;
        boot_means_max = boot_means_max + 0.5 * range_pad;
    end

    x_grid = linspace(boot_means_min, boot_means_max, 200);

    % Figure: horizontal violins with same y layout as dot-whisker
    fig = figure('Visible', 'off', 'Position', [100 100 750 520]);
    ax = axes('Position', [0.25 0.14 0.58 0.82]);
    hold(ax, 'on');

    y_pos = (1:n)';
    violin_half_width = 0.35;

    cmap_base = [0.38 0.55 0.84];  % base color for violins
    face_color = 0.85 + 0.15 * (cmap_base - 0.5);  % lighten base color a bit
    h_violin_example = [];

    for k = 1:n
        this_boot = boot_means{k};
        if numel(this_boot) < 2
            % Degenerate: plot a small marker only
            plot(ax, this_boot, y_pos(k), 'ko', 'MarkerFaceColor', 'k', ...
                 'MarkerSize', 5, 'LineWidth', 1.0);
            continue;
        end

        % Kernel density estimate of bootstrap means
        try
            pdf_vals = ksdensity(this_boot, x_grid);
        catch
            % If ksdensity fails for any reason, fall back to a flat shape
            pdf_vals = ones(size(x_grid));
        end

        if all(~isfinite(pdf_vals)) || max(pdf_vals) <= 0
            pdf_scaled = ones(size(pdf_vals)) * 0.1;
        else
            pdf_scaled = pdf_vals / max(pdf_vals);
        end
        pdf_scaled = pdf_scaled * violin_half_width;

        % Construct horizontal violin polygon
        x_poly = [x_grid, fliplr(x_grid)];
        y_poly = [y_pos(k) - pdf_scaled, fliplr(y_pos(k) + pdf_scaled)];

        h_violin = patch('XData', x_poly, 'YData', y_poly, ...
              'FaceColor', face_color, 'EdgeColor', cmap_base .* [0.7 0.7 0.7], ...
              'FaceAlpha', 0.75, 'EdgeAlpha', 0.9, 'LineWidth', 0.8, ...
              'Parent', ax);

        if isempty(h_violin_example)
            h_violin_example = h_violin;
        end
    end

    % Overlay mean of bootstrap means as solid dots
    h_mean = plot(ax, mean_of_boot, y_pos, 'ko', 'MarkerFaceColor', 'k', ...
        'MarkerSize', 5.5, 'LineWidth', 1.1);

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

    x_range = boot_means_max - boot_means_min;
    if x_range < 1e-6
        x_range = max(1, abs(boot_means_max));
    end
    x_lo = boot_means_min - 0.08 * x_range;
    x_hi = boot_means_max + 0.05 * x_range;
    ax.XLim = [x_lo, x_hi];

    ax.XGrid = 'on'; ax.YGrid = 'on';
    ax.GridAlpha = 0.13;

    % Outer y labels (investment groups) in left margin, mirroring plot_dot_whisker
    [~, ~, grp_id] = unique(outer_labels, 'stable');
    ax_pos = ax.Position;
    for g = 1:max(grp_id)
        idx = find(grp_id == g);
        y_center = mean(idx);

        if n == 1
            group_frac = 0.5;
        else
            group_frac = (n - y_center) / (n - 1);
        end
        fig_y = ax_pos(2) + ax_pos(4) * group_frac;
        annotation(fig, 'textbox', [0.01 fig_y - 0.022 0.13 0.045], ...
            'String', outer_labels{idx(1)}, 'EdgeColor', 'none', ...
            'FontWeight', 'bold', 'FontSize', 10, 'VerticalAlignment', 'middle', ...
            'HorizontalAlignment', 'right', 'Interpreter', 'none');
    end

    % Legend for mean marker and violin distribution, visually below x-axis labels
    lgd = legend(ax, [h_mean, h_violin_example], ...
        {'Sample mean', 'Bootstrap means distribution'}, ...
        'Location', 'southwest', 'Orientation', 'horizontal', ...
        'FontSize', 9, 'Interpreter', 'none', 'Box', 'off');
    lgd.Units = 'normalized';
    ax_pos = ax.Position;
    % Center legend horizontally under the axis, just below the x-axis label
    legend_width = 0.35;
    legend_height = 0.05;
    legend_x = ax_pos(1) + (ax_pos(3) - legend_width) / 2;
    % Place legend a bit further below the x-axis label while keeping it inside figure
    legend_y = max(0.01, ax_pos(2) - legend_height - 0.12);
    lgd.Position = [legend_x, legend_y, legend_width, legend_height];

    title(ax, 'Bootstrap means of net value across scenarios', 'FontSize', 12);

    saveas(fig, fullfile(figure_path, 'net_value_bootstrap_violins.jpg'));
    close(fig);
end

function [row_tag, accent] = parse_grid_scenario_tag(scen_name)
    % Parse scenario name into investment row tag and BCR or surplus accent.
    %
    % This helper mirrors the logic used in plot_dot_whisker so that
    % scenario ordering and grouping stay consistent across plots.

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

