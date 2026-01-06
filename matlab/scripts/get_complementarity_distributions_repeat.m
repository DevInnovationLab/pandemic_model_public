function get_complementarity_distributions_repeat(output_dir)
    % GET_COMPLEMENTARITY_DISTRIBUTIONS_REPEAT
    % Generates distribution plots for complementarities between preparedness investments
    % using aggregated results from repeat job batches
    % Complementarity = Combined program - Sum of standalone programs
    %
    % Args:
    %   output_dir (string): Directory containing aggregated results from assemble_repeat_job_results
    
    % Set up paths
    processed_dir = fullfile(output_dir, "processed");
    figure_path = fullfile(output_dir, "figures");
    if ~exist(figure_path, 'dir')
        mkdir(figure_path);
    end
    
    % Load job config from first seed directory to get scenario definitions
    subdir_tab = struct2table(dir(output_dir));
    subdir_tab = subdir_tab(contains(subdir_tab.name, "seed_"), :);
    first_seed_dir = fullfile(subdir_tab.folder(1), subdir_tab.name(1));
    job_config = yaml.loadFile(fullfile(first_seed_dir, "job_config.yaml"));
    
    % Get all scenarios
    all_scenarios = string(fieldnames(job_config.scenarios));
    all_scenarios = all_scenarios(~strcmp(all_scenarios, "baseline"));
    
    % Filter out prevac0 and prec1 scenarios
    all_scenarios = all_scenarios(~contains(all_scenarios, "prevac0"));
    all_scenarios = all_scenarios(~contains(all_scenarios, "prec1"));
    
    % Parse scenarios to identify interventions and accents
    [scenario_info, investment_types] = parse_all_scenarios(all_scenarios);
    
    % Number of bootstrap samples (use pre-computed bootstraps)
    n_bootstrap = 200;
    
    % Metrics to plot
    metrics = {'benefits_vaccine', 'total_costs_pv'};
    metric_labels = {'Benefits complementarity', 'Costs complementarity'};
    
    % Accent types
    accents = {'bcr', 'surplus'};
    accent_labels = {'BCR scenarios', 'Surplus scenarios'};
    
    % For each metric and accent, create figures
    for m = 1:length(metrics)
        metric = metrics{m};
        metric_label = metric_labels{m};
        
        for a = 1:length(accents)
            accent = accents{a};
            accent_label = accent_labels{a};
            
            % Filter scenarios by accent
            accent_mask = strcmp(scenario_info.accent, accent);
            if sum(accent_mask) == 0
                continue; % Skip if no scenarios for this accent
            end
            
            % Create complementarity data structure
            complementarity_data = calculate_complementarities(...
                scenario_info(accent_mask, :), ...
                processed_dir, ...
                metric, ...
                investment_types);
            
            % Create figures: raw distributions and bootstrap means
            create_complementarity_figures(complementarity_data, ...
                metric_label, accent_label, ...
                figure_path, n_bootstrap);
        end
    end
end


function [scenario_info, investment_types] = parse_all_scenarios(scenarios)
    % Parse all scenarios to extract intervention flags and accents
    
    investments = {'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'};
    investment_types = containers.Map({'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'}, ...
        {'Early warning', 'Advance capacity', 'Neglected pathogen R&D', 'Universal flu vaccine'});
    
    % Initialize table
    n_scen = length(scenarios);
    scenario_info = table('Size', [n_scen, 6], ...
        'VariableTypes', {'string', 'string', 'logical', 'logical', 'logical', 'logical'}, ...
        'VariableNames', {'scenario', 'accent', 'early_warning', 'advance_capacity', ...
        'neglected_pathogen', 'universal_flu'});
    
    for i = 1:n_scen
        scen_name = scenarios(i);
        scenario_info.scenario(i) = scen_name;
        
        % Extract accent (bcr or surplus)
        accent_match = regexp(scen_name, '(bcr|surplus)', 'match', 'once');
        if isempty(accent_match)
            accent_match = 'bcr'; % Default
        end
        scenario_info.accent(i) = accent_match;
        
        % Extract intervention flags
        for j = 1:length(investments)
            scenario_info.(investments{j})(i) = contains(scen_name, investments{j});
        end
    end
end

function complementarity_data = calculate_complementarities(scenario_info, processed_dir, metric, investment_types)
    % Calculate complementarities for all investment combinations using aggregated data
    
    investments = {'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'};
    complementarity_data = struct();
    
    % Load data for all scenarios
    scenario_data = containers.Map();
    scenario_bootstrap_data = containers.Map();
    
    for i = 1:height(scenario_info)
        scen_name = scenario_info.scenario(i);
        
        % Load raw aggregated results
        rel_sums_file = fullfile(processed_dir, sprintf("%s_rel_sums.mat", scen_name));
        if exist(rel_sums_file, 'file')
            load(rel_sums_file, 'results');
            col_name = strcat(metric, '_full');
            if ismember(col_name, results.Properties.VariableNames)
                scenario_data(scen_name) = results.(col_name);
            end
        end
        
        % Load bootstrap results
        bootstrap_file = fullfile(processed_dir, sprintf("%s_rel_sums_bootstraps.mat", scen_name));
        if exist(bootstrap_file, 'file')
            load(bootstrap_file, 'bootstrap_table');
            col_name = strcat(metric, '_full');
            if ismember(col_name, bootstrap_table.Properties.VariableNames)
                scenario_bootstrap_data(scen_name) = bootstrap_table.(col_name);
            end
        end
    end
    
    % Count number of interventions for each scenario
    num_interventions = sum([scenario_info.early_warning, ...
                            scenario_info.advance_capacity, ...
                            scenario_info.neglected_pathogen, ...
                            scenario_info.universal_flu], 2);
    
    % Build complementarity matrix
    n_inv = length(investments);
    complementarity_data.investments = investments;
    complementarity_data.investment_types = investment_types;
    complementarity_data.data_matrix = cell(n_inv, n_inv);
    complementarity_data.bootstrap_matrix = cell(n_inv, n_inv);
    
    for i = 1:n_inv
        inv_i = investments{i};
        
        for j = 1:n_inv
            inv_j = investments{j};
            
            if i == j
                % Diagonal: standalone investment
                alone_mask = scenario_info.(inv_i) & (num_interventions == 1);
                alone_idx = find(alone_mask, 1);
                
                if ~isempty(alone_idx)
                    alone_scen = scenario_info.scenario(alone_idx);
                    if scenario_data.isKey(alone_scen)
                        complementarity_data.data_matrix{i, j} = scenario_data(alone_scen);
                    end
                    if scenario_bootstrap_data.isKey(alone_scen)
                        complementarity_data.bootstrap_matrix{i, j} = scenario_bootstrap_data(alone_scen);
                    end
                end
            else
                % Off-diagonal: complementarity between two investments
                % Find combined scenario
                combined_mask = scenario_info.(inv_i) & ...
                               scenario_info.(inv_j) & ...
                               (num_interventions == 2);
                combined_idx = find(combined_mask, 1);
                
                if ~isempty(combined_idx)
                    combined_scen = scenario_info.scenario(combined_idx);
                    
                    % Find standalone scenarios
                    alone_i_mask = scenario_info.(inv_i) & (num_interventions == 1);
                    alone_j_mask = scenario_info.(inv_j) & (num_interventions == 1);
                    alone_i_idx = find(alone_i_mask, 1);
                    alone_j_idx = find(alone_j_mask, 1);
                    
                    if ~isempty(alone_i_idx) && ~isempty(alone_j_idx)
                        alone_i_scen = scenario_info.scenario(alone_i_idx);
                        alone_j_scen = scenario_info.scenario(alone_j_idx);
                        
                        % Calculate complementarity: combined - (alone_i + alone_j)
                        if scenario_data.isKey(combined_scen) && ...
                           scenario_data.isKey(alone_i_scen) && ...
                           scenario_data.isKey(alone_j_scen)
                            
                            combined_data = scenario_data(combined_scen);
                            alone_i_data = scenario_data(alone_i_scen);
                            alone_j_data = scenario_data(alone_j_scen);
                            
                            complementarity_data.data_matrix{i, j} = ...
                                combined_data - (alone_i_data + alone_j_data);
                        end
                        
                        % Calculate bootstrap complementarity
                        if scenario_bootstrap_data.isKey(combined_scen) && ...
                           scenario_bootstrap_data.isKey(alone_i_scen) && ...
                           scenario_bootstrap_data.isKey(alone_j_scen)
                            
                            combined_boot = scenario_bootstrap_data(combined_scen);
                            alone_i_boot = scenario_bootstrap_data(alone_i_scen);
                            alone_j_boot = scenario_bootstrap_data(alone_j_scen);
                            
                            complementarity_data.bootstrap_matrix{i, j} = ...
                                combined_boot - (alone_i_boot + alone_j_boot);
                        end
                    end
                end
            end
        end
    end
end

function create_complementarity_figures(complementarity_data, metric_label, accent_label, figure_path, n_bootstrap)
    % Create complementarity distribution figures
    
    investments = complementarity_data.investments;
    investment_types = complementarity_data.investment_types;
    data_matrix = complementarity_data.data_matrix;
    bootstrap_matrix = complementarity_data.bootstrap_matrix;
    n_investments = length(investments);
    
    % Create five figures
    fig_raw = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    fig_raw_pct = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    fig_boot = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    fig_boot_pct = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    fig_relative = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    
    % Extract simple metric name
    simple_metric = strrep(metric_label, ' complementarity', '');
    
    % Plot matrix
    for i = 1:n_investments
        inv_i = investments{i};
        inv_i_label = investment_types(inv_i);
        
        for j = 1:n_investments
            inv_j = investments{j};
            inv_j_label = investment_types(inv_j);
            
            subplot_idx = (i - 1) * n_investments + j;
            
            % ===== PLOT 1: Raw data distribution =====
            figure(fig_raw);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            if ~isempty(data_matrix{i, j})
                data = data_matrix{i, j};
                
                if ~isempty(data) && ~all(isnan(data))
                    histogram(data, 'Normalization', 'probability', ...
                             'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.6, ...
                             'EdgeColor', 'none');
                    
                    mean_val = mean(data, 'omitnan');
                    yl = ylim;
                    if ~isnan(mean_val)
                        plot([mean_val mean_val], yl, 'k--', 'LineWidth', 1.5);
                    end
                    if i ~= j
                        plot([0 0], yl, 'r:', 'LineWidth', 1);
                    end
                end
            end
            
            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 9;
            ax.TickDir = 'out';
            
            xlabel(simple_metric, 'FontSize', 10);
            if j == 1
                ylabel('Probability', 'FontSize', 10);
            end
            
            if j == 1
                text(-0.3, 0.5, inv_i_label, 'Units', 'normalized', ...
                     'Rotation', 90, 'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            if i == 1
                text(0.5, 1.15, inv_j_label, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            hold off;
            
            % ===== PLOT 2: Raw data % deviation from mean =====
            figure(fig_raw_pct);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            if ~isempty(data_matrix{i, j})
                data = data_matrix{i, j};
                
                if ~isempty(data) && ~all(isnan(data))
                    mean_val = mean(data, 'omitnan');
                    pct_deviations = 100 * (data - mean_val) ./ mean_val;
                    
                    histogram(pct_deviations, 'Normalization', 'probability', ...
                             'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.6, ...
                             'EdgeColor', 'none');
                    
                    yl = ylim;
                    plot([0 0], yl, 'r:', 'LineWidth', 1);
                end
            end
            
            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 9;
            ax.TickDir = 'out';
            
            xlabel(strcat(simple_metric, " % deviation"), 'FontSize', 10);
            if j == 1
                ylabel('Probability', 'FontSize', 10);
            end
            
            if j == 1
                text(-0.3, 0.5, inv_i_label, 'Units', 'normalized', ...
                     'Rotation', 90, 'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            if i == 1
                text(0.5, 1.15, inv_j_label, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            hold off;
            
            % ===== PLOT 3: Bootstrap means =====
            figure(fig_boot);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            if ~isempty(bootstrap_matrix{i, j})
                bootstat = bootstrap_matrix{i, j};
                
                if ~isempty(bootstat) && ~all(isnan(bootstat))
                    histogram(bootstat, 'Normalization', 'probability', ...
                             'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.6, ...
                             'EdgeColor', 'none');
                    
                    yl = ylim;
                    if i ~= j
                        plot([0 0], yl, 'r:', 'LineWidth', 1);
                    end
                end
            end
            
            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 9;
            ax.TickDir = 'out';
            
            xlabel(simple_metric, 'FontSize', 10);
            if j == 1
                ylabel('Probability', 'FontSize', 10);
            end
            
            if j == 1
                text(-0.3, 0.5, inv_i_label, 'Units', 'normalized', ...
                     'Rotation', 90, 'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            if i == 1
                text(0.5, 1.15, inv_j_label, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            hold off;
            
            % ===== PLOT 4: Bootstrap % deviation from mean =====
            figure(fig_boot_pct);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            if ~isempty(data_matrix{i, j})
                data = data_matrix{i, j};
                
                if ~isempty(data) && ~all(isnan(data)) && ~isempty(bootstrap_matrix{i, j})
                    mean_val = mean(data, 'omitnan');
                    bootstat = bootstrap_matrix{i, j};
                    bootstat_pct = 100 * (bootstat - mean_val) ./ mean_val;
                    
                    histogram(bootstat_pct, 'Normalization', 'probability', ...
                             'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.6, ...
                             'EdgeColor', 'none');
                    
                    yl = ylim;
                    plot([0 0], yl, 'r:', 'LineWidth', 1);
                end
            end
            
            box off;
            ax = gca;
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.15;
            ax.LineWidth = 1;
            ax.FontSize = 9;
            ax.TickDir = 'out';
            
            xlabel(strcat(simple_metric, " % deviation"), 'FontSize', 10);
            if j == 1
                ylabel('Probability', 'FontSize', 10);
            end
            
            if j == 1
                text(-0.3, 0.5, inv_i_label, 'Units', 'normalized', ...
                     'Rotation', 90, 'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            if i == 1
                text(0.5, 1.15, inv_j_label, 'Units', 'normalized', ...
                     'HorizontalAlignment', 'center', ...
                     'FontSize', 10, 'FontWeight', 'bold');
            end
            
            hold off;
            
            % ===== PLOT 5: Relative to combined investment =====
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
    
    % Add titles and adjust spacing
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
    
    figure(fig_boot);
    sgtitle({sprintf('\\fontsize{14}\\bf Bootstrapped mean complementarity in %s', lower(metric_short)), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    figure(fig_boot_pct);
    sgtitle({sprintf('\\fontsize{14}\\bf Bootstrapped %s mean %% deviation from mean', lower(metric_short)), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    figure(fig_relative);
    sgtitle({sprintf('\\fontsize{14}\\bf %s: Standalone (diagonal) and %% change vs combined (off-diagonal)', metric_short), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    % Adjust subplot positions for all figures
    for fig = [fig_raw, fig_raw_pct, fig_boot, fig_boot_pct, fig_relative]
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
    
    saveas(fig_raw, fullfile(figure_path, [filename_base '_raw.jpg']));
    saveas(fig_raw_pct, fullfile(figure_path, [filename_base, '_raw_pct_deviation_from_mean.jpg']));
    saveas(fig_boot, fullfile(figure_path, [filename_base '_bootstrap.jpg']));
    saveas(fig_boot_pct, fullfile(figure_path, [filename_base '_bootstrap_pct_deviation_from_mean.jpg']));
    saveas(fig_relative, fullfile(figure_path, [filename_base '_relative_to_combined.jpg']));
    
    close(fig_raw);
    close(fig_raw_pct);
    close(fig_boot);
    close(fig_boot_pct);
    close(fig_relative);
    
    fprintf('Saved complementarity figures for %s %s\n', metric_label, accent_label);
end
