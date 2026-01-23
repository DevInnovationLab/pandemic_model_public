function get_pairwise_program_table(job_dir, varargin)
    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'recompute_ci', false, @islogical);
    parse(p, varargin{:});
    recompute_ci = p.Results.recompute_ci;
    
    % Load data from processed results directory
    processed_dir = fullfile(job_dir, "processed");
    
    % Get scenarios from config
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, 'baseline') & ...
                          ~contains(scenarios, "prec1") & ...
                          ~contains(scenarios, "prevac0"));

    fprintf('Processing %d scenarios\n', length(scenarios));

    % Check if CI file exists
    ci_file = fullfile(processed_dir, 'pairwise_confidence_intervals.mat');
    ci_exists = exist(ci_file, 'file');
    
    if ~recompute_ci && ci_exists
        fprintf('Loading existing confidence intervals from %s\n', ci_file);
        ci_data = load(ci_file);
        ci_table = ci_data.ci_table;
        
        % Check if complementarity CI table exists
        if isfield(ci_data, 'complementarity_ci_table')
            complementarity_ci_table = ci_data.complementarity_ci_table;
            has_complementarity_ci = true;
        else
            fprintf('No complementarity CI data found in saved file\n');
            has_complementarity_ci = false;
        end
        
        % Verify that all scenarios are present
        if all(ismember(scenarios, ci_table.Scenario))
            fprintf('All scenarios found in saved CI data\n');
            use_saved_ci = true;
        else
            fprintf('Some scenarios missing from saved CI data, recomputing...\n');
            use_saved_ci = false;
            has_complementarity_ci = false;
        end
    else
        if recompute_ci
            fprintf('Recomputing confidence intervals as requested\n');
        else
            fprintf('No saved confidence intervals found, computing...\n');
        end
        use_saved_ci = false;
        has_complementarity_ci = false;
    end

    % Initialize table
    summary_table = table('Size', [length(scenarios) 9], ...
        'VariableTypes', {'string', 'double', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'BenefitDiff', 'BenefitCI_lower', 'BenefitCI_upper', ...
        'CostDiff', 'CostCI_lower', 'CostCI_upper', 'BCRatio', 'BCR_CI_lower'};

    % Initialize CI table if computing
    if ~use_saved_ci
        ci_table = table('Size', [length(scenarios) 7], ...
            'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double', 'double'});
        ci_table.Properties.VariableNames = {...
            'Scenario', 'BenefitCI_lower', 'BenefitCI_upper', ...
            'CostCI_lower', 'CostCI_upper', 'BCR_CI_lower', 'BCR_CI_upper'};
    end
    
    % Store raw data for complementarity calculations
    raw_data = struct();
    
    % Get results for each scenario
    for i = 1:length(scenarios)
        scen_name = scenarios(i);
        fprintf('Processing scenario %d/%d: %s\n', i, length(scenarios), scen_name);

        % Load relative sums table
        sums_file = fullfile(processed_dir, sprintf('%s_relative_sums.mat', scen_name));
        fprintf('  Loading file: %s\n', sums_file);
        tic;
        sums_data = load(sums_file);
        all_relative_sums = sums_data.all_relative_sums;
        fprintf('  Loaded in %.2f seconds\n', toc);
        
        % Store raw data for complementarity calculations
        raw_data.(scen_name).benefits = all_relative_sums.benefits_vaccine_full;
        raw_data.(scen_name).costs = all_relative_sums.total_costs_pv_full;
        
        % Extract values from the sums table
        fprintf('  Computing means...\n');
        tic;
        cost_diff = mean(all_relative_sums.total_costs_pv_full);
        benefit_diff = mean(all_relative_sums.benefits_vaccine_full);
        fprintf('  Means computed in %.2f seconds\n', toc);
        
        % Calculate benefit-cost ratio
        bc_ratio = benefit_diff / (cost_diff);
        
        % Get or compute confidence intervals
        if use_saved_ci
            % Look up CI from saved data
            ci_row = ci_table(ci_table.Scenario == scen_name, :);
            benefit_ci = [ci_row.BenefitCI_lower; ci_row.BenefitCI_upper];
            cost_ci = [ci_row.CostCI_lower; ci_row.CostCI_upper];
            bcr_ci = [ci_row.BCR_CI_lower; ci_row.BCR_CI_upper];
            fprintf('  Using saved confidence intervals\n');
        else
            % Compute 90% confidence intervals using bootstrap
            fprintf('  Computing benefit CI...\n');
            tic;
            benefit_ci = bootci(1000, {@mean, all_relative_sums.benefits_vaccine_full}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  Benefit CI computed in %.2f seconds\n', toc);
            
            fprintf('  Computing cost CI...\n');
            tic;
            cost_ci = bootci(1000, {@mean, all_relative_sums.total_costs_pv_full}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  Cost CI computed in %.2f seconds\n', toc);
            
            fprintf('  Computing BCR CI...\n');
            tic;
            bcr_ci = bootci(1000, {@(x,y) mean(x)./mean(y), all_relative_sums.benefits_vaccine_full, all_relative_sums.total_costs_pv_full}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  BCR CI computed in %.2f seconds\n', toc);
            
            % Save to CI table
            ci_table(i, :) = {scen_name, benefit_ci(1), benefit_ci(2), ...
                             cost_ci(1), cost_ci(2), bcr_ci(1), bcr_ci(2)};
        end
        
        % Add to table
        summary_table(i,:) = {scen_name, benefit_diff, benefit_ci(1), benefit_ci(2), ...
                             cost_diff, cost_ci(1), cost_ci(2), bc_ratio, bcr_ci(1)};
        fprintf('  Scenario %s complete\n\n', scen_name);
    end

    fprintf('Parsing scenario names...\n');
    % Add accents and investment indicators to table
    [accents, investment_indicators] = parse_scenario_name(scenarios);

    summary_table.accent = accents;

    investments = investment_indicators.Properties.VariableNames;
    for i = 1:length(investments)
        summary_table.(investments{i}) = investment_indicators.(investments{i});
    end

    % Compute complementarity CIs if needed
    if ~has_complementarity_ci
        fprintf('Computing complementarity confidence intervals...\n');
        surplus_summary_table = summary_table(strcmp(summary_table.accent, "surplus"), :);
        complementarity_ci_table = compute_complementarity_cis(surplus_summary_table, investments, raw_data);
        
        % Save CI tables
        fprintf('Saving confidence intervals to %s\n', ci_file);
        save(ci_file, 'ci_table', 'complementarity_ci_table', '-v7.3');
    else
        fprintf('Using saved complementarity confidence intervals\n');
    end

    % Save table to CSV
    fprintf('Saving CSV...\n');
    writetable(summary_table, fullfile(processed_dir, 'pairwise_npv_summary.csv'));

    % Create LaTeX table for surplus scenarios
    fprintf('Creating LaTeX table...\n');
    surplus_summary_table = summary_table(strcmp(summary_table.accent, "surplus"), :);

    outpath = fullfile(processed_dir, "pairwise_npv_summary.tex");
    create_table(surplus_summary_table, investments, outpath, complementarity_ci_table);
    
    fprintf('Complete!\n');

end

function [accent, investment_indicators] = parse_scenario_name(scenario_name) 
    accent = regexp(scenario_name, '(bcr|surplus)$', 'match', 'once');

    investments = {'advance_capacity', 'early_warning', 'neglected_pathogen', 'universal_flu'};

    investment_indicators = table('Size', [length(scenario_name) 4], ...
                                  'VariableTypes', {'logical', 'logical', 'logical', 'logical'}, ...
                                  'VariableNames', investments);

    for i = 1:length(investments)
        investment_indicators.(investments{i}) = contains(scenario_name, investments{i});
    end

end

function complementarity_ci_table = compute_complementarity_cis(summary_data, investments, raw_data)
    % Initialize table to store complementarity CIs
    % We need one row per unique investment pair combination
    n_pairs = 0;
    for i = 1:length(investments)
        for j = (i+1):length(investments)
            % Check if there's a scenario with both investments
            has_both = false;
            for k = 1:height(summary_data)
                if summary_data.(investments{i})(k) && summary_data.(investments{j})(k)
                    has_both = true;
                    break;
                end
            end
            if has_both
                n_pairs = n_pairs + 1;
            end
        end
    end
    
    complementarity_ci_table = table('Size', [n_pairs 8], ...
        'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double', 'double', 'double'});
    complementarity_ci_table.Properties.VariableNames = {...
        'Investment', 'WithInvestment', 'BenefitComp', 'BenefitCompCI_lower', 'BenefitCompCI_upper', ...
        'CostComp', 'CostCompCI_lower', 'CostCompCI_upper'};
    
    row_idx = 1;
    
    % Iterate through unique pairs of investments
    for i = 1:length(investments)
        for j = (i+1):length(investments)
            investment1 = investments{i};
            investment2 = investments{j};
            
            fprintf('  Computing complementarity CIs for %s with %s\n', investment1, investment2);
            
            % Find the "with" scenario (both investments active)
            with_scenario = [];
            for k = 1:height(summary_data)
                is_active = table2array(summary_data(k, investments));
                if summary_data.(investment1)(k) && summary_data.(investment2)(k) && sum(is_active) == 2
                    with_scenario = summary_data.Scenario(k);
                    break;
                end
            end
            
            if isempty(with_scenario)
                continue;
            end
            
            with_benefits = raw_data.(with_scenario).benefits;
            with_costs = raw_data.(with_scenario).costs;
            
            % Find investment1's alone scenario
            alone1_scenario = [];
            for k = 1:height(summary_data)
                is_active = table2array(summary_data(k, investments));
                if summary_data.(investment1)(k) && sum(is_active) == 1
                    alone1_scenario = summary_data.Scenario(k);
                    break;
                end
            end
            
            if isempty(alone1_scenario)
                warning('No alone scenario found for %s', investment1);
                continue;
            end
            
            alone1_benefits = raw_data.(alone1_scenario).benefits;
            alone1_costs = raw_data.(alone1_scenario).costs;
            
            % Find investment2's alone scenario
            alone2_scenario = [];
            for k = 1:height(summary_data)
                is_active = table2array(summary_data(k, investments));
                if summary_data.(investment2)(k) && sum(is_active) == 1
                    alone2_scenario = summary_data.Scenario(k);
                    break;
                end
            end
            
            if isempty(alone2_scenario)
                warning('No alone scenario found for %s', investment2);
                continue;
            end
            
            alone2_benefits = raw_data.(alone2_scenario).benefits;
            alone2_costs = raw_data.(alone2_scenario).costs;
            
            % Compute complementarity point estimates
            benefit_comp = mean(with_benefits) - mean(alone1_benefits) - mean(alone2_benefits);
            cost_comp = mean(with_costs) - mean(alone1_costs) - mean(alone2_costs);
            
            % Compute complementarity CIs using bootstrap
            fprintf('    Computing CI for %s with %s\n', investment1, investment2);
            
            % Bootstrap for benefit complementarity
            benefit_comp_ci = bootci(1000, {@(w,a,o) mean(w) - mean(a) - mean(o), ...
                with_benefits, alone1_benefits, alone2_benefits}, ...
                'alpha', 0.1, 'type', 'percentile');
            
            % Bootstrap for cost complementarity
            cost_comp_ci = bootci(1000, {@(w,a,o) mean(w) - mean(a) - mean(o), ...
                with_costs, alone1_costs, alone2_costs}, ...
                'alpha', 0.1, 'type', 'percentile');
            
            % Store in table
            complementarity_ci_table(row_idx, :) = {investment1, investment2, ...
                benefit_comp, benefit_comp_ci(1), benefit_comp_ci(2), ...
                cost_comp, cost_comp_ci(1), cost_comp_ci(2)};
            row_idx = row_idx + 1;
        end
    end
end

function create_table(summary_data, investments, outpath, complementarity_ci_table)

    fprintf('  Converting units...\n');
    % Convert to appropriate units (billions)
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9;
    summary_data.BenefitCI_lower = summary_data.BenefitCI_lower / 1e9;
    summary_data.BenefitCI_upper = summary_data.BenefitCI_upper / 1e9;
    summary_data.CostDiff = summary_data.CostDiff / 1e9;
    summary_data.CostCI_lower = summary_data.CostCI_lower / 1e9;
    summary_data.CostCI_upper = summary_data.CostCI_upper / 1e9;
    
    % Convert complementarity CI table to billions
    complementarity_ci_table.BenefitComp = complementarity_ci_table.BenefitComp / 1e9;
    complementarity_ci_table.BenefitCompCI_lower = complementarity_ci_table.BenefitCompCI_lower / 1e9;
    complementarity_ci_table.BenefitCompCI_upper = complementarity_ci_table.BenefitCompCI_upper / 1e9;
    complementarity_ci_table.CostComp = complementarity_ci_table.CostComp / 1e9;
    complementarity_ci_table.CostCompCI_lower = complementarity_ci_table.CostCompCI_lower / 1e9;
    complementarity_ci_table.CostCompCI_upper = complementarity_ci_table.CostCompCI_upper / 1e9;
    
    % Nice rounding for values
    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));

    function s = bcr_to_string(x, less_than_zero_to_inf)
        inf_idx = isinf(x); if less_than_zero_to_inf, inf_idx = inf_idx | (x < 0); end
        s = round_nicely(x); s(inf_idx) = "$\infty$";
    end

    % Format values with CIs using nested tabular (like get_sensitivity_loss_summary.m)
    function s = format_with_ci(val, ci_lower, ci_upper)
        s = sprintf('\\begin{tabular}[c]{@{}c@{}}%s \\\\[-0.7em] \\footnotesize [%s, %s]\\end{tabular}', ...
                    round_nicely(val), round_nicely(ci_lower), round_nicely(ci_upper));
    end

    fprintf('  Formatting values...\n');
    summary_data.BenefitFormatted = arrayfun(@(i) format_with_ci(summary_data.BenefitDiff(i), summary_data.BenefitCI_lower(i), summary_data.BenefitCI_upper(i)), (1:height(summary_data))', 'UniformOutput', false);
    summary_data.CostFormatted = arrayfun(@(i) format_with_ci(summary_data.CostDiff(i), summary_data.CostCI_lower(i), summary_data.CostCI_upper(i)), (1:height(summary_data))', 'UniformOutput', false);
    summary_data.BCRFormatted = bcr_to_string(summary_data.BCRatio, true);
    
    % Escape LaTeX special chars & in names
    summary_data.Scenario = replace(string(summary_data.Scenario), "&", "\&");

    % Open LaTeX file for writing
    fprintf('  Opening file: %s\n', outpath);
    fileID = fopen(outpath, 'w');

    % Table: Effects summary with complementarities
    fprintf('  Writing table header...\n');
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated expected benefits and costs from advance investment programs.} Monetary estimates are discounted. 90\\%% confidence intervals shown in brackets.}\n'
    ];
    fprintf(fileID, caption_str);
    fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c}\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, ...
        ' & \\multicolumn{2}{c}{Benefits (\\$~bn)} & \\multicolumn{2}{c}{Costs (\\$~bn)} \\\\\n');
    fprintf(fileID, ...
        '\\cline{2-3} \\cline{4-5}\n');
    fprintf(fileID, ...
        'Investment & Total & Complementarity & Total & Complementarity \\\\\n');
    fprintf(fileID, '\\hline\n');

    fprintf('  Writing table rows...\n');
    for i = 1:length(investments)
        current_investment = investments{i};
        fprintf('    Processing investment %d/%d: %s\n', i, length(investments), current_investment);
        investment_scenarios = summary_data(summary_data.(current_investment), :);
        clean_investment_name = get_clean_investment_name(current_investment);
        fprintf(fileID, '%s \\\\\n', clean_investment_name);

        % For ordering: Alone first, then With-PROGRAM sorted alphabetically
        alone_idx = [];
        with_indices = [];
        with_names = {};

        fprintf('      Finding alone and with scenarios...\n');
        for j = 1:height(investment_scenarios)
            current_row = investment_scenarios(j, :);
            is_active = table2array(current_row(:, investments));
            if sum(is_active) == 1
                alone_idx = j;
            else
                % Find which other investment it is matched with (not current)
                other_idx = find(is_active & ~strcmp(investments, current_investment));
                if isscalar(other_idx)
                    other_investment = investments{other_idx};
                    name = get_clean_investment_name(other_investment);
                    with_names{end+1} = char(name); % Ensure cellstr of char, not string
                    with_indices(end+1) = j;
                else
                    warning("More than one investment active");
                end
            end
        end

        % Print Alone first
        if ~isempty(alone_idx)
            fprintf('      Writing alone row...\n');
            name = "Alone";
            fprintf(fileID, '\\hspace{3mm} %s & ', name);
            fprintf(fileID, '%s & --- & %s & --- \\\\\n', ...
                investment_scenarios.BenefitFormatted{alone_idx}, ...
                investment_scenarios.CostFormatted{alone_idx});
        end

        % Print With combos in alphabetical order
        if ~isempty(with_names)
            fprintf('      Writing %d with rows...\n', length(with_names));
            [sorted_names, sort_idx] = sort(with_names);
            for k = 1:length(sorted_names)
                fprintf('        Processing with row %d/%d: %s\n', k, length(sorted_names), sorted_names{k});
                idx = with_indices(sort_idx(k));
                name = "With " + string(sorted_names{k});
                
                % Get the other investment name
                other_investment_name = investments{find(table2array(investment_scenarios(idx, investments)) & ~strcmp(investments, current_investment))};
                
                % Look up complementarity CI from table
                % Need to check both orderings since we only store unique pairs
                comp_row = complementarity_ci_table((strcmp(complementarity_ci_table.Investment, current_investment) & ...
                                                     strcmp(complementarity_ci_table.WithInvestment, other_investment_name)) | ...
                                                    (strcmp(complementarity_ci_table.Investment, other_investment_name) & ...
                                                     strcmp(complementarity_ci_table.WithInvestment, current_investment)), :);
                
                if isempty(comp_row)
                    warning('No complementarity data found for %s with %s', current_investment, other_investment_name);
                    benefit_comp_formatted = '---';
                    cost_comp_formatted = '---';
                else
                    benefit_comp_formatted = format_with_ci(comp_row.BenefitComp, comp_row.BenefitCompCI_lower, comp_row.BenefitCompCI_upper);
                    cost_comp_formatted = format_with_ci(comp_row.CostComp, comp_row.CostCompCI_lower, comp_row.CostCompCI_upper);
                end
                
                fprintf(fileID, '\\hspace{3mm} %s & ', name);
                fprintf(fileID, '%s & %s & %s & %s \\\\\n', ...
                    investment_scenarios.BenefitFormatted{idx}, ...
                    benefit_comp_formatted, ...
                    investment_scenarios.CostFormatted{idx}, ...
                    cost_comp_formatted);
            end
        end
    end

    fprintf('  Writing table footer...\n');
    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');
    
    fclose(fileID);
    fprintf('  LaTeX table written successfully\n');
end


function clean_name = get_clean_investment_name(investment)
    clean_map = dictionary(["advance_capacity", "early_warning", "neglected_pathogen", "universal_flu"], ...
                           ["Advance capacity", "Early warning", "Neglected pathogen R\&D", "Universal flu vaccine R\&D"]);

    clean_name = clean_map(investment);
end