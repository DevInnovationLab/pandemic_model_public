function plot_complementarity_bootstrap(complementarity_data, metric_label, accent_label, figure_path, sample_size)
    % PLOT_COMPLEMENTARITY_BOOTSTRAP
    % Creates bootstrap distribution plots for complementarities between preparedness investments
    % Reorganized as a matrix: rows and columns both represent investments
    %
    % Args:
    %   complementarity_data: Struct containing complementarity data
    %   metric_label: Label for the metric being plotted
    %   accent_label: Label for the accent (BCR or Surplus)
    %   figure_path: Path to save figures
    %   sample_size: Number of simulations (for reference)
    
    investments = {'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'};
    investment_types = containers.Map({'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'}, ...
        {'Early warning', 'Advance capacity', 'Neglected pathogen R&D', 'Universal flu vaccine'});
    
    % Count valid investment types (those with data)
    valid_investments = {};
    for i = 1:length(investments)
        inv = investments{i};
        if isfield(complementarity_data, inv) && ...
           isfield(complementarity_data.(inv), 'bootstrap_data') && ...
           ~isempty(complementarity_data.(inv).bootstrap_data)
            % Check if any bootstrap data exists
            has_bootstrap = false;
            for k = 1:length(complementarity_data.(inv).bootstrap_data)
                if ~isempty(complementarity_data.(inv).bootstrap_data{k})
                    has_bootstrap = true;
                    break;
                end
            end
            if has_bootstrap
                valid_investments{end+1} = inv;
            end
        end
    end
    
    if isempty(valid_investments)
        fprintf('No valid bootstrap complementarity data found for %s %s\n', metric_label, accent_label);
        return;
    end
    
    % Reorganize data into matrix format: bootstrap_matrix{i,j} contains complementarity between i and j
    n_investments = length(investments);
    bootstrap_matrix = cell(n_investments, n_investments);
    
    for i = 1:n_investments
        inv_i = investments{i};
        if ~isfield(complementarity_data, inv_i)
            continue;
        end
        
        % Get standalone data (diagonal)
        configs = complementarity_data.(inv_i).configs;
        bootstrap_list = complementarity_data.(inv_i).bootstrap_data;
        
        % Find standalone
        alone_idx = find(strcmp(configs, 'alone'), 1);
        if ~isempty(alone_idx) && ~isempty(bootstrap_list{alone_idx})
            bootstrap_matrix{i, i} = bootstrap_list{alone_idx};
        end
        
        % Find combinations with other investments
        for j = 1:n_investments
            if i == j
                continue; % Already handled diagonal
            end
            inv_j = investments{j};
            with_j_pattern = ['with_' inv_j];
            with_j_idx = find(cellfun(@(x) contains(x, with_j_pattern), configs), 1);
            if ~isempty(with_j_idx) && ~isempty(bootstrap_list{with_j_idx})
                bootstrap_matrix{i, j} = bootstrap_list{with_j_idx};
                % Complementarity is symmetric, so also store in reverse direction
                % But only if that cell is empty (don't overwrite if already set)
                if isempty(bootstrap_matrix{j, i})
                    bootstrap_matrix{j, i} = bootstrap_list{with_j_idx};
                end
            end
        end
    end
    
    % Create figures: bootstrap means
    fig_boot = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    fig_boot_pct = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    
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
            
            % ===== PLOT 1: Bootstrap mean distribution =====
            figure(fig_boot);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            % Get bootstrap data for this cell
            if ~isempty(bootstrap_matrix{i, j})
                bootstat = bootstrap_matrix{i, j};
                
                % Check if data is valid
                if ~isempty(bootstat) && ~all(isnan(bootstat)) && length(bootstat) > 0
                    mean_val = mean(bootstat, 'omitnan');
                    
                    % Create histogram
                    histogram(bootstat, 'Normalization', 'probability', ...
                             'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.6, ...
                             'EdgeColor', 'none');
                    
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

            % ===== PLOT 2: Bootstrap mean distribution (% deviation from mean) =====
            figure(fig_boot_pct);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            % Get bootstrap data for this cell
            if ~isempty(bootstrap_matrix{i, j})
                bootstat = bootstrap_matrix{i, j};
                
                % Check if data is valid
                if ~isempty(bootstat) && ~all(isnan(bootstat)) && length(bootstat) > 0
                    mean_val = mean(bootstat, 'omitnan');
                    pct_deviations = 100 * (bootstat - mean_val) ./ mean_val;
                    
                    % Create histogram
                    histogram(pct_deviations, 'Normalization', 'probability', ...
                             'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.6, ...
                             'EdgeColor', 'none');
                    
                    % Add mean line
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
        end
    end
    
    % Add overall titles
    metric_short = strrep(metric_label, ' complementarity', '');
    accent_short = strrep(accent_label, ' scenarios', '');
    
    figure(fig_boot);
    sgtitle({sprintf('\\fontsize{14}\\bf Bootstrapped mean complementarity in %s', lower(metric_short)), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    figure(fig_boot_pct);
    sgtitle({sprintf('\\fontsize{14}\\bf Bootstrapped %s mean %% deviation from mean', lower(metric_short)), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    % Adjust subplot positions for all figures
    for fig = [fig_boot, fig_boot_pct]
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

    % Save figures
    filename_base = sprintf('complementarity_%s_%s', ...
        lower(strrep(metric_short, ' ', '_')), ...
        lower(accent_short));
    
    print(fig_boot, fullfile(figure_path, [filename_base '_bootstrap']), '-djpeg', '-r600');
    print(fig_boot_pct, fullfile(figure_path, [filename_base '_bootstrap_pct_deviation_from_mean']), '-djpeg', '-r600');
    close(fig_boot);
    close(fig_boot_pct);
    
    fprintf('Saved bootstrap complementarity figures for %s %s\n', metric_label, accent_label);
end




