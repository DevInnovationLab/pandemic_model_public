function get_detailed_invest_scenario_table(job_dir, recalculate_bc)

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
    summary_table = table('Size', [length(scenarios) 15], ...
        'VariableTypes', {'string', 'string', 'string', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Category', 'Accent', 'Variation', 'BenefitDiff', 'CostDiff', 'NPVDiff',  ...
        'BCRatio10yr', 'BCRatio30yr', 'BCRatioAll', 'Lives10yr', 'Lives30yr', ...
        'LivesAll', 'CostPerLife10yr', 'CostPerLife30yr', 'CostPerLifeAll'};
    
        % Process each scenario
    for i = 1:length(scenarios)
        scen_name = scenarios(i);

        [category_name, accent, variation] = parse_scenario_name(scen_name);
        
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
        summary_table(i,:) = {category_name, accent, variation, benefit_diff, cost_diff, npv_diff, ...
                             bc_ratio_10yr, bc_ratio_30yr, bc_ratio_all, lives_10yr, lives_30yr, ...
                             lives_all, cost_per_life_10yr, cost_per_life_30yr, cost_per_life_all};

        % % Convert any Inf values to NaN in the summary table
        % summary_table.CostPerLife10yr(isinf(summary_table.CostPerLife10yr)) = NaN;
        % summary_table.CostPerLife30yr(isinf(summary_table.CostPerLife30yr)) = NaN;
        % summary_table.CostPerLifeAll(isinf(summary_table.CostPerLifeAll)) = NaN;
    end

    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'npv_summary_detailed.csv'));

    % Write LaTeX tables both with and without 10- and 30-year statistics
    write_advance_investment_table_latex(summary_table, ...
        fullfile(processed_dir, 'advance_investment_summary.tex'), ...
        'IncludeTenThirtyYearStats', true);

    write_advance_investment_table_latex(summary_table, ...
        fullfile(processed_dir, 'advance_investment_summary_no_10_30.tex'), ...
        'IncludeTenThirtyYearStats', false);
end

function [category_name, accent, variation]  = parse_scenario_name(scenario_name)

    disp(scenario_name);
    if startsWith(scenario_name, "combined_invest")
        category_name = "Combined";
        if contains(scenario_name, "bcr_acc")
            accent = "BCR";
            variation = "";
        elseif contains(scenario_name, "surplus_acc")
            accent = "Surplus";
            variation = "";
        end
    elseif startsWith(scenario_name, "advance_capacity")
        category_name = "Advance capacity";
        if contains(scenario_name, "9_month")
            accent = "BCR";
            variation = "Vaccinate within 9 months";
        elseif contains(scenario_name, "6_month")
            accent = "Surplus";
            variation = "Vaccinate within 6 months";
        end
    elseif startsWith(scenario_name, "universal_flu_rd")
        category_name = "Universal flu vaccine R&D";
        if contains(scenario_name, "single")
            accent = "BCR";
            variation = "Single platform response R&D";
        elseif contains(scenario_name, "both")
            accent = "Surplus";
            variation = "Both platform response R&D";
        end
    elseif startsWith(scenario_name, "neglected_pathogen_rd")
        category_name = "Neglected pathogen R&D";
        if contains(scenario_name, "single")
            accent = "BCR";
            variation = "Prototype R&D for highest risk neglected pathogen";
        elseif contains(scenario_name, "all")
            accent = "Surplus";
            variation = "Prototype R&D for three neglected pathogens";
        end
    elseif startsWith(scenario_name, "improved_early_warning")
        category_name = "Improved early warning";
        if contains(scenario_name, "high_threshold")
            accent = "BCR";
            variation = "Higher warning threshold";
        elseif contains(scenario_name, "low_threshold")
            accent = "Surplus";
            variation = "Lower warning threshold";
        end
    end

end

function write_advance_investment_table_latex(summary_data, outpath, varargin)
    % Write a LaTeX table summarizing scenario results, grouping accents under scenario lines.
    %
    % Args:
    %   summary_data (table): Table with scenario summary data, including 'Category', 'Accent', and 'Variation'.
    %   outpath (string): Output path for the LaTeX file.
    %   varargin: Optional name-value pairs.
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
    summary_data.NPVDiff = summary_data.NPVDiff / 1e9; % to billions
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9;
    summary_data.CostDiff = summary_data.CostDiff / 1e9;
    if include_ten_thirty
        summary_data.CostPerLife10yr = summary_data.CostPerLife10yr / 1e3; % to thousands
        summary_data.CostPerLife30yr = summary_data.CostPerLife30yr / 1e3;
    end
    summary_data.CostPerLifeAll = summary_data.CostPerLifeAll / 1e3;

    % Round lives saved
    round_lives = @(x) arrayfun(@(y) round(y, -2) * (y < 1e4) + round(y, -3) * (y >= 1e4), x);

    if include_ten_thirty
        summary_data.Lives10yr = comma_format(round_lives(summary_data.Lives10yr));
        summary_data.Lives30yr = comma_format(round_lives(summary_data.Lives30yr));
    end
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

    if include_ten_thirty
        summary_data.BCRatio10yr = bcr_to_string(summary_data.BCRatio10yr, true);
        summary_data.BCRatio30yr = bcr_to_string(summary_data.BCRatio30yr, true);
        summary_data.CostPerLife10yr = bcr_to_string(summary_data.CostPerLife10yr, false);
        summary_data.CostPerLife30yr = bcr_to_string(summary_data.CostPerLife30yr, false);
    end
    summary_data.BCRatioAll = bcr_to_string(summary_data.BCRatioAll, true);
    summary_data.CostPerLifeAll = bcr_to_string(summary_data.CostPerLifeAll, false);

    % Escape LaTeX special chars & in names
    summary_data.Category = replace(string(summary_data.Category), "&", "\&");
    summary_data.Accent = replace(string(summary_data.Accent), "&", "\&");
    summary_data.Variation = replace(string(summary_data.Variation), "&", "\&");

    % Group programs so only unique Category rows start scenario, others indented
    [unique_cats,~,cat_idx] = unique(summary_data.Category, 'stable');


    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');

    % Table 1: Effects summary (costs, benefits, net, lives)
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated expected benefits, costs, net value, and lives saved from advance investment programs.} Monetary estimates are discounted. ', ...
        'Values $>\\!$10 rounded to integer; $<\\!$10 share $1$ decimal. Lives saved rounded to the nearest hundred if $<10{,}000$, else thousand. ', ...
        'Scenario rows group alternative program designs. }\n'
    ]; fprintf(fileID, caption_str);

    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c c}\n');
    else
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c}\n');
    end

    fprintf(fileID, '\\hline\n');
    if include_ten_thirty
        fprintf(fileID, ...
            'Scenario & Accent & Costs (\\$~bn) & Benefits (\\$~bn) & Net value (\\$~bn) & \\multicolumn{3}{c}{Lives saved} \\\\\n');
        fprintf(fileID, '\\cline{6-8}\n');
        fprintf(fileID, '& & & & & & 10 yr & 30 yr & 50 yr \\\\\n');
    else
        fprintf(fileID, ...
            'Scenario & Accent & Costs (\\$~bn) & Benefits (\\$~bn) & Net value (\\$~bn) & Lives saved \\\\\n');
    end
    fprintf(fileID, '\\hline\n');

    % Print data in grouped scenario style
    for c = 1:numel(unique_cats)
        idx = find(cat_idx == c);
        for ii = 1:numel(idx)
            i = idx(ii);
            if include_ten_thirty
                fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s & %s \\\\\n', ...
                    summary_data.Category{i}, ...
                    summary_data.Accent{i}, ...
                    summary_data.CostDiff(i), ...
                    summary_data.BenefitDiff(i), ...
                    summary_data.NPVDiff(i), ...
                    summary_data.Lives10yr(i), ...
                    summary_data.Lives30yr(i), ...
                    summary_data.LivesAll(i));
            else
                fprintf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
                    summary_data.Category{i}, ...
                    summary_data.Accent{i}, ...
                    summary_data.CostDiff(i), ...
                    summary_data.BenefitDiff(i), ...
                    summary_data.NPVDiff(i), ...
                    summary_data.LivesAll(i));
            end
        end
    end
    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');

    % Table 2: Cost-effectiveness grouped, same display style
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated cost-effectiveness for advance investment programs.} Ratios: discounted benefits/costs. ', ...
        'Values $>\\!$10 integer; $<\\!$10 one decimal. Lives saved rounded as above. ', ...
        'Scenario rows group program variants. }\n'
    ]; fprintf(fileID, caption_str);

    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c c}\n');
    else
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c}\n');
    end

    fprintf(fileID, '\\hline\n');
    if include_ten_thirty
        fprintf(fileID, ...
            'Scenario & Accent & \\multicolumn{3}{c}{Benefit-cost ratio} & \\multicolumn{3}{c}{\\$k per expected life saved} \\\\\n');
        fprintf(fileID, '\\cline{3-5}\\cline{6-8}\n');
        fprintf(fileID, '& & & 10 yr & 30 yr & 50 yr & 10 yr & 30 yr & 50 yr \\\\\n');
    else
        fprintf(fileID, ...
            'Scenario & Accent & BCR & \\$k per life saved \\\\\n');
    end
    fprintf(fileID, '\\hline\n');

    for c = 1:numel(unique_cats)
        idx = find(cat_idx == c);
        for ii = 1:numel(idx)
            i = idx(ii);
            if include_ten_thirty
                fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s & %s \\\\\n', ...
                    summary_data.Category{i}, ...
                    summary_data.Accent{i}, ...
                    summary_data.BCRatio10yr(i), ...
                    summary_data.BCRatio30yr(i), ...
                    summary_data.BCRatioAll(i), ...
                    summary_data.CostPerLife10yr(i), ...
                    summary_data.CostPerLife30yr(i), ...
                    summary_data.CostPerLifeAll(i));
            else
                fprintf(fileID, '%s & %s & %s & %s \\\\\n', ...
                    summary_data.Category{i}, ...
                    summary_data.Accent{i}, ...
                    summary_data.BCRatioAll(i), ...
                    summary_data.CostPerLifeAll(i));
            end
        end
    end

    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_cost_effectiveness}\n');
    fprintf(fileID, '\\end{table}\n');

    fclose(fileID);
end

