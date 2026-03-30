function plot_exceedance_curves(job_dir, results)
    % PLOT_EXCEEDANCE_CURVES
    % Plot exceedance curves for scenario result distributions on normal and log-y scales.
    %
    % This function mirrors the grid layout of get_result_distribution.m but
    % replaces histograms with exceedance curves. For each scenario and
    % result type, it:
    %   - selects a common set of thresholds over the global data range,
    %   - bootstraps exceedance probabilities at those thresholds, and
    %   - plots the median and 5th/95th percentile exceedance curves.
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results.
    %   results (cell array, optional): Cell array of result types to plot.
    %                                   Default: {'net_value_pv'}.

    if nargin < 2 || isempty(results)
        results = {'net_value_pv'};
    end

    % Investment types and labels, row order
    % Program order and labels: advance capacity, prototype vaccine R&D,
    % universal flu vaccine R&D, improved early warning, combined.
    investment_tags = {'advance_capacity', ...
                       'neglected_pathogen_rd', ...
                       'universal_flu_rd', ...
                       'improved_early_warning', ...
                       'combined_invest'};
    investment_labels = {'Advance capacity', ...
                         'Prototype vaccine R&D', ...
                         'Universal flu vaccine R&D', ...
                         'Improved early warning', ...
                         'Combined'};

    col_accents = {'BCR', 'Surplus'};

    n_rows = numel(investment_tags);
    n_cols = numel(col_accents);

    rawdata_dir = fullfile(job_dir, "processed");
    figure_path = fullfile(job_dir, "figures");
    if ~exist(figure_path, 'dir'); mkdir(figure_path); end

    job_config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    all_scenarios = string(fieldnames(job_config.scenarios));
    all_scenarios = all_scenarios(~strcmp(all_scenarios, "baseline"));

    % -------- Map scenarios to (row,col) --------
    position_map = containers.Map(); % scenario name -> [row,col] (kept for symmetry)
    scenario_grid_labels = cell(n_rows, n_cols); % grid cell stores scenario or empty

    for i = 1:n_rows
        for j = 1:n_cols
            found_idx = [];
            for si = 1:numel(all_scenarios)
                scen = all_scenarios(si);
                [row_tag, accent] = parse_grid_scenario_tag_exceed(scen);
                if strcmp(row_tag, investment_tags{i}) && strcmpi(accent, col_accents{j})
                    found_idx = si; break;
                end
            end
            if ~isempty(found_idx)
                scenario_grid_labels{i, j} = all_scenarios(found_idx);
                position_map(all_scenarios(found_idx)) = [i, j];
            else
                scenario_grid_labels{i, j} = "";
            end
        end
    end

    n_bootstrap = 200;
    n_thresholds = 40;

    % --- For each result type, construct exceedance grids ---
    for jj = 1:length(results)
        result = results{jj};
        result_title = prettify_result_name_exceed(result);

        data_grid = cell(n_rows, n_cols);

        % Gather all data for global thresholds
        all_data_flat = [];
        for i = 1:n_rows
            for j = 1:n_cols
                scen_name = scenario_grid_labels{i, j};
                if strlength(scen_name) == 0
                    continue;
                end
                sum_table_file = fullfile(rawdata_dir, sprintf("%s_relative_sums.mat", scen_name));
                if ~exist(sum_table_file, "file")
                    continue;
                end
                load(sum_table_file, 'all_relative_sums');
                col_name = strcat(result, '_full');
                if ~ismember(col_name, all_relative_sums.Properties.VariableNames)
                    continue;
                end
                data = all_relative_sums.(col_name);
                data_grid{i, j} = data;
                all_data_flat = [all_data_flat; data];
            end
        end

        if isempty(all_data_flat)
            warning('plot_exceedance_curves: no data found for result %s in %s', result, job_dir);
            continue;
        end

        min_val = min(all_data_flat);
        max_val = max(all_data_flat);
        if min_val == max_val
            min_val = min_val - 0.5;
            max_val = max_val + 0.5;
        end

        thresholds = linspace(min_val, max_val, n_thresholds);

        % Precompute bootstrap exceedance summaries for each cell
        med_exceed = cell(n_rows, n_cols);
        lo_exceed = cell(n_rows, n_cols);
        hi_exceed = cell(n_rows, n_cols);

        for i = 1:n_rows
            for j = 1:n_cols
                data = data_grid{i, j};
                if isempty(data)
                    continue;
                end

                n_samples = numel(data);
                if n_samples < 2
                    % With only one observation, exceedance is either 0 or 1/(n+1)
                    ex_probs = zeros(1, numel(thresholds));
                    ex_probs(data > thresholds) = 1 / (n_samples + 1);
                    med_exceed{i, j} = ex_probs;
                    lo_exceed{i, j} = ex_probs;
                    hi_exceed{i, j} = ex_probs;
                    continue;
                end

                % Bootstrap exceedance curves
                boot_exceed = nan(n_bootstrap, numel(thresholds));
                for b = 1:n_bootstrap
                    idx = randsample(n_samples, n_samples, true);
                    boot_sample = data(idx);
                    for t = 1:numel(thresholds)
                        boot_exceed(b, t) = sum(boot_sample > thresholds(t)) / (n_samples + 1);
                    end
                end

                med_exceed{i, j} = median(boot_exceed, 1);
                lo_exceed{i, j} = prctile(boot_exceed, 5, 1);
                hi_exceed{i, j} = prctile(boot_exceed, 95, 1);
            end
        end

        % ---- Normal y scale figure ----
        fig_normal = figure('Visible', 'off', 'Position', [100 100 1050 1050]);
        example_band_normal = [];
        example_line_normal = [];
        example_subplot_normal = [];

        for i = 1:n_rows
            for j = 1:n_cols
                subplot_idx = (i - 1) * n_cols + j;
                subplot(n_rows, n_cols, subplot_idx);
                data = data_grid{i, j};
                if isempty(data)
                    box off; axis off; continue;
                end

                med_y = med_exceed{i, j};
                lo_y = lo_exceed{i, j};
                hi_y = hi_exceed{i, j};

                hold on;

                % Shaded 5–95% band
                xx = [thresholds, fliplr(thresholds)];
                yy = [lo_y, fliplr(hi_y)];
                h_band = fill(xx, yy, [0.82 0.86 0.96], 'EdgeColor', 'none', 'FaceAlpha', 0.7);

                % Median curve
                h_line = plot(thresholds, med_y, '-', 'Color', [0.10 0.15 0.28], 'LineWidth', 1.5);

                if isempty(example_band_normal)
                    example_band_normal = h_band;
                    example_line_normal = h_line;
                    example_subplot_normal = subplot_idx;
                end

                box off; ax = gca;
                ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridAlpha = 0.13;
                ax.LineWidth = 1; ax.FontSize = 10; ax.TickDir = 'out';
                ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off';

                if i == n_rows
                    switch result
                        case 'net_value_pv'
                            xlabel('Net value (PV, $)', 'FontSize', 11);
                        case 'lives_saved'
                            xlabel('Lives saved', 'FontSize', 11);
                        otherwise
                            xlabel(result_title, 'FontSize', 11);
                    end
                end
                if j == 1
                    ylabel('Exceedance probability', 'FontSize', 11);
                end
            end
        end

        % Single legend explaining line and shaded band
        if ~isempty(example_band_normal)
            subplot(n_rows, n_cols, example_subplot_normal);
            legend([example_line_normal, example_band_normal], ...
                {'Median exceedance probability', '5th–95th percentile band'}, ...
                'Location', 'northeast', 'FontSize', 9, 'Box', 'off');
        end

        % Column labels
        col_label_ypos = 1.12;
        for j = 1:n_cols
            subplot(n_rows, n_cols, j);
            t = title(col_accents{j}, 'FontWeight', 'bold', 'FontSize', 13);
            t.Units = 'normalized';
            t.Position(2) = col_label_ypos;
        end

        % Row labels on first column
        for i = 1:n_rows
            subplot(n_rows, n_cols, (i - 1) * n_cols + 1);
            yl = ylim;
            ymid = mean(yl);
            xl = xlim;
            xgap = (xl(2) - xl(1)) * 0.2;
            xpos = xl(1) - xgap;
            text(xpos, ymid, investment_labels{i}, ...
                'HorizontalAlignment', 'center', ...
                'Rotation', 90, ...
                'FontWeight', 'bold', ...
                'FontSize', 10, ...
                'Interpreter', 'none');
        end

        annotation(fig_normal, 'textbox', [0 0.97 1 0.025], ...
            'String', sprintf('%s exceedance curves across simulations', result_title), ...
            'EdgeColor', 'none', ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 14);
        exportgraphics(fig_normal, fullfile(figure_path, sprintf('%s_exceed_grid_normal.pdf', result)), ...
            'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
        close(fig_normal);

        % ---- Log-y scale figure ----
        fig_log = figure('Visible', 'off', 'Position', [100 100 1050 1050]);
        example_band_log = [];
        example_line_log = [];
        example_subplot_log = [];

        % Determine a reasonable lower bound for log scale from all probabilities
        all_probs = [];
        for i = 1:n_rows
            for j = 1:n_cols
                if isempty(med_exceed{i, j})
                    continue;
                end
                all_probs = [all_probs, med_exceed{i, j}, lo_exceed{i, j}, hi_exceed{i, j}]; %#ok<AGROW>
            end
        end
        all_probs = all_probs(all_probs > 0);
        if isempty(all_probs)
            y_min_log = 1e-4;
        else
            y_min_log = min(min(all_probs) / 2, 1e-6);
        end

        for i = 1:n_rows
            for j = 1:n_cols
                subplot_idx = (i - 1) * n_cols + j;
                subplot(n_rows, n_cols, subplot_idx);
                data = data_grid{i, j};
                if isempty(data)
                    box off; axis off; continue;
                end

                med_y = med_exceed{i, j};
                lo_y = lo_exceed{i, j};
                hi_y = hi_exceed{i, j};

                % Avoid exact zeros on log scale by clipping to y_min_log
                med_y = max(med_y, y_min_log);
                lo_y = max(lo_y, y_min_log);
                hi_y = max(hi_y, y_min_log);

                hold on;

                xx = [thresholds, fliplr(thresholds)];
                yy = [lo_y, fliplr(hi_y)];
                h_band = fill(xx, yy, [0.82 0.86 0.96], 'EdgeColor', 'none', 'FaceAlpha', 0.7);

                h_line = plot(thresholds, med_y, '-', 'Color', [0.10 0.15 0.28], 'LineWidth', 1.5);

                if isempty(example_band_log)
                    example_band_log = h_band;
                    example_line_log = h_line;
                    example_subplot_log = subplot_idx;
                end

                set(gca, 'YScale', 'log');

                box off; ax = gca;
                ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridAlpha = 0.13;
                ax.LineWidth = 1; ax.FontSize = 10; ax.TickDir = 'out';
                ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off';

                if i == n_rows
                    switch result
                        case 'net_value_pv'
                            xlabel('Net value (PV, $)', 'FontSize', 11);
                        case 'lives_saved'
                            xlabel('Lives saved', 'FontSize', 11);
                        otherwise
                            xlabel(result_title, 'FontSize', 11);
                    end
                end
                if j == 1
                    ylabel('Exceedance probability', 'FontSize', 11);
                end
            end
        end

        % Single legend for log-y figure
        if ~isempty(example_band_log)
            subplot(n_rows, n_cols, example_subplot_log);
            legend([example_line_log, example_band_log], ...
                {'Median exceedance probability', '5th–95th percentile band'}, ...
                'Location', 'northeast', 'FontSize', 9, 'Box', 'off');
        end

        for j = 1:n_cols
            subplot(n_rows, n_cols, j);
            t = title(col_accents{j}, 'FontWeight', 'bold', 'FontSize', 13);
            t.Units = 'normalized';
            t.Position(2) = col_label_ypos;
        end

        % Row labels for log-y plot
        for i = 1:n_rows
            subplot(n_rows, n_cols, (i - 1) * n_cols + 1);
            yl = ylim;
            ymid_log = 10 ^ mean(log10(yl));
            xl = xlim;
            xgap = (xl(2) - xl(1)) * 0.2;
            xpos = xl(1) - xgap;
            text(xpos, ymid_log, investment_labels{i}, ...
                'HorizontalAlignment', 'center', ...
                'Rotation', 90, ...
                'FontWeight', 'bold', ...
                'FontSize', 10, ...
                'Interpreter', 'none');
        end

        annotation(fig_log, 'textbox', [0 0.97 1 0.025], ...
            'String', sprintf('%s exceedance curves across simulations', result_title), ...
            'EdgeColor', 'none', ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 14);
        exportgraphics(fig_log, fullfile(figure_path, sprintf('%s_exceed_grid_logy.pdf', result)), ...
            'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
        close(fig_log);
    end
end

function [row_tag, accent] = parse_grid_scenario_tag_exceed(scen_name)
    % Parse scenario name into investment row tag and BCR or surplus accent.

    scen = char(scen_name); % string to char
    accent = "";
    row_tag = "";

    if startsWith(scen, "improved_early_warning")
        row_tag = "improved_early_warning";
        if contains(scen, "high_threshold") || contains(scen, "bcr")
            accent = "BCR";
        elseif contains(scen, "low_threshold") || contains(scen, "surplus")
            accent = "Surplus";
        end
    elseif startsWith(scen, "advance_capacity")
        row_tag = "advance_capacity";
        if contains(scen, "9_month") || contains(scen, "bcr")
            accent = "BCR";
        elseif contains(scen, "6_month") || contains(scen, "surplus")
            accent = "Surplus";
        end
    elseif startsWith(scen, "neglected_pathogen_rd")
        row_tag = "neglected_pathogen_rd";
        if contains(scen, "single") || contains(scen, "bcr")
            accent = "BCR";
        elseif contains(scen, "all") || contains(scen, "surplus")
            accent = "Surplus";
        end
    elseif startsWith(scen, "universal_flu_rd")
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

function pretty = prettify_result_name_exceed(result_var)
    % Convert an internal result variable name to a readable figure title.

    switch lower(result_var)
        case {'net_value_pv', 'netvaluepv'}
            pretty = 'Net value ($ PV)';
        case {'lives_saved', 'livessaved'}
            pretty = 'Lives saved';
        case {'bcr'}
            pretty = 'Benefit-cost ratio';
        case {'surplus'}
            pretty = 'Surplus';
        otherwise
            pretty = regexprep(result_var, '_', ' ');
            pretty = lower(pretty);
            if ~isempty(pretty)
                pretty(1) = upper(pretty(1));
            end
            underscore_idx = strfind(pretty, ' ');
            for k = underscore_idx
                if k < length(pretty)
                    pretty(k + 1) = upper(pretty(k + 1));
                end
            end
    end
end

