function get_complementarity_distributions(job_dir)
    % GET_COMPLEMENTARITY_DISTRIBUTIONS
    % Generates distribution plots for complementarities between preparedness investments
    % Complementarity = Combined program - Sum of standalone programs
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results
    
    % Set up paths
    rawdata_dir = fullfile(job_dir, "raw");
    figure_path = fullfile(job_dir, "figures");
    if ~exist(figure_path, 'dir')
        mkdir(figure_path);
    end
    
    % Load job config and get all scenarios
    job_config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    all_scenarios = string(fieldnames(job_config.scenarios));
    all_scenarios = all_scenarios(~strcmp(all_scenarios, "baseline"));
    
    % Filter out prevac0 and prec1 scenarios
    all_scenarios = all_scenarios(~contains(all_scenarios, "prevac0"));
    all_scenarios = all_scenarios(~contains(all_scenarios, "prec1"));
    
    % Parse scenarios to identify interventions and accents
    [scenario_info, investment_types] = parse_all_scenarios(all_scenarios, job_config);
    
    % Number of bootstrap samples
    n_bootstrap = 1000;
    
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
                rawdata_dir, ...
                metric, ...
                investment_types);
            
            % Create figures: raw distributions and bootstrap means
            create_complementarity_figures(complementarity_data, ...
                metric_label, accent_label, ...
                figure_path, n_bootstrap, ...
                job_config.num_simulations);
        end
    end
end

function [scenario_info, investment_types] = parse_all_scenarios(scenarios, job_config)
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
        
        % Extract precision/recall for early warning if present
        if scenario_info.early_warning(i)
            try
                scen_params = job_config.scenarios.(scen_name);
                if isfield(scen_params, 'improved_early_warning')
                    scenario_info.precision(i) = scen_params.improved_early_warning.precision;
                    scenario_info.recall(i) = scen_params.improved_early_warning.recall;
                end
            catch
                % If precision/recall not available, set to NaN
                if ~ismember('precision', scenario_info.Properties.VariableNames)
                    scenario_info.precision = nan(n_scen, 1);
                    scenario_info.recall = nan(n_scen, 1);
                end
                scenario_info.precision(i) = NaN;
                scenario_info.recall(i) = NaN;
            end
        end
    end
    
    % Add precision/recall columns if they don't exist
    if ~ismember('precision', scenario_info.Properties.VariableNames)
        scenario_info.precision = nan(n_scen, 1);
        scenario_info.recall = nan(n_scen, 1);
    end
end

function complementarity_data = calculate_complementarities(scenario_info, rawdata_dir, metric, investment_types)
    % Calculate complementarities for all investment combinations
    
    investments = {'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'};
    complementarity_data = struct();
    
    % Load data for all scenarios
    scenario_data = containers.Map();
    for i = 1:height(scenario_info)
        scen_name = scenario_info.scenario(i);
        sum_table_file = fullfile(rawdata_dir, sprintf("%s_relative_sums.mat", scen_name));
        if exist(sum_table_file, 'file')
            load(sum_table_file, 'scenario_sum_table');
            col_name = strcat(metric, '_full');
            if ismember(col_name, scenario_sum_table.Properties.VariableNames)
                scenario_data(scen_name) = scenario_sum_table.(col_name);
            end
        end
    end
    
    % For each investment type, find complementarities
    for inv_idx = 1:length(investments)
        inv_name = investments{inv_idx};
        inv_label = investment_types(inv_name);
        
        % Find all combinations involving this investment
        % We want: alone, and combinations with each other investment
        
        complementarity_data.(inv_name) = struct();
        complementarity_data.(inv_name).label = inv_label;
        complementarity_data.(inv_name).configs = {};
        complementarity_data.(inv_name).data = {};
        complementarity_data.(inv_name).config_labels = {};
        
        % Count number of interventions for each scenario
        num_interventions = sum([scenario_info.early_warning, ...
                                scenario_info.advance_capacity, ...
                                scenario_info.neglected_pathogen, ...
                                scenario_info.universal_flu], 2);
        
        % Configuration 1: Investment alone (show standalone value, not complementarity)
        % For early warning, we might have multiple "alone" scenarios with different precision/recall
        % For now, just take the first one found
        alone_mask = scenario_info.(inv_name) & (num_interventions == 1);
        alone_indices = find(alone_mask);
        
        if ~isempty(alone_indices)
            % Use first alone scenario found
            alone_idx = alone_indices(1);
            alone_scen = scenario_info.scenario(alone_idx);
            if scenario_data.isKey(alone_scen)
                % Store standalone value (not complementarity, which would be 0)
                complementarity_data.(inv_name).configs{end+1} = 'alone';
                complementarity_data.(inv_name).data{end+1} = scenario_data(alone_scen);
                complementarity_data.(inv_name).config_labels{end+1} = 'Alone (standalone)';
            end
        end
        
        % Configuration 2-N: Combined with each other investment
        for other_idx = 1:length(investments)
            if other_idx == inv_idx
                continue;
            end
            other_name = investments{other_idx};
            other_label = investment_types(other_name);
            
            % Find combined scenario (exactly 2 interventions)
            combined_mask = scenario_info.(inv_name) & ...
                           scenario_info.(other_name) & ...
                           (num_interventions == 2);
            
            combined_idx = find(combined_mask, 1);
            if ~isempty(combined_idx)
                combined_scen = scenario_info.scenario(combined_idx);
                
                    % Find standalone scenarios
                alone_inv_mask = scenario_info.(inv_name) & (num_interventions == 1);
                alone_other_mask = scenario_info.(other_name) & (num_interventions == 1);
                alone_inv_idx = find(alone_inv_mask, 1);
                alone_other_idx = find(alone_other_mask, 1);
                
                if ~isempty(alone_inv_idx) && ~isempty(alone_other_idx)
                    alone_inv_scen = scenario_info.scenario(alone_inv_idx);
                    alone_other_scen = scenario_info.scenario(alone_other_idx);
                    
                    if scenario_data.isKey(combined_scen) && ...
                       scenario_data.isKey(alone_inv_scen) && ...
                       scenario_data.isKey(alone_other_scen)
                        
                        % Calculate complementarity: Combined - (Alone1 + Alone2)
                        combined_data = scenario_data(combined_scen);
                        alone_inv_data = scenario_data(alone_inv_scen);
                        alone_other_data = scenario_data(alone_other_scen);
                        
                        % Ensure same length
                        min_len = min([length(combined_data), length(alone_inv_data), length(alone_other_data)]);
                        complementarity = combined_data(1:min_len) - ...
                                         (alone_inv_data(1:min_len) + alone_other_data(1:min_len));
                        
                        config_label = sprintf('With %s', other_label);
                        complementarity_data.(inv_name).configs{end+1} = sprintf('with_%s', other_name);
                        complementarity_data.(inv_name).data{end+1} = complementarity;
                        complementarity_data.(inv_name).config_labels{end+1} = config_label;
                    end
                end
            end
        end
    end
end

function create_complementarity_figures(complementarity_data, metric_label, accent_label, figure_path, n_bootstrap, sample_size)
    % Create distribution figures for complementarities
    % Reorganized as a matrix: rows and columns both represent investments
    
    investments = {'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'};
    investment_types = containers.Map({'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'}, ...
        {'Early warning', 'Advance capacity', 'Neglected pathogen R&D', 'Universal flu vaccine'});
    
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
    
    % Generate bootstrap sample indices once, to be reused across all scenarios
    rng(42); % Set seed for reproducibility
    bootstrap_indices = randi(sample_size, sample_size, n_bootstrap);
    
    % Create two figures: raw distributions and bootstrap means
    % Use tighter spacing
    fig_raw = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    fig_boot = figure('Visible', 'off', 'Position', [100 100 350*n_investments 300*n_investments]);
    
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
                    histogram(data, 'Normalization', 'probability', ...
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
            
            % ===== PLOT 2: Bootstrap mean distribution =====
            figure(fig_boot);
            subplot(n_investments, n_investments, subplot_idx);
            hold on;
            
            % Get data for this cell
            if ~isempty(data_matrix{i, j})
                data = data_matrix{i, j};
                
                % Check if data is valid
                if ~isempty(data) && ~all(isnan(data)) && length(data) > 0
                    % Bootstrap distribution of means using pre-generated indices
                    bootstat = zeros(n_bootstrap, 1);
                    for b = 1:n_bootstrap
                        bootstat(b) = mean(data(bootstrap_indices(:, b)), 'omitnan');
                    end
                    mean_val = mean(data, 'omitnan');
                    
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
        end
    end
    
    % Add overall titles
    metric_short = strrep(metric_label, ' complementarity', '');
    accent_short = strrep(accent_label, ' scenarios', '');
    
    % Create title for raw distribution figure
    figure(fig_raw);
    sgtitle({sprintf('\\fontsize{16}\\bf Raw %s complementarity', lower(metric_short)), ...
             sprintf('\\fontsize{14}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    % Adjust subplot positions to add space below title
    for i = 1:n_investments
        for j = 1:n_investments
            subplot_idx = (i - 1) * n_investments + j;
            subplot(n_investments, n_investments, subplot_idx);
            pos = get(gca, 'Position');
            % Reduce height and shift down to create space for title
            pos(4) = pos(4) * 0.92; % Reduce height by 8%
            pos(2) = pos(2) - pos(4) * 0.08; % Shift down
            set(gca, 'Position', pos);
        end
    end
    
    % Create title for bootstrap figure
    figure(fig_boot);
    sgtitle({sprintf('\\fontsize{14}\\bf Bootstrapped mean complementarity in %s', lower(metric_short)), ...
             sprintf('\\fontsize{12}Accent: %s', accent_short)}, ...
            'FontWeight', 'normal', 'Interpreter', 'tex');
    
    % Adjust subplot positions to add space below title
    for i = 1:n_investments
        for j = 1:n_investments
            subplot_idx = (i - 1) * n_investments + j;
            subplot(n_investments, n_investments, subplot_idx);
            pos = get(gca, 'Position');
            % Reduce height and shift down to create space for title
            pos(4) = pos(4) * 0.92; % Reduce height by 8%
            pos(2) = pos(2) - pos(4) * 0.08; % Shift down
            set(gca, 'Position', pos);
        end
    end
    
    % Save figures
    filename_base = sprintf('complementarity_%s_%s', ...
        lower(strrep(metric_short, ' ', '_')), ...
        lower(accent_short));
    
    saveas(fig_raw, fullfile(figure_path, [filename_base '_raw.jpg']));
    saveas(fig_boot, fullfile(figure_path, [filename_base '_bootstrap.jpg']));
    close(fig_raw);
    close(fig_boot);
    
    fprintf('Saved complementarity figures for %s %s\n', metric_label, accent_label);
end
