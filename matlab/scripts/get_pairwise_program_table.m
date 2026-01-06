function get_pairwise_program_table(job_dir)
    % Load data from raw results directory
    rawdata_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");
    create_folders_recursively(processed_dir);

    % Get scenarios from config
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, 'baseline') & ...
                          ~contains(scenarios, "prec1") & ...
                          ~contains(scenarios, "prevac0"));

    % Initialize table
    summary_table = table('Size', [length(scenarios) 13], ...
        'VariableTypes', {'string', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'BenefitDiff', 'CostDiff', 'NPVDiff',  ...
        'BCRatio10yr', 'BCRatio30yr', 'BCRatioAll', 'Lives10yr', 'Lives30yr', ...
        'LivesAll', 'CostPerLife10yr', 'CostPerLife30yr', 'CostPerLifeAll'};

    
    % Get results for each scenario
    for i = 1:length(scenarios)
        scen_name = scenarios(i);

        % Load relative sums table
        sums_data = load(fullfile(rawdata_dir, sprintf('%s_relative_sums.mat', scen_name)));
        sums_table = sums_data.scenario_sum_table;
        
        % Extract values from the sums table
        npv_diff = mean(sums_table.net_value_pv_full);
        cost_diff = mean(sums_table.total_costs_pv_full);
        benefit_diff = mean(sums_table.benefits_vaccine_full);
        
        cost_diff_10yr = mean(sums_table.total_costs_pv_10_years);
        cost_diff_30yr = mean(sums_table.total_costs_pv_30_years);
        benefit_diff_10yr = mean(sums_table.benefits_vaccine_10_years);
        benefit_diff_30yr = mean(sums_table.benefits_vaccine_30_years);
        
        % Lives saved are negative as difference from baseline
        lives_10yr = mean(-sums_table.m_deaths_10_years);
        lives_30yr = mean(-sums_table.m_deaths_30_years);
        lives_all = mean(-sums_table.m_deaths_full);
        
        % Calculate benefit-cost ratios for different time horizons
        bc_ratio_10yr = benefit_diff_10yr / (cost_diff_10yr + eps);
        bc_ratio_30yr = benefit_diff_30yr / (cost_diff_30yr + eps);
        bc_ratio_all = benefit_diff / (cost_diff + eps);
        
        % Calculate cost per life saved
        cost_per_life_10yr = (cost_diff_10yr / lives_10yr);
        cost_per_life_30yr = (cost_diff_30yr / lives_30yr);
        cost_per_life_all = (cost_diff / lives_all);
        
        % Add to table
        summary_table(i,:) = {scen_name, benefit_diff, cost_diff, npv_diff, ...
                             bc_ratio_10yr, bc_ratio_30yr, bc_ratio_all, lives_10yr, lives_30yr, ...
                             lives_all, cost_per_life_10yr, cost_per_life_30yr, cost_per_life_all};
    end

    % Add accents and investment indicators to table
    [accents, investment_indicators] = parse_scenario_name(scenarios);

    summary_table.accent = accents;

    investments = investment_indicators.Properties.VariableNames;
    for i = 1:length(investments)
        summary_table.(investments{i}) = investment_indicators.(investments{i});
    end

    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'pairwise_npv_summary.csv'));

    % Create LaTeX table for surplus scenarios
    surplus_summary_table = summary_table(strcmp(summary_table.accent, "surplus"), :);

    outpath = fullfile(processed_dir, "pairwise_npv_summary.tex");
    create_table(surplus_summary_table, investments, outpath);

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

function create_table(summary_data, investments, outpath)

    % Convert to appropriate units
    summary_data.NPVDiff = summary_data.NPVDiff / 1e9; % to billions
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9;
    summary_data.CostDiff = summary_data.CostDiff / 1e9;
    summary_data.CostPerLifeAll = summary_data.CostPerLifeAll / 1e3;

    % Round lives saved
    round_lives = @(x) arrayfun(@(y) round(y, -2) * (y < 1e4) + round(y, -3) * (y >= 1e4), x);
    summary_data.LivesAll = comma_format(round_lives(summary_data.LivesAll));
    
    % Nice rounding for BCR, costs, etc.
    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));

    function s = bcr_to_string(x, less_than_zero_to_inf)
        inf_idx = isinf(x); if less_than_zero_to_inf, inf_idx = inf_idx | (x < 0); end
        s = round_nicely(x); s(inf_idx) = "$\infty$";
    end

    summary_data.NPVDiff = round_nicely(summary_data.NPVDiff);
    summary_data.BenefitDiff = round_nicely(summary_data.BenefitDiff);
    summary_data.CostDiff = round_nicely(summary_data.CostDiff);
    summary_data.BCRatioAll = bcr_to_string(summary_data.BCRatioAll, true);
    summary_data.CostPerLifeAll = bcr_to_string(summary_data.CostPerLifeAll, false);
    
    % Escape LaTeX special chars & in names
    summary_data.Scenario = replace(string(summary_data.Scenario), "&", "\&");

    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');

    % Table 1: Effects summary (costs, benefits, net, lives)
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated expected benefits, costs, net value, and lives saved from advance investment programs.} Monetary estimates are discounted.}\n'
    ];
    fprintf(fileID, caption_str);
    fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c}\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, ...
        'Investment & Costs (\\$~bn) & Benefits (\\$~bn) & Net value (\\$~bn) & Lives saved \\\\\n');

    for i = 1:length(investments)
        current_investment = investments{i};
        investment_scenarios = summary_data(summary_data.(current_investment), :);
        clean_investment_name = get_clean_investment_name(current_investment);
        fprintf(fileID, '%s \\\\\n', clean_investment_name);

        % For ordering: Alone first, then With-PROGRAM sorted alphabetically
        alone_idx = [];
        with_indices = [];
        with_names = {};

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
            name = "Alone";
            fprintf(fileID, '\\hspace{3mm} %s & ', name);
            fprintf(fileID, '%s & %s & %s & %s \\\\\n', ...
                investment_scenarios.CostDiff(alone_idx), ...
                investment_scenarios.BenefitDiff(alone_idx), ...
                investment_scenarios.NPVDiff(alone_idx), ...
                investment_scenarios.LivesAll(alone_idx));
        end

        % Print With combos in alphabetical order
        % Make sure with_names is a cell array of char vectors
        if ~isempty(with_names)
            [sorted_names, sort_idx] = sort(with_names);
            for k = 1:length(sorted_names)
                idx = with_indices(sort_idx(k));
                name = "With " + string(sorted_names{k});
                fprintf(fileID, '\\hspace{3mm} %s & ', name);
                fprintf(fileID, '%s & %s & %s & %s \\\\\n', ...
                    investment_scenarios.CostDiff(idx), ...
                    investment_scenarios.BenefitDiff(idx), ...
                    investment_scenarios.NPVDiff(idx), ...
                    investment_scenarios.LivesAll(idx));
            end
        end
    end

    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');
end


function clean_name = get_clean_investment_name(investment)
    clean_map = dictionary(["advance_capacity", "early_warning", "neglected_pathogen", "universal_flu"], ...
                           ["Advance capacity", "Early warning", "Neglected pathogen R\&D", "Universal flu vaccine R\&D"]);

    clean_name = clean_map(investment);
end