function get_invest_scenario_table(job_dir, recalculate_bc)
    % Creates a table summarizing costs, NPV differences, lives saved, and benefit-cost ratios
    % for each scenario relative to baseline.
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results
    %   recalculate_bc (logical): Whether to recalculate benefit-cost data

    % Process benefits and costs
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
    scenarios = scenarios(~strcmp(scenarios, 'baseline'));
    % Move combined_invest to end
    combined_idx = find(strcmp(scenarios, 'combined_invest'));
    if ~isempty(combined_idx)
        scenarios = [scenarios(1:(combined_idx-1)); 
                    scenarios((combined_idx+1):end);
                    scenarios(combined_idx)];
    end
    % Initialize table with baseline row, now with LivesAll and CostPerLifeAll
    summary_table = table('Size', [length(scenarios) 13], ...
        'VariableTypes', {'string', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'BenefitDiff', 'CostDiff', 'NPVDiff',  ...
        'BCRatio10yr', 'BCRatio30yr', 'BCRatioAll', 'Lives10yr', 'Lives30yr', ...
        'LivesAll', 'CostPerLife10yr', 'CostPerLife30yr', 'CostPerLifeAll'};
    
    % Process each scenario
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
        bc_ratio_10yr = benefit_diff_10yr / cost_diff_10yr;
        bc_ratio_30yr = benefit_diff_30yr / cost_diff_30yr;
        bc_ratio_all = benefit_diff / cost_diff;
        
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
    
    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'npv_summary.csv'));

    % Write LaTeX tables both with and without 10- and 30-year statistics
    write_advance_investment_table_latex(summary_table, ...
        fullfile(processed_dir, 'advance_investment_summary.tex'), ...
        'IncludeTenThirtyYearStats', true);

    write_advance_investment_table_latex(summary_table, ...
        fullfile(processed_dir, 'advance_investment_summary_no_10_30.tex'), ...
        'IncludeTenThirtyYearStats', false);
end

function write_advance_investment_table_latex(summary_data, outpath, varargin)
    % Write a LaTeX table summarizing scenario results, with optional inclusion of 10- and 30-year statistics.
    %
    % Args:
    %   summary_data (table): Table with scenario summary data.
    %   outpath (string): Output path for the LaTeX file.
    %   varargin: Optional name-value pairs:
    %       'IncludeTenThirtyYearStats' (logical, default: true): Whether to include 10- and 30-year columns.
    %
    % Example:
    %   write_advance_investment_table_latex(summary_data, 'out.tex', 'IncludeTenThirtyYearStats', false);

    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'IncludeTenThirtyYearStats', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    include_ten_thirty = p.Results.IncludeTenThirtyYearStats;

    % Convert to appropriate units
    summary_data.NPVDiff = summary_data.NPVDiff / 1e9; % Convert to billions
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9; % Convert to billions
    summary_data.CostDiff = summary_data.CostDiff / 1e9; % Convert to billions
    if include_ten_thirty
        summary_data.CostPerLife10yr = summary_data.CostPerLife10yr / 1e3; % Convert to thousands
        summary_data.CostPerLife30yr = summary_data.CostPerLife30yr / 1e3; % Convert to thousands
    end
    summary_data.CostPerLifeAll = summary_data.CostPerLifeAll / 1e3; % Convert to thousands

    % Round lives saved: to nearest hundred if < 1 million, else to nearest thousand, then format with commas
    round_lives = @(x) arrayfun(@(y) round(y, -2)*(y < 1e4) + round(y, -3)*(y >= 1e4), x);

    if include_ten_thirty
        summary_data.Lives10yr = comma_format(round_lives(summary_data.Lives10yr));
        summary_data.Lives30yr = comma_format(round_lives(summary_data.Lives30yr));
    end
    summary_data.LivesAll = comma_format(round_lives(summary_data.LivesAll));

    % Format benefit-cost ratios according to rules:
    % - Round to 0 decimals if >= 10
    % - Round to 1 decimal if < 10
    % - Convert to string vectors
    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));

    % Helper to replace negative BCRs with "Cost-saving"
    function s = bcr_to_string(x)
        s = round_nicely(x);
        s(x < 0) = "$\infty$"; % Uber hack. please fix
    end

    summary_data.NPVDiff = round_nicely(summary_data.NPVDiff);
    summary_data.BenefitDiff = round_nicely(summary_data.BenefitDiff);
    summary_data.CostDiff = round_nicely(summary_data.CostDiff);

    if include_ten_thirty
        summary_data.BCRatio10yr = bcr_to_string(summary_data.BCRatio10yr);
        summary_data.BCRatio30yr = bcr_to_string(summary_data.BCRatio30yr);
        summary_data.CostPerLife10yr = bcr_to_string(summary_data.CostPerLife10yr);
        summary_data.CostPerLife30yr = bcr_to_string(summary_data.CostPerLife30yr);
    end
    summary_data.BCRatioAll = bcr_to_string(summary_data.BCRatioAll);
    summary_data.CostPerLifeAll = bcr_to_string(summary_data.CostPerLifeAll);

    % Convert scenario names
    summary_data.Scenario = convert_varnames(summary_data.Scenario);
    summary_data.Scenario = replace(summary_data.Scenario, "&", "\&"); % Escape ampersands in scenario names for LaTeX

    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');

    % Write first table with costs and benefits
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated expected benefits, costs, net value, benefit-cost ratio and lives saved from advance investment programs.} ', ...
        'Monetary estimates are presented in discounted terms. ', ...
        'Values greater than 10 are rounded to the nearest integer; values less than 10 are rounded to one decimal place. Lives saved are rounded to the nearest hundred if less than 10{,}000, otherwise to the nearest thousand.}\n'
    ];
    fprintf(fileID, caption_str);
    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c}\n');
    else
        % Add a column for benefit-cost ratio
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c}\n');
    end
    fprintf(fileID, '\\noalign{\\vskip 3pt}');
    fprintf(fileID, '\\hline\n');
    if include_ten_thirty
        fprintf(fileID, 'Scenario & \\multicolumn{6}{c}{Difference from baseline vaccine program} \\\\\n');
        fprintf(fileID, '\\cline{2-7}\n');
        fprintf(fileID, '& Costs & Benefits & Net value & \\multicolumn{3}{c}{Lives saved after} \\\\\n');
        fprintf(fileID, '\\cline{5-7}\n');
        fprintf(fileID, '& \\$ billions & \\$ billions & \\$ billions & 10 years & 30 years & 50 years \\\\\n');
    else
        % Add a column for benefit-cost ratio
        fprintf(fileID, 'Scenario & Costs & Benefits & Net value & Benefit-cost ratio & Lives saved \\\\\n');
        fprintf(fileID, '& \\$ billions & \\$ billions & \\$ billions &  &  \\\\\n');
    end
    fprintf(fileID, '\\hline\n');

    % Write data rows for first table
    for i = 1:height(summary_data)
        if include_ten_thirty
            fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s \\\\\n', ...
                summary_data.Scenario{i}, ...
                summary_data.CostDiff(i), ...
                summary_data.BenefitDiff(i), ...
                summary_data.NPVDiff(i), ...
                summary_data.Lives10yr(i), ...
                summary_data.Lives30yr(i), ...
                summary_data.LivesAll(i));
        else
            % Add a column for benefit-cost ratio
            fprintf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
                summary_data.Scenario{i}, ...
                summary_data.CostDiff(i), ...
                summary_data.BenefitDiff(i), ...
                summary_data.NPVDiff(i), ...
                summary_data.BCRatioAll(i), ...
                summary_data.LivesAll(i));
        end
    end

    % Write first table footer
    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');

    % Write second table with cost-effectiveness metrics
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated cost-effectiveness for advance investment programs.} ', ...
        'Cost-effectiveness is calculated as discounted expected benefits divided by discounted expected costs. ', ...
        'Values greater than 10 are rounded to the nearest integer; values less than 10 are rounded to one decimal place. Lives saved are rounded to the nearest hundred if less than 10{,}000, otherwise to the nearest thousand.}\n'
    ];
    fprintf(fileID, caption_str);
    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular}{l c c c c c c}\n');
    else
        fprintf(fileID, '\\begin{tabular}{l c c}\n');
    end
    fprintf(fileID, '\\noalign{\\vskip 3pt}');
    fprintf(fileID, '\\hline\n');
    if include_ten_thirty
        fprintf(fileID, 'Scenario & \\multicolumn{3}{c}{Benefit-cost ratio} & \\multicolumn{3}{c}{\\$ thousands per expected life saved} \\\\\n');
        fprintf(fileID, '\\cline{2-4}\\cline{5-7}\n');
        fprintf(fileID, '& 10 years & 30 years & 50 years & 10 years & 30 years & 50 years \\\\\n');
    else
        fprintf(fileID, 'Scenario & Benefit-cost ratio & \\$ thousands per life saved \\\\\n');
    end
    fprintf(fileID, '\\hline\n');

    % Write data rows for second table
    for i = 1:height(summary_data)
        if include_ten_thirty
            fprintf(fileID, '%s & %s & %s & %s & %.0f & %.0f & %.0f \\\\\n', ...
                summary_data.Scenario{i}, ...
                summary_data.BCRatio10yr(i), ...
                summary_data.BCRatio30yr(i), ...
                summary_data.BCRatioAll(i), ...
                summary_data.CostPerLife10yr(i), ...
                summary_data.CostPerLife30yr(i), ...
                summary_data.CostPerLifeAll(i));
        else
            fprintf(fileID, '%s & %s & %.0f \\\\\n', ...
                summary_data.Scenario{i}, ...
                summary_data.BCRatioAll(i), ...
                summary_data.CostPerLifeAll(i));
        end
    end

    % Write second table footer
    fprintf(fileID, '\\hline\n\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:adv_invest_cost_effectiveness}\n');
    fprintf(fileID, '\\end{table}\n');

    % Close the file
    fclose(fileID);
end
