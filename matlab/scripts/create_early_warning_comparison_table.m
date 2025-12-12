function create_early_warning_comparison_table(job_dir, recalculate_bc)
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
    scenarios = scenarios(strcmp(scenarios, 'baseline') | (contains(scenarios, "early_warning") & ~contains(scenarions, "_and_")));

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

    accents = regexp(scenario_name, '(bcr|surplus)$', 'match', 'once');
    
    precisions = zeros(size(accents));
    recalls = zeros(size(accents));
    for i = 1:length(scenarios)
       scenario = scenarios(i);
       scenario_params = config.scenarios.(scenario);
       precisions(i) = scenario_params.improved_early_warning.precision;
       recalls(i) = scenario_params.improved_early_warning.recall;
    end

    summary_table.accent = accents;
    summary_table.precision = precisions;
    summary_table.recall = recalls;

    disp(summary_table)
    disp(scenarios)

    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'early_warning_variant_summary.csv'));

    % Write latex table
    outpath = fullfile(processed_dir, "early_warning_variant_summary.tex");
    create_table(summary_table, investments, outpath);

end


function create_table(summary_data)
    
    % Convert to appropriate units
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
        '\\caption{\\textbf{Estimated expected benefits, costs, and lives saved across early warning program variants.} Monetary estimates are discounted.}\n'
    ];
    fprintf(fileID, caption_str);
    fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c}\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, ...
        'Description & Sensivitity & Precision & Costs (\\$~bn) & Benefits (\\$~bn) & Lives saved \\\\\n');

    for i = 1:height(summary_data)
        printf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
                summary_data.description{i}, ...
                summary_data.recall(i), ...
                summary_data.precision(i), ...
                summary_data.CostDiff(i), ...
                summary_data.BenefitDiff(i), ...
                summary_data.LivesAll(i));
    end

    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');
end

function description = get_description(scenario_name)

    dictmap = dictionary()
end