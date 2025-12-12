function create_ufv_comparison_table(job_dir, recalculate_bc)
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

    % Get scenarios from config. Only want to look at early warning scenarios.
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(strcmp(scenarios, 'baseline') | (contains(scenarios, "universal_flu")));

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

    [accents, investment_indicators] = parse_scenario_name(scenarios);

    init_vax_share = zeros(size(accents));
    for i = 1:length(scenarios)
       scenario = scenarios(i);
       scenario_params = config.scenarios.(scenario);
       init_vax_share(i) = scenario_params.universal_flu_rd.initial_share_ufv;
    end

    summary_table.accent = accents;
    summary_table.initial_share_ufv = init_vax_share;

    investments = investment_indicators.Properties.VariableNames;
    for i = 1:length(investments)
        summary_table.(investments{i}) = investment_indicators.(investments{i});
    end
    
    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'ufv_investigation_summary.csv'));

    % Now let's create the table
    surplus_summary_table = summary_table(strcmp(summary_table.accent, "surplus"), :);

    outpath = fullfile(processed_dir, "ufv_investigation_summary.tex");
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
    fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c}\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, ...
        'Investment & Costs (\\$~bn) & Benefits (\\$~bn) & Lives saved \\\\\n');

    % Instead of looping through investments, output all universal flu vaccine scenarios.
    % First, sort table by initial_share_ufv, then within each, print Alone first, then "With" scenarios alphabetically.

    % Sort by initial share (initial_share_ufv)
    [~, order_idx] = sort(summary_data.initial_share_ufv);
    summary_data = summary_data(order_idx, :);

    % Get unique initial_share_ufv (initial_share_ufv) values in sorted order
    unique_shares = unique(summary_data.initial_share_ufv);

    for s = 1:length(unique_shares)
        share = unique_shares(s);

        % Get all scenarios with this share
        share_rows = summary_data(summary_data.initial_share_ufv == share, :)

        % Print header for initial share
        fprintf(fileID, '\\multicolumn{5}{l}{\\textbf{Initial share UFV: %.2g}} \\\\\n', share);

        % Find "Alone" scenario: only universal_flu is true among investments
        only_ufv = share_rows.universal_flu & ...
                   ~share_rows.advance_capacity & ~share_rows.early_warning & ~share_rows.neglected_pathogen;
        alone_idx = find(only_ufv);

        % Print Alone scenario first if it exists
        if ~isempty(alone_idx)
            name = "Alone";
            fprintf(fileID, '\\hspace{3mm} %s & ', name);
            fprintf(fileID, '%s & %s & %s \\\\\n', ...
                share_rows.CostDiff(alone_idx), ...
                share_rows.BenefitDiff(alone_idx), ...
                share_rows.LivesAll(alone_idx));
        end

        % Now find "With" scenarios: universal_flu plus *one* other investment
        with_mask = share_rows.universal_flu & ...
            (share_rows.advance_capacity + share_rows.early_warning + share_rows.neglected_pathogen == 1);

        with_idxs = find(with_mask);

        % For each "With" row, assign the name of the other investment
        with_names = {};
        for i = 1:length(with_idxs)
            idx = with_idxs(i);
            row = share_rows(idx, :);
            % Find which non-ufv investment is true
            other = '';
            if row.advance_capacity, other = 'Advance capacity'; end
            if row.early_warning,   other = 'Early warning';   end
            if row.neglected_pathogen, other = 'Neglected pathogen'; end
            with_names{i} = other;
        end

        % Sort "With" scenarios alphabetically by name
        [sorted_with_names, sort_idx] = sort(with_names);
        sorted_with_idxs = with_idxs(sort_idx);

        for k = 1:length(sorted_with_idxs)
            idx = sorted_with_idxs(k);
            name = "With " + sorted_with_names{k};
            fprintf(fileID, '\\hspace{3mm} %s & ', name);
            fprintf(fileID, '%s & %s & %s \\\\\n', ...
                share_rows.CostDiff(idx), ...
                share_rows.BenefitDiff(idx), ...
                share_rows.LivesAll(idx));
        end
    end

    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');
end