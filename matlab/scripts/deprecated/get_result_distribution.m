function get_result_distribution(job_dir, results)
    % GET_RESULT_DISTRIBUTIONS
    % Generates distribution plots for simulation results using full horizon sums
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results
    %   results (cell array, optional): Cell array of result types to plot
    %                                   Default: {'tot_benefits_pv', 'lives_saved'}
    
    % Set default results if not provided
    if nargin < 2 || isempty(results)
        results = {'tot_benefits_pv' 'lives_saved'};
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
    
    % Loop through each result type
    for j = 1:length(results)
        result = results{j};
        
        % Create TWO figures: one for raw data, one for bootstrap means
        n_scenarios = length(scenarios);
        n_cols = min(3, n_scenarios);
        n_rows = ceil(n_scenarios / n_cols);
        
        % Figure 1: Raw data distributions
        fig_raw = figure('Visible', 'off', 'Position', [100 100 400*n_cols 300*n_rows]);
        
        % Figure 2: Bootstrap mean distributions
        fig_boot = figure('Visible', 'off', 'Position', [100 100 400*n_cols 300*n_rows]);
        
        % Loop through scenarios
        for i = 1:n_scenarios
            scen_name = scenarios(i);
            
            % Load relative sums table for non-baseline scenarios
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
            
            % Bootstrap distribution of means
            bootstat = bootstrp(n_bootstrap, @mean, data);
            mean_val = mean(data);
            
            % ===== PLOT 1: Raw data distribution =====
            figure(fig_raw);
            subplot(n_rows, n_cols, i);
            hold on;
            
            disp("hi")
            % Plot histogram of raw data
            histogram(data, 'Normalization', 'pdf', ...
                     'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.6, ...
                     'EdgeColor', 'none', 'DisplayName', 'Empirical');
            
            % Add mean line
            yl = ylim;
            plot([mean_val mean_val], yl, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Mean');
            
            % Style the plot
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
                legend('Location', 'best', 'FontSize', 9, 'Box', 'off');
            end
            
            hold off;
            
            % ===== PLOT 2: Bootstrap mean distribution =====
            figure(fig_boot);
            subplot(n_rows, n_cols, i);
            hold on;
            
            % Plot bootstrap distribution of means as histogram
            histogram(bootstat, 'Normalization', 'pdf', ...
                     'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.6, ...
                     'EdgeColor', 'none', 'DisplayName', 'Bootstrap mean');
            
            % Add mean line
            yl = ylim;
            plot([mean_val mean_val], yl, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Mean');
            
            % Style the plot
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
            title([title_text ' (Bootstrap)'], 'FontSize', 12, 'FontWeight', 'normal');
            
            if i == 1
                legend('Location', 'best', 'FontSize', 9, 'Box', 'off');
            end
            
            hold off;
        end
        
        % Save both figures
        saveas(fig_raw, fullfile(figure_path, sprintf('%s_distributions_raw.jpg', result)));
        saveas(fig_boot, fullfile(figure_path, sprintf('%s_distributions_bootstrap.jpg', result)));
        close(fig_raw);
        close(fig_boot);
    end
end