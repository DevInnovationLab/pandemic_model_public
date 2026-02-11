function get_result_distribution(job_dir, results)
    % GET_RESULT_DISTRIBUTION
    % Generates distribution plots for simulation results using full horizon sums
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results
    %   results (cell array, optional): Cell array of result types to plot
    %                                   Default: {'net_value_pv', 'lives_saved'}

    % Set default results if not provided
    if nargin < 2 || isempty(results)
        results = {'net_value_pv', 'lives_saved'};
    end

    % Set up paths
    rawdata_dir = fullfile(job_dir, "processed");
    figure_path = fullfile(job_dir, "figures");
    if ~exist(figure_path, 'dir')
        mkdir(figure_path);
    end

    job_config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = string(fieldnames(job_config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, "baseline"));

    % Number of bootstrap samples
    n_bootstrap = 200;

    for j = 1:length(results)
        result = results{j};

        n_scenarios = length(scenarios);
        n_cols = min(3, n_scenarios);
        n_rows = ceil(n_scenarios / n_cols);

        % Figure 1: Normal y-scale
        fig_normal = figure('Visible', 'off', 'Position', [100 100 400*n_cols 300*n_rows]);
        % Figure 2: Log-y scale
        fig_log = figure('Visible', 'off', 'Position', [100 100 400*n_cols 300*n_rows]);

        for i = 1:n_scenarios
            scen_name = scenarios(i);
            sum_table_file = fullfile(rawdata_dir, sprintf("%s_relative_sums.mat", scen_name));
            load(sum_table_file, 'all_relative_sums');

            % Get the full horizon column for this result
            col_name = strcat(result, '_full');
            data = all_relative_sums.(col_name);

            % Set labels based on result type
            switch result
                case 'tot_benefits_pv'
                    ylabel_text = 'Net value (PV, $)';
                    title_text = sprintf('%s: Benefits', scen_name);
                case 'm_deaths'
                    ylabel_text = 'Lives saved';
                    title_text = sprintf('%s: Lives saved', scen_name);
                otherwise
                    ylabel_text = result;
                    title_text = sprintf('%s: %s', scen_name, result);
            end

            % Bootstrap: sample means, get mean + 2.5/97.5 percentiles (95% CI)
            bootstat = bootstrp(n_bootstrap, @mean, data);
            mean_val = mean(data);
            boot_CI = prctile(bootstat, [2.5, 97.5]);

            % -- Replace zeros with a very small positive value for log scale plot
            epsilon = min([1e-6, min(data(data > 0))/100]); % scale epsilon if possible
            data_logsafe = data;
            data_logsafe(data_logsafe <= 0) = epsilon;

            % ----- Normal y-scale subplot -----
            figure(fig_normal);
            subplot(n_rows, n_cols, i);
            hold on;
            % Histogram (empirical)
            h = histogram(data, 'Normalization', 'pdf', ...
                'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.6, ...
                'EdgeColor', 'none', 'DisplayName', 'Empirical');

            % Plot mean and 95% CI
            yl = ylim;
            p1 = plot([mean_val mean_val], yl, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Mean');
            p2 = plot([boot_CI(1) boot_CI(1)], yl, 'r-', 'LineWidth', 1.2, 'DisplayName', '95% CI');
            plot([boot_CI(2) boot_CI(2)], yl, 'r-', 'LineWidth', 1.2); % 2nd CI line

            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 10;
            ax.TickDir = 'out';

            xlabel(ylabel_text, 'FontSize', 11);
            ylabel('Density', 'FontSize', 11);
            title(title_text, 'FontSize', 12, 'FontWeight', 'normal');
            if i == 1
                legend([h p1 p2], {'Empirical', 'Mean', '95% CI'}, 'Location', 'best', 'FontSize', 9, 'Box', 'off');
            end
            hold off;

            % ----- LOG y-scale subplot -----
            figure(fig_log);
            subplot(n_rows, n_cols, i);
            hold on;
            % Histogram (empirical, but with replaced zeros for log)
            h_log = histogram(data_logsafe, 'Normalization', 'pdf', ...
                'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.6, ...
                'EdgeColor', 'none', 'DisplayName', 'Empirical');

            yl = ylim;
            % Set log scale on y
            set(gca, 'YScale', 'log');
            % Guard: set yticks only >0 to avoid log(0) issues
            ytick = get(gca, 'YTick');
            ytick(ytick == 0) = [];
            set(gca, 'YTick', ytick);

            % Plot mean and CI lines
            p1_log = plot([mean_val mean_val], yl, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Mean');
            p2_log = plot([boot_CI(1) boot_CI(1)], yl, 'r-', 'LineWidth', 1.2, 'DisplayName', '95% CI');
            plot([boot_CI(2) boot_CI(2)], yl, 'r-', 'LineWidth', 1.2);

            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 10;
            ax.TickDir = 'out';

            xlabel(ylabel_text, 'FontSize', 11);
            ylabel('Density (log scale)', 'FontSize', 11);
            title([title_text, ' (log y)'], 'FontSize', 12, 'FontWeight', 'normal');
            if i == 1
                legend([h_log p1_log p2_log], {'Empirical', 'Mean', '95% CI'}, 'Location', 'best', 'FontSize', 9, 'Box', 'off');
            end
            hold off;
        end

        % Save both figures
        saveas(fig_normal, fullfile(figure_path, sprintf('%s_dist_normal.jpg', result)));
        saveas(fig_log, fullfile(figure_path, sprintf('%s_dist_logy.jpg', result)));
        close(fig_normal);
        close(fig_log);
    end
end