function get_pairwise_program_table(job_dir, recalculate_bc)
    if recalculate_bc
        process_benefit_cost(job_dir, recalculate_bc);
    end

    % Load baseline data
    rawdata_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");
    baseline_npv = readmatrix(fullfile(processed_dir, "baseline_absolute_npv.csv"));
    baseline_costs = readmatrix(fullfile(processed_dir, "baseline_pv_costs.csv"));
    load(fullfile(rawdata_dir, "baseline_results.mat"), "m_deaths");
    baseline_mortality = m_deaths;
    
    % Calculate total baseline values
    total_baseline_npv = mean(sum(baseline_npv, 2));
    total_baseline_costs = mean(sum(baseline_costs, 2));

    % Get scenarios from config
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, 'baseline') & ...
                          ~contains(scenarios, "precision1") & ...
                          ~contains(scenarios, "initshare0"));

    % Initialize table with baseline row, now with LivesAll and CostPerLifeAll
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

        % Load scenario data
        scen_npv = readmatrix(fullfile(processed_dir, strcat(scen_name, "_absolute_npv.csv")));
        scen_costs = readmatrix(fullfile(processed_dir, strcat(scen_name, "_pv_costs.csv")));
        scen_benefits = scen_npv + scen_costs; % Benefits = NPV + Costs
        load(fullfile(rawdata_dir, sprintf('%s_results.mat', scen_name)), 'm_deaths');
        scen_mortality = m_deaths;
        
        % Calculate differences from baseline for different time horizons
        total_scen_npv = mean(sum(scen_npv, 2));
        total_scen_costs = mean(sum(scen_costs, 2));
        total_scen_benefits = mean(sum(scen_benefits, 2));
        
        % 10 year costs and benefits
        total_scen_costs_10yr = mean(sum(scen_costs(:,1:10), 2));
        total_baseline_costs_10yr = mean(sum(baseline_costs(:,1:10), 2));
        total_scen_benefits_10yr = mean(sum(scen_benefits(:,1:10), 2));
        total_baseline_benefits_10yr = mean(sum(baseline_npv(:,1:10) + baseline_costs(:,1:10), 2));
        
        % 30 year costs and benefits
        total_scen_costs_30yr = mean(sum(scen_costs(:,1:30), 2));
        total_baseline_costs_30yr = mean(sum(baseline_costs(:,1:30), 2));
        total_scen_benefits_30yr = mean(sum(scen_benefits(:,1:30), 2));
        total_baseline_benefits_30yr = mean(sum(baseline_npv(:,1:30) + baseline_costs(:,1:30), 2));
        
        % Calculate differences
        npv_diff = total_scen_npv - total_baseline_npv;
        cost_diff = total_scen_costs - total_baseline_costs;
        benefit_diff = total_scen_benefits - (total_baseline_npv + total_baseline_costs);
        
        cost_diff_10yr = total_scen_costs_10yr - total_baseline_costs_10yr;
        cost_diff_30yr = total_scen_costs_30yr - total_baseline_costs_30yr;
        benefit_diff_10yr = total_scen_benefits_10yr - total_baseline_benefits_10yr;
        benefit_diff_30yr = total_scen_benefits_30yr - total_baseline_benefits_30yr;
        
        % Calculate lives saved
        lives_diff = baseline_mortality - scen_mortality;
        lives_10yr = mean(sum(lives_diff(:,1:10), 2));
        lives_30yr = mean(sum(lives_diff(:,1:30), 2));
        lives_all = mean(sum(lives_diff, 2));
        
        % Calculate benefit-cost ratios for different time horizons
        bc_ratio_10yr = benefit_diff_10yr / (cost_diff_10yr + eps);
        bc_ratio_30yr = benefit_diff_30yr / (cost_diff_30yr + eps);
        bc_ratio_all = benefit_diff / (cost_diff + eps);
        
        % Calculate cost per life saved using time-bound costs
        cost_per_life_10yr = (cost_diff_10yr / lives_10yr);
        cost_per_life_30yr = (cost_diff_30yr / lives_30yr);
        cost_per_life_all = (cost_diff / lives_all);
        
        % Add to table
        summary_table(i,:) = {scen_name, benefit_diff, cost_diff, npv_diff, ...
                             bc_ratio_10yr, bc_ratio_30yr, bc_ratio_all, lives_10yr, lives_30yr, ...
                             lives_all, cost_per_life_10yr, cost_per_life_30yr, cost_per_life_all};

        % % Convert any Inf values to NaN in the summary table
        % summary_table.CostPerLife10yr(isinf(summary_table.CostPerLife10yr)) = NaN;
        % summary_table.CostPerLife30yr(isinf(summary_table.CostPerLife30yr)) = NaN;
        % summary_table.CostPerLifeAll(isinf(summary_table.CostPerLifeAll)) = NaN;
    end

    % Now add accents and investments indicators to table.
    [accents, investment_indicators] = parse_scenario_name(scenarios);

    summary_table.accent = accents;

    investments = investment_indicators.Properties.VariableNames;
    for i = 1:length(investments)
        summary_table.(investments{i}) = investment_indicators.(investments{i});
    end

    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'pairwise_npv_summary.csv'));

    % Now let's create the table
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