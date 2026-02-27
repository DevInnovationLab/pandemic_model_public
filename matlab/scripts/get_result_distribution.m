function get_result_distribution(job_dir, results)
    % GET_RESULT_DISTRIBUTION
    % Generate distribution plots for scenario results using full-horizon sums.
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results.
    %   results (cell array, optional): Cell array of result types to plot.
    %                                   Default: {'net_value_pv'}.
    %
    % By default, this function produces grid histogram plots.
    % Columns are BCR/Surplus, rows are investments types. No subplot for baseline.

    if nargin < 2 || isempty(results)
        results = {'net_value_pv'};
    end

    % Investment types and nice labels in row order
    investment_tags = {'improved_early_warning', ...
                       'advance_capacity', ...
                       'neglected_pathogen_rd', ...
                       'universal_flu_rd', ...
                       'combined_invest'};
    investment_labels = {'Improved early warning', ...
                         'Advance capacity', ...
                         'Neglected pathogen R&D', ...
                         'Universal flu vaccine R&D', ...
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
    position_map = containers.Map(); % scenario name -> [row,col]
    scenario_grid_labels = cell(n_rows, n_cols); % grid cell stores scenario or empty

    % Assign scenarios to (row, col) in grid, only if that investment-accent present
    for i = 1:n_rows
        for j = 1:n_cols
            found_idx = [];
            for si = 1:numel(all_scenarios)
                scen = all_scenarios(si);
                [row_tag, accent] = parse_grid_scenario_tag(scen); % Helper below
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
    num_bins = 20; % for all

    % --- For each result type (e.g., net_value_pv), plot grid of distributions ---
    for jj = 1:length(results)
        result = results{jj};

        % Convert result variable name to nice title string for the figure
        result_title = prettify_result_name(result);

        data_grid     = cell(n_rows, n_cols);
        mean_grid     = nan(n_rows, n_cols);
        bootCIs_grid  = nan(n_rows, n_cols, 2);

        % Gather all data (for global binning)
        all_data_flat = [];
        for i = 1:n_rows
            for j = 1:n_cols
                scen_name = scenario_grid_labels{i, j};
                if strlength(scen_name)==0; continue; end
                sum_table_file = fullfile(rawdata_dir, sprintf("%s_relative_sums.mat", scen_name));
                if ~exist(sum_table_file, "file"); continue; end
                load(sum_table_file, 'all_relative_sums');
                col_name = strcat(result, '_full');
                data = all_relative_sums.(col_name);
                data_grid{i, j} = data;
                all_data_flat = [all_data_flat; data];
            end
        end

        min_val = min(all_data_flat);
        max_val = max(all_data_flat);
        if min_val == max_val
            min_val = min_val - 0.5;
            max_val = max_val + 0.5;
        end
        bin_edges = linspace(min_val, max_val, num_bins + 1);

        % ---- Summary tables: negatives and bin probabilities ----
        neg_rows = {};
        bin_rows = {};

        for i = 1:n_rows
            for j = 1:n_cols
                scen_name = scenario_grid_labels{i, j};
                data = data_grid{i, j};

                if isempty(data) || strlength(scen_name) == 0
                    continue;
                end

                n_samples = numel(data);
                n_negative = sum(data < 0);
                p_negative = n_negative / n_samples;

                % Row for negative summary table
                neg_rows(end+1, :) = {char(scen_name), investment_labels{i}, col_accents{j}, ...
                                      n_samples, n_negative, p_negative}; %#ok<AGROW>

                % Rows for bin probability table
                probs = histcounts(data, bin_edges, 'Normalization', 'probability');
                for b = 1:num_bins
                    bin_rows(end+1, :) = {char(scen_name), investment_labels{i}, col_accents{j}, ...
                                          bin_edges(b), bin_edges(b+1), probs(b)}; %#ok<AGROW>
                end
            end
        end

        if ~isempty(neg_rows)
            neg_table = cell2table(neg_rows, ...
                'VariableNames', {'Scenario', 'InvestmentType', 'Accent', ...
                                  'NumSamples', 'NumNegative', 'ProbNegative'});
            writetable(neg_table, fullfile(rawdata_dir, sprintf('%s_negative_summary.csv', result)));
        end

        if ~isempty(bin_rows)
            bin_table = cell2table(bin_rows, ...
                'VariableNames', {'Scenario', 'InvestmentType', 'Accent', ...
                                  'BinLower', 'BinUpper', 'Probability'});
            writetable(bin_table, fullfile(rawdata_dir, sprintf('%s_bin_probabilities.csv', result)));
        end

        % ---- Linear scale ----
        fig_normal = figure('Visible', 'off', 'Position', [100 100 1050 1050]);

        for i = 1:n_rows
            for j = 1:n_cols
                idx = sub2ind([n_cols n_rows], j, i); % MATLAB is column major (but subplot row,col ordering is inverse of our grid)
                subplot(n_rows, n_cols, (i-1)*n_cols + j);

                data = data_grid{i, j};
                if isempty(data); box off; axis off; continue; end

                h = histogram(data, 'BinEdges', bin_edges, 'Normalization', 'pdf', ...
                    'FaceAlpha', 0.7, 'EdgeColor', 'none');
                hold on;

                bootstat = bootstrp(n_bootstrap, @mean, data);
                mean_val = mean(data); mean_grid(i,j) = mean_val;
                bootCI = prctile(bootstat, [2.5, 97.5]); bootCIs_grid(i,j,:) = bootCI;
                yl = ylim;

                % Mean and CI
                plot([mean_val mean_val], yl, '--k', 'LineWidth', 1.1);
                plot([bootCI(1) bootCI(1)], yl, '-r', 'LineWidth', 0.8);
                plot([bootCI(2) bootCI(2)], yl, '-r', 'LineWidth', 0.8);

                % Style -- only major ticks, no minor grid lines
                box off; ax = gca;
                ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridAlpha = 0.13;
                ax.LineWidth = 1; ax.FontSize = 10; ax.TickDir = 'out';
                ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off'; % REMOVE minor grid
                grid on;

                % Only show labels on edge subplots
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
                    ylabel('Density', 'FontSize', 11);
                end
            end
        end

        % Column labels (move them up for clarity)
        col_label_ypos = 1.12; % Increase from default to add space
        for j = 1:n_cols
            subplot(n_rows, n_cols, j);
            t = title(col_accents{j}, 'FontWeight', 'bold', 'FontSize', 13);
            t.Units = 'normalized';
            t.Position(2) = col_label_ypos; % Move up for extra space
        end

        % Row labels (on first col), JUST beyond y-axis and vertically centered in axis
        for i = 1:n_rows
            subplot(n_rows, n_cols, (i-1)*n_cols + 1);
            ax = gca;
            yl = ylim;
            ymid = mean(yl);

            % Find a reasonable gap from y-label: use xlim and a fraction beyond min(xlim)
            xl = xlim;
            xgap = (xl(2) - xl(1)) * 0.2; % 20% of range beyond axis minimum
            xpos = xl(1) - xgap;

            text(xpos, ymid, investment_labels{i}, ...
                'HorizontalAlignment', 'center', ...
                'Rotation', 90, ...
                'FontWeight', 'bold', ...
                'FontSize', 10, ...
                'Interpreter', 'none');
        end

        % Nicer, well-formatted figure title (readable, not snake_case)
        annotation(fig_normal, 'textbox', [0 0.97 1 0.025], ...
            'String', sprintf('%s across simulations', result_title), ...
            'EdgeColor', 'none', ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 14);

        print(fig_normal, fullfile(figure_path, sprintf('%s_dist_grid_normal', result)), '-djpeg', '-r600');
        close(fig_normal);

        % ---- Log scale ----
        fig_log = figure('Visible', 'off', 'Position', [100 100 1050 1050]);

        % Calculate the full Y axis limits for each row (for leftmost subplot), so we can align row labels with center of each row's displayed y-range
        row_ylims_log = zeros(n_rows, 2); % [ymin ymax] for each row's first column subplot after logscale
        for i = 1:n_rows
            subplot(n_rows, n_cols, (i-1)*n_cols + 1);
            data = data_grid{i, 1};
            if isempty(data)
                row_ylims_log(i, :) = [NaN NaN];
            else
                h = histogram(data, 'BinEdges', bin_edges, 'Normalization', 'pdf', ...
                    'FaceAlpha', 0.7, 'EdgeColor', 'none');
                set(gca, 'YScale', 'log');
                drawnow; % force axis update
                row_ylims_log(i, :) = ylim;
            end
        end

        for i = 1:n_rows
            for j = 1:n_cols
                subplot(n_rows, n_cols, (i-1)*n_cols + j);
                data = data_grid{i, j};
                if isempty(data); box off; axis off; continue; end

                histogram(data, 'BinEdges', bin_edges, 'Normalization', 'pdf', ...
                    'FaceAlpha', 0.7, 'EdgeColor', 'none');
                hold on;

                bootstat = bootstrp(n_bootstrap, @mean, data);
                mean_val = mean(data);
                bootCI = prctile(bootstat, [2.5,97.5]);
                yl = ylim;

                plot([mean_val mean_val], yl, '--k', 'LineWidth', 1.1);
                plot([bootCI(1) bootCI(1)], yl, '-r', 'LineWidth', 0.8);
                plot([bootCI(2) bootCI(2)], yl, '-r', 'LineWidth', 0.8);

                set(gca, 'YScale', 'log');
                ax = gca;
                ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridAlpha = 0.13;
                ax.LineWidth = 1; ax.FontSize = 10; ax.TickDir = 'out';
                ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off';
                grid on;

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
                    ylabel('Density', 'FontSize', 11);
                end
            end
        end

        % Column labels for log plot (space as for normal plot)
        for j = 1:n_cols
            subplot(n_rows, n_cols, j);
            t = title(col_accents{j}, 'FontWeight', 'bold', 'FontSize', 13);
            t.Units = 'normalized';
            t.Position(2) = col_label_ypos;
        end

        % Row labels for log plot -- vertical position more robust to log scale axis
        for i = 1:n_rows
            subplot(n_rows, n_cols, (i-1)*n_cols + 1);
            ax = gca;
            % Use saved row_ylims_log for vertical center regardless of current auto ylims
            yl_fix = row_ylims_log(i, :);
            if any(isnan(yl_fix))
                continue; % row was empty
            end
            % ymid in log space
            ymid_log = 10^mean(log10(yl_fix));
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
            'String', sprintf('%s across simulations', result_title), ...
            'EdgeColor', 'none', ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 14);

        print(fig_log, fullfile(figure_path, sprintf('%s_dist_grid_logy', result)), '-djpeg', '-r600');
        close(fig_log);
    end
end

% --- Helper for grid: gets row/col for a scenario name
function [row_tag, accent] = parse_grid_scenario_tag(scen_name)
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

% --- Helper to prettify result variable names to readable figure titles
function pretty = prettify_result_name(result_var)
    switch lower(result_var)
        case {'net_value_pv', 'netvaluepv'}
            pretty = 'Net Value ($ PV)';
        case {'lives_saved', 'livessaved'}
            pretty = 'Lives Saved';
        case {'bcr'}
            pretty = 'Benefit-Cost Ratio';
        case {'surplus'}
            pretty = 'Surplus';
        otherwise
            % Replace underscores with spaces and capitalize words
            pretty = regexprep(result_var, '_', ' ');
            pretty = lower(pretty);
            pretty(1) = upper(pretty(1));
            underscore_idx = strfind(pretty, ' ');
            for k = underscore_idx
                if k < length(pretty)
                    pretty(k+1) = upper(pretty(k+1));
                end
            end
        end
end