function write_pairwise_program_table(job_dir)
    % Load data from processed results directory
    processed_dir = fullfile(job_dir, "processed");

    % Get scenarios from config
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, 'baseline') & ...
                          ~contains(scenarios, "prec1") & ...
                          ~contains(scenarios, "prevac0"));

    fprintf('Processing %d scenarios\n', length(scenarios));

    % Initialize summary table (point estimates only): net value = benefits - costs
    summary_table = table('Size', [length(scenarios) 2], ...
        'VariableTypes', {'string', 'double'});
    summary_table.Properties.VariableNames = {'Scenario', 'NetValue'};

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
        raw_data.(scen_name).benefits = all_relative_sums.tot_benefits_pv_full;
        raw_data.(scen_name).costs = all_relative_sums.costs_adv_invest_pv_full;
        
        % Extract net value (benefits - costs, same definition as detailed table)
        fprintf('  Computing means...\n');
        tic;
        net_value = mean(all_relative_sums.tot_benefits_pv_full - all_relative_sums.costs_adv_invest_pv_full);
        fprintf('  Means computed in %.2f seconds\n', toc);

        % Add to table
        summary_table(i, :) = {scen_name, net_value};
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

    % Compute complementarity point estimates
    fprintf('Computing complementarity...\n');
    surplus_summary_table = summary_table(strcmp(summary_table.accent, "surplus"), :);
    complementarity_table = compute_complementarity(surplus_summary_table, investments, raw_data);

    % Save table to CSV
    fprintf('Saving CSV...\n');
    writetable(summary_table, fullfile(processed_dir, 'pairwise_npv_summary.csv'));

    % Create LaTeX table for surplus scenarios
    fprintf('Creating LaTeX table...\n');
    surplus_summary_table = summary_table(strcmp(summary_table.accent, "surplus"), :);

    outpath = fullfile(processed_dir, "pairwise_npv_summary.tex");
    create_table(surplus_summary_table, investments, outpath, complementarity_table);
    
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

function complementarity_table = compute_complementarity(summary_data, investments, raw_data)
    % Compute complementarity point estimates (net value) for each investment pair.
    n_pairs = 0;
    for i = 1:length(investments)
        for j = (i+1):length(investments)
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

    complementarity_table = table('Size', [n_pairs 3], ...
        'VariableTypes', {'string', 'string', 'double'});
    complementarity_table.Properties.VariableNames = {...
        'Investment', 'WithInvestment', 'NetValueComp'};

    row_idx = 1;
    for i = 1:length(investments)
        for j = (i+1):length(investments)
            investment1 = investments{i};
            investment2 = investments{j};

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

            net_with = mean(with_benefits - with_costs);
            net_alone1 = mean(alone1_benefits - alone1_costs);
            net_alone2 = mean(alone2_benefits - alone2_costs);
            net_value_comp = net_with - net_alone1 - net_alone2;

            complementarity_table(row_idx, :) = {investment1, investment2, net_value_comp};
            row_idx = row_idx + 1;
        end
    end
end

function create_table(summary_data, investments, outpath, complementarity_table)

    fprintf('  Converting units...\n');
    summary_data.NetValue = summary_data.NetValue / 1e9;
    complementarity_table.NetValueComp = complementarity_table.NetValueComp / 1e9;

    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x, 1));

    fprintf('  Formatting values...\n');
    summary_data.NetValueFormatted = arrayfun(@(i) round_nicely(summary_data.NetValue(i)), (1:height(summary_data))', 'UniformOutput', false);
    
    % Escape LaTeX special chars & in names
    summary_data.Scenario = replace(string(summary_data.Scenario), "&", "\&");

    % Open LaTeX file for writing
    fprintf('  Opening file: %s\n', outpath);
    fileID = fopen(outpath, 'w');

    % Table: Effects summary with complementarities
    fprintf('  Writing table header...\n');
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated expected net value from advance investment programs.} Net value is benefits minus costs; monetary estimates are discounted.}\n'
    ];
    fprintf(fileID, caption_str);
    fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c}\n');
    fprintf(fileID, '\\small\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, 'Investment & Net value (\\$~bn) & Complementarity \\\\\n');
    fprintf(fileID, '\\hline\n');

    fprintf('  Writing table rows...\n');
    for i = 1:length(investments)
        current_investment = investments{i};
        fprintf('    Processing investment %d/%d: %s\n', i, length(investments), current_investment);
        investment_scenarios = summary_data(summary_data.(current_investment), :);
        clean_investment_name = get_clean_investment_name(current_investment);

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

        % Print Alone on the same line as the investment name
        if ~isempty(alone_idx)
            fprintf('      Writing alone row...\n');
            fprintf(fileID, '%s & %s & --- \\\\\n', ...
                clean_investment_name, ...
                investment_scenarios.NetValueFormatted{alone_idx});
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
                
                comp_row = complementarity_table((strcmp(complementarity_table.Investment, current_investment) & ...
                                                  strcmp(complementarity_table.WithInvestment, other_investment_name)) | ...
                                                 (strcmp(complementarity_table.Investment, other_investment_name) & ...
                                                  strcmp(complementarity_table.WithInvestment, current_investment)), :);

                if isempty(comp_row)
                    warning('No complementarity data found for %s with %s', current_investment, other_investment_name);
                    comp_formatted = '---';
                else
                    comp_formatted = round_nicely(comp_row.NetValueComp);
                end

                fprintf(fileID, '\\hspace{3mm} %s & %s & %s \\\\\n', ...
                    name, ...
                    investment_scenarios.NetValueFormatted{idx}, ...
                    comp_formatted);
            end
        end
    end

    fprintf('  Writing table footer...\n');
    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_compl_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');
    
    fclose(fileID);
    fprintf('  LaTeX table written successfully\n');
end


function clean_name = get_clean_investment_name(investment)
    clean_map = dictionary(["advance_capacity", "early_warning", "neglected_pathogen", "universal_flu"], ...
                           ["Advance capacity", "Early warning", "Neglected pathogen R\&D", "Universal flu vaccine R\&D"]);

    clean_name = clean_map(investment);
end