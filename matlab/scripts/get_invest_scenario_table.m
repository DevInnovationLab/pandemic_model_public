function get_invest_scenario_table(job_dir, recalculate_bc)
    % Creates a table summarizing costs, NPV differences, lives saved, and benefit-cost ratios
    % for each scenario relative to baseline
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results
    
    % Process benefits and costs
    if recalculate_bc
        process_benefit_cost(job_dir, recalculate_bc);
    end

    % Load baseline data
    rawdata_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");
    baseline_npv = readmatrix(fullfile(processed_dir, "baseline_absolute_npv.csv"));
    baseline_costs = readmatrix(fullfile(processed_dir, "baseline_pv_costs.csv"));
    baseline_mortality = load(fullfile(rawdata_dir, "baseline_results.mat"), "sim_out_arr_m_deaths");
    baseline_mortality = baseline_mortality.sim_out_arr_m_deaths;
    
    % Calculate total baseline values
    total_baseline_npv = mean(sum(baseline_npv, 2));
    total_baseline_costs = mean(sum(baseline_costs, 2));
    
    % Get scenarios from config
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, 'baseline'));
    % Move combined_invest to end
    combined_idx = find(strcmp(scenarios, 'combined_invest'));
    if ~isempty(combined_idx)
        scenarios = [scenarios(1:(combined_idx-1)); 
                    scenarios((combined_idx+1):end);
                    scenarios(combined_idx)];
    end
    % Initialize table with baseline row
    summary_table = table('Size', [length(scenarios) 11], ...
        'VariableTypes', {'string', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double', 'double', ...
                         'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'BenefitDiff', 'CostDiff', 'NPVDiff',  ...
        'BCRatio10yr', 'BCRatio30yr', 'BCRatioAll', 'Lives10yr', 'Lives30yr', ...
        'CostPerLife10yr', 'CostPerLife30yr'};
    
    % Process each scenario
    for i = 1:length(scenarios)
        scen_name = scenarios(i);
        
        % Load scenario data
        scen_npv = readmatrix(fullfile(processed_dir, strcat(scen_name, "_absolute_npv.csv")));
        scen_costs = readmatrix(fullfile(processed_dir, strcat(scen_name, "_pv_costs.csv")));
        scen_benefits = scen_npv + scen_costs; % Benefits = NPV + Costs
        scen_mat = load(fullfile(rawdata_dir, sprintf('%s_results.mat', scen_name)), 'sim_out_arr_m_deaths');
        scen_mortality = scen_mat.sim_out_arr_m_deaths;
        
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
        
        % Calculate benefit-cost ratios for different time horizons
        bc_ratio_10yr = benefit_diff_10yr / cost_diff_10yr;
        bc_ratio_30yr = benefit_diff_30yr / cost_diff_30yr;
        bc_ratio_all = benefit_diff / cost_diff;
        
        % Calculate cost per life saved using time-bound costs
        cost_per_life_10yr = (cost_diff_10yr / lives_10yr);
        cost_per_life_30yr = (cost_diff_30yr / lives_30yr);
        
        % Add to table
        summary_table(i,:) = {scen_name, benefit_diff, cost_diff, npv_diff, ...
                             bc_ratio_10yr, bc_ratio_30yr, bc_ratio_all, lives_10yr, lives_30yr, ...
                             cost_per_life_10yr, cost_per_life_30yr};

    % Convert any Inf values to NaN in the summary table
    summary_table.CostPerLife10yr(isinf(summary_table.CostPerLife10yr)) = NaN;
    summary_table.CostPerLife30yr(isinf(summary_table.CostPerLife30yr)) = NaN;
    end
    
    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'npv_summary.csv'));
    
    % Write to LaTeX
    write_advance_investment_table_latex(summary_table, fullfile(processed_dir, 'advance_investment_summary.tex'));
end

function write_advance_investment_table_latex(summary_data, outpath)
    % Convert to appropriate units
    summary_data.NPVDiff = summary_data.NPVDiff / 1e9; % Convert to billions
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9; % Convert to billions
    summary_data.CostDiff = summary_data.CostDiff / 1e9; % Convert to billions
    summary_data.CostPerLife10yr = summary_data.CostPerLife10yr / 1e3; % Convert to thousands
    summary_data.CostPerLife30yr = summary_data.CostPerLife30yr / 1e3; % Convert to thousands

    % Comma format lives saved numbers
    summary_data.Lives10yr = comma_format(round(summary_data.Lives10yr));
    summary_data.Lives30yr = comma_format(round(summary_data.Lives30yr));

    % Format benefit-cost ratios according to rules:
    % - Round to 0 decimals if >= 10
    % - Round to 1 decimal if < 10
    % - Convert to string vectors
    
    % Format numbers nicely
    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));
    summary_data.NPVDiff = round_nicely(summary_data.NPVDiff);
    summary_data.BenefitDiff = round_nicely(summary_data.BenefitDiff);
    summary_data.CostDiff = round_nicely(summary_data.CostDiff);
    summary_data.BCRatio10yr = round_nicely(summary_data.BCRatio10yr);
    summary_data.BCRatio30yr = round_nicely(summary_data.BCRatio30yr);
    summary_data.BCRatioAll = round_nicely(summary_data.BCRatioAll);

    % Convert scenario names
    summary_data.Scenario
    summary_data.Scenario = convert_varnames(summary_data.Scenario);
    summary_data.Scenario = replace(summary_data.Scenario, "&", "\&"); % Escape ampersands in scenario names for LaTeX
    
    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');
    
    % Write first table with costs and benefits
    fprintf(fileID, '\\begin{table}[h]\n\\centering\n');
    fprintf(fileID, '\\begin{tabular}{l c c c c c}\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, 'Scenario & \\multicolumn{5}{c}{Difference from baseline vaccine program} \\\\\n');
    fprintf(fileID, '\\cline{2-6}\n');
    fprintf(fileID, '& Costs & Benefits & Net present value & \\multicolumn{2}{c}{Expected lives saved} \\\\\n');
    fprintf(fileID, '\\cline{5-6}\n');
    fprintf(fileID, '& \\$ billions & \\$ billions & \\$ billions & After 10 years & After 30 years \\\\\n');
    fprintf(fileID, '\\hline\n');
    
    % Write data rows for first table
    for i = 1:height(summary_data)
        fprintf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
            summary_data.Scenario{i}, ...
            summary_data.CostDiff(i), ...
            summary_data.BenefitDiff(i), ...
            summary_data.NPVDiff(i), ...
            summary_data.Lives10yr(i), ...
            summary_data.Lives30yr(i));
    end
    
    % Write first table footer
    fprintf(fileID, '\\hline\n\\end{tabular}\n');
    caption_str = [
        '\\caption{\\textbf{Estimated expected benefits, costs, net present value and lives saved from advance investment programs.} ', ...
        'Benefits, costs, and net present value estimates are presented in discounted terms. ', ...
        'Values greater than ten are rounded to the nearest whole number. Those lower than ten are rounded to the nearest first decimal place.}\n'
    ];
    fprintf(fileID, caption_str);
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');
    
    % Write second table with cost-effectiveness metrics
    fprintf(fileID, '\\begin{table}[h]\n\\centering\n');
    fprintf(fileID, '\\begin{tabular}{l c c c c c}\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, 'Scenario & \\multicolumn{5}{c}{Cost-effectiveness metrics} \\\\\n');
    fprintf(fileID, '\\cline{2-6}\n');
    fprintf(fileID, '& \\multicolumn{3}{c}{Benefit-cost ratio} & \\multicolumn{2}{c}{\\$ thousands per expected life saved} \\\\\n');
    fprintf(fileID, '\\cline{2-4}\\cline{5-6}\n');
    fprintf(fileID, '& 10 years & 30 years & 50 years & 10 years & 30 years \\\\\n');
    fprintf(fileID, '\\hline\n');
    
    % Write data rows for second table
    for i = 1:height(summary_data)
        fprintf(fileID, '%s & %s & %s & %s & %.0f & %.0f \\\\\n', ...
            summary_data.Scenario{i}, ...
            summary_data.BCRatio10yr(i), ...
            summary_data.BCRatio30yr(i), ...
            summary_data.BCRatioAll(i), ...
            summary_data.CostPerLife10yr(i), ...
            summary_data.CostPerLife30yr(i));
    end
    
    % Write second table footer
    fprintf(fileID, '\\hline\n\\end{tabular}\n');
    caption_str = [
        '\\caption{\\textbf{Estimated cost-effectiveness for advance investment programs.} ', ...
        'Cost-effectiveness is calculated as estimated discounted benefits divided by estimated discounted costs. ', ...
        'Values greater than ten are rounded to the nearest whole number. Those lower than ten are rounded to the nearest first decimal place.}\n'
    ];
    fprintf(fileID, caption_str);
    fprintf(fileID, '\\label{tab:adv_invest_cost_effectiveness}\n');
    fprintf(fileID, '\\end{table}\n');
    
    % Close the file
    fclose(fileID);
end
