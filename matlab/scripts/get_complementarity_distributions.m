function get_complementarity_distributions(job_dir, raw_only)
    % GET_COMPLEMENTARITY_DISTRIBUTIONS
    % Generates distribution plots for complementarities between preparedness investments
    % Complementarity = Combined program - Sum of standalone programs
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results
    
    % Set up paths
    processed_dir = fullfile(job_dir, "processed");
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
    
    % Metrics to plot
    metrics = {'tot_benefits_pv'};
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
                investment_types, ...
                raw_only);

            % Save complementarity data
            complementarity_filename = sprintf('complementarity_%s_%s.mat', metric, accent);
            complementarity_filepath = fullfile(processed_dir, complementarity_filename);
            save(complementarity_filepath, 'complementarity_data');
            fprintf('Saved complementarity data to %s\n', complementarity_filepath);
            
            % Create figures: raw distributions and bootstrap means
            plot_complementarity_raw(complementarity_data, ...
                metric_label, accent_label, ...
                figure_path, ...
                job_config.num_simulations);

            if ~raw_only
                plot_complementarity_bootstrap(complementarity_data, ...
                    metric_label, accent_label, ...
                    figure_path, ...
                    job_config.num_simulations);
            end
        end
    end
end

function [scenario_info, investment_types] = parse_all_scenarios(scenarios, job_config)
    % Parse all scenarios to extract intervention flags and accents
    
    investments = {'advance_capacity', 'neglected_pathogen', 'universal_flu', 'early_warning'};
    investment_types = containers.Map({'early_warning', 'advance_capacity', 'neglected_pathogen', 'universal_flu'}, ...
        {'Improved early warning', 'Advance capacity', 'Prototype vaccine R&D', 'Universal flu vaccine'});
    
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

function complementarity_data = calculate_complementarities(scenario_info, processed_dir, metric, investment_types, raw_only)
    % Calculate complementarities for all investment combinations
    % Loads data from aggregated relative sums
    
    investments = {'advance_capacity', 'neglected_pathogen', 'universal_flu', 'early_warning'};
    complementarity_data = struct();
    
    % Load data for all scenarios from aggregated files
    scenario_data = containers.Map();
    scenario_bootstrap_data = containers.Map();
    
    for i = 1:height(scenario_info)
        scen_name = scenario_info.scenario(i);
        rel_sums_file = fullfile(processed_dir, sprintf('%s_relative_sums.mat', scen_name));

        if ~raw_only
            bootstrap_file = fullfile(processed_dir, sprintf('%s_relative_sums_bootstraps.mat', scen_name));
        end
        
        if exist(rel_sums_file, 'file')
            load(rel_sums_file, 'all_relative_sums');
            col_name = strcat(metric, '_full');
            if ismember(col_name, all_relative_sums.Properties.VariableNames)
                scenario_data(scen_name) = all_relative_sums.(col_name);
            end
        end
        
        if ~raw_only && exist(bootstrap_file, 'file')
            load(bootstrap_file, 'bootstrap_table');
            col_name = strcat(metric, '_full');
            if ismember(col_name, bootstrap_table.Properties.VariableNames)
                scenario_bootstrap_data(scen_name) = bootstrap_table.(col_name);
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
        complementarity_data.(inv_name).bootstrap_data = {};
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
                if ~raw_only && scenario_bootstrap_data.isKey(alone_scen)
                    complementarity_data.(inv_name).bootstrap_data{end+1} = scenario_bootstrap_data(alone_scen);
                else
                    complementarity_data.(inv_name).bootstrap_data{end+1} = [];
                end
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
                        
                        % Calculate bootstrap complementarity if available
                        if ~raw_only && ...
                           scenario_bootstrap_data.isKey(combined_scen) && ...
                           scenario_bootstrap_data.isKey(alone_inv_scen) && ...
                           scenario_bootstrap_data.isKey(alone_other_scen)
                            
                            combined_boot = scenario_bootstrap_data(combined_scen);
                            alone_inv_boot = scenario_bootstrap_data(alone_inv_scen);
                            alone_other_boot = scenario_bootstrap_data(alone_other_scen);
                            
                            min_boot_len = min([length(combined_boot), length(alone_inv_boot), length(alone_other_boot)]);
                            complementarity_boot = combined_boot(1:min_boot_len) - ...
                                                  (alone_inv_boot(1:min_boot_len) + alone_other_boot(1:min_boot_len));
                            
                            complementarity_data.(inv_name).bootstrap_data{end+1} = complementarity_boot;
                        else
                            complementarity_data.(inv_name).bootstrap_data{end+1} = [];
                        end
                    end
                end
            end
        end
    end
end

