function plot_complementarity_raw(complementarity_data, metric_label, accent_label, figure_path, sample_size)
    % PLOT_COMPLEMENTARITY_RAW
    % Creates raw distribution plots for complementarities between preparedness investments
    % Reorganized as a matrix: rows and columns both represent investments
    %
    % Args:
    %   complementarity_data: Struct containing complementarity data
    %   metric_label: Label for the metric being plotted
    %   accent_label: Label for the accent (BCR or Surplus)
    %   figure_path: Path to save figures
    %   sample_size: Number of simulations (for reference)
    
    investments = {'advance_capacity', 'neglected_pathogen', 'universal_flu', 'early_warning'};
    investment_types = containers.Map({'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'}, ...
        {'Improved early warning', 'Advance capacity', 'Prototype vaccine R&D', 'Universal flu vaccine'});
    
    % Count valid investment types (those with data)
    valid_investments = {};
    for i = 1:length(investments)
        inv = investments{i};
        if isfield(complementarity_data, inv) && ...
           isfield(complementarity_data.(inv), 'data') && ...
           ~isempty(complementarity_data.(inv).data)
            valid_investments{end+1} = inv;
        end
    end
    
    if isempty(valid_investments)
        fprintf('No valid complementarity data found for %s %s\n', metric_label, accent_label);
        return;
    end
    
    % Reorganize data into matrix format: data_matrix{i,j} contains complementarity between i and j
    n_investments = length(investments);
    data_matrix = cell(n_investments, n_investments);
    
    for i = 1:n_investments
        inv_i = investments{i};
        if ~isfield(complementarity_data, inv_i)
            continue;
        end
        
        % Get standalone data (diagonal)
        configs = complementarity_data.(inv_i).configs;
        data_list = complementarity_data.(inv_i).data;
        
        % Find standalone
        alone_idx = find(strcmp(configs, 'alone'), 1);
        if ~isempty(alone_idx)
            data_matrix{i, i} = data_list{alone_idx};
        end
        
        % Find combinations with other investments
        for j = 1:n_investments
            if i == j
                continue; % Already handled diagonal
            end
            inv_j = investments{j};
            with_j_pattern = ['with_' inv_j];
            with_j_idx = find(cellfun(@(x) contains(x, with_j_pattern), configs), 1);
            if ~isempty(with_j_idx)
                data_matrix{i, j} = data_list{with_j_idx};
                % Complementarity is symmetric, so also store in reverse direction
                % But only if that cell is empty (don't overwrite if already set)
                if isempty(data_matrix{j, i})
                    data_matrix{j, i} = data_list{with_j_idx};
                end
            end
        end
    end
    
    % Create figures: raw distributions and relative to combined
    spec = get_paper_figure_spec("grid_2xn", "GridCols", n_investments);
    fig_raw = figure('Visible', 'off', 'Units', 'inches', ...
        'Position', [1 1 spec.width_in spec.height_in], ...
        'DefaultAxesFontName', spec.font_name, ...
        'DefaultAxesFontSize', spec.typography.tick);
    fig_raw_pct = figure('Visible', 'off', 'Units', 'inches', ...
        'Position', [1 1 spec.width_in spec.height_in], ...
        'DefaultAxesFontName', spec.font_name, ...
        'DefaultAxesFontSize', spec.typography.tick);
    fig_relative = figure('Visible', 'off', 'Units', 'inches', ...
        'Position', [1 1 spec.width_in spec.height_in], ...
        'DefaultAxesFontName', spec.font_name, ...
        'DefaultAxesFontSize', spec.typography.tick);
    
    % Extract simple metric name (remove "complementarity")
    simple_metric = strrep(metric_label, ' complementarity', '');
    
    % Plot matrix: row i, column j
    for i = 1:n_investments
        inv_i = investments{i};
        inv_i_label = investment_types(inv_i);
        
        for j = 1:n_investments
            inv_j = investments{j};
            inv_j_label = investment_types(inv_j);
            
            % Always create subplot to maintain grid structure
            subplot_idx = (i - 1) * n_investments + j;
            
            % ===== PLOT 1: Raw data distribution =====
            figure(fig_raw);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            % Get data for this cell
            if ~isempty(data_matrix{i, j})
                data = data_matrix{i, j};
                
                % Check if data is valid (not all NaN, not empty)
                if ~isempty(data) && ~all(isnan(data)) && length(data) > 0
                    % Create histogram
                    histogram(data, 50, 'Normalization', 'probability', ...
                             'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.6, ...
                             'EdgeColor', 'none');
                    
                    mean_val = mean(data, 'omitnan');
                    
                    % Add mean line
                    yl = ylim;
                    if ~isnan(mean_val)
                        plot([mean_val mean_val], yl, 'k--', 'LineWidth', 1.5);
                    end
                    if i ~= j  % Only show zero line for complementarities, not standalones
                        plot([0 0], yl, 'r:', 'LineWidth', 1); % Zero line
                    end
                end
            end
            
            % Style
            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 9;
            ax.TickDir = 'out';
            
            % Labels
            xlabel(simple_metric, 'FontSize', 10);
            if j == 1
                ylabel('Probability', 'FontSize', 10);
            end
            
            % Add row label on left side for first column
            if j == 1
                text(-0.3, 0.5, inv_i_label, 'Units', 'normalized', ...
                     'Rotation', 90, 'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            % Add column label on top for first row
            if i == 1
                text(0.5, 1.15, inv_j_label, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            hold off;

            % ===== PLOT 2: Raw data distribution (% deviation from mean) =====
            figure(fig_raw_pct);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            % Get data for this cell
            if ~isempty(data_matrix{i, j})
                data = data_matrix{i, j};
                
                % Check if data is valid (not all NaN, not empty)
                if ~isempty(data) && ~all(isnan(data)) && length(data) > 0
                    % Create histogram
                    mean_val = mean(data, 'omitnan');
                    pct_deviations = 100 * (data - mean_val) ./ mean_val;

                    histogram(pct_deviations, 'Normalization', 'probability', ...
                             'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.6, ...
                             'EdgeColor', 'none');
                    
                    yl = ylim;
                    plot([0 0], yl, 'r:', 'LineWidth', 1); % Zero line
                end
            end
            
            % Style
            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 9;
            ax.TickDir = 'out';
            
            % Labels
            xlabel(strcat(simple_metric, " % deviation"), 'FontSize', 10);
            if j == 1
                ylabel('Probability', 'FontSize', 10);
            end
            
            % Add row label on left side for first column
            if j == 1
                text(-0.3, 0.5, inv_i_label, 'Units', 'normalized', ...
                     'Rotation', 90, 'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            % Add column label on top for first row
            if i == 1
                text(0.5, 1.15, inv_j_label, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            hold off;

            % ===== PLOT 3: Relative to combined investment =====
            figure(fig_relative);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            if i == j
                % Diagonal: plot standalone distribution
                if ~isempty(data_matrix{i, j})
                    data = data_matrix{i, j};
                    
                    if ~isempty(data) && ~all(isnan(data)) && length(data) > 0
                        % Create histogram
                        histogram(data, 'Normalization', 'probability', ...
                                 'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.6, ...
                                 'EdgeColor', 'none');
                        
                        mean_val = mean(data, 'omitnan');
                        
                        % Add mean line
                        yl = ylim;
                        if ~isnan(mean_val)
                            plot([mean_val mean_val], yl, 'k--', 'LineWidth', 1.5);
                        end
                    end
                end
            else
                % Off-diagonal: plot percent change relative to combined investment
                % Get complementarity data for this cell
                if ~isempty(data_matrix{i, j})
                    complementarity = data_matrix{i, j};
                    
                    % Get standalone data for both investments
                    standalone_i = data_matrix{i, i};
                    standalone_j = data_matrix{j, j};
                    
                    if ~isempty(complementarity) && ~isempty(standalone_i) && ~isempty(standalone_j) && ...
                       ~all(isnan(complementarity)) && ~all(isnan(standalone_i)) && ~all(isnan(standalone_j))
                        
                        % Ensure same length
                        min_len = min([length(complementarity), length(standalone_i), length(standalone_j)]);
                        complementarity = complementarity(1:min_len);
                        standalone_i = standalone_i(1:min_len);
                        standalone_j = standalone_j(1:min_len);
                        
                        % Combined = Sum of standalones + Complementarity
                        combined = standalone_i + standalone_j;
                        
                        % Percent change: (Combined - Sum of standalones) / Combined * 100
                        pct_change = 100 * complementarity ./ (combined + eps);
                        
                        % Create histogram
                        histogram(pct_change, 'Normalization', 'probability', ...
                                 'FaceColor', [0.5 0.7 0.3], 'FaceAlpha', 0.6, ...
                                 'EdgeColor', 'none');
                        
                        % Add mean line
                        mean_val = mean(pct_change, 'omitnan');
                        yl = ylim;
                        if ~isnan(mean_val)
                            plot([mean_val mean_val], yl, 'k--', 'LineWidth', 1.5);
                        end
                        plot([0 0], yl, 'r:', 'LineWidth', 1); % Zero line
                    end
                end
            end
            
            % Style
            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 9;
            ax.TickDir = 'out';
            
            % Labels
            if i == j
                xlabel(simple_metric, 'FontSize', 10);
            else
                xlabel('% change vs combined', 'FontSize', 10);
            end
            if j == 1
                ylabel('Probability', 'FontSize', 10);
            end
            
            % Add row label on left side for first column
            if j == 1
                text(-0.3, 0.5, inv_i_label, 'Units', 'normalized', ...
                     'Rotation', 90, 'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            % Add column label on top for first row
            if i == 1
                text(0.5, 1.15, inv_j_label, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            hold off;
        end
    end
    
    % Add overall titles
    metric_short = strrep(metric_label, ' complementarity', '');
    accent_short = strrep(accent_label, ' scenarios', '');
    
    figure(fig_raw);
    sgtitle({sprintf('\\fontsize{14}\\bf Raw %s complementarity', lower(metric_short)), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    figure(fig_raw_pct);
    sgtitle({sprintf('\\fontsize{14}\\bf Raw %s %% deviations from mean', lower(metric_short)), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    figure(fig_relative);
    sgtitle({sprintf('\\fontsize{14}\\bf %s: Standalone (diagonal) and %% change vs combined (off-diagonal)', metric_short), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    % Adjust subplot positions for all figures
    for fig = [fig_raw, fig_raw_pct, fig_relative]
        figure(fig);
        for i = 1:n_investments
            for j = 1:n_investments
                subplot_idx = (i - 1) * n_investments + j;
                subplot(n_investments, n_investments, subplot_idx);
                pos = get(gca, 'Position');
                pos(4) = pos(4) * 0.94;
                pos(2) = pos(2) - pos(4) * 0.06;
                set(gca, 'Position', pos);
            end
        end
    end

    % Save figures as vector PDFs
    filename_base = sprintf('complementarity_%s_%s', ...
        lower(strrep(metric_short, ' ', '_')), ...
        lower(accent_short));
    
    export_figure(fig_raw, fullfile(figure_path, [filename_base '_raw.pdf']));
    export_figure(fig_raw_pct, fullfile(figure_path, [filename_base '_raw_pct_deviation_from_mean.pdf']));
    export_figure(fig_relative, fullfile(figure_path, [filename_base '_relative_to_combined.pdf']));
    close(fig_raw);
    close(fig_raw_pct);
    close(fig_relative);
    
    fprintf('Saved raw complementarity figures for %s %s\n', metric_label, accent_label);
end

