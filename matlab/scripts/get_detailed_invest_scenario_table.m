function get_detailed_invest_scenario_table(job_dir, recalculate_bc)

    % Process benefits and costs
    if recalculate_bc
        process_benefit_cost(job_dir, recalculate_bc);
    end

    % Load processed data
    processed_dir = fullfile(job_dir, "processed");
    
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
    
    % Bootstrap parameters
    n_bootstrap = 1000;
    alpha = 0.05; % For 95% CI
    
    % Initialize table with confidence intervals
    summary_table = table('Size', [length(scenarios) 27], ...
        'VariableTypes', {'string', 'string', 'string', ...
                         'double', 'double', 'double', ...  % BenefitDiff and CI
                         'double', 'double', 'double', ...  % CostDiff and CI
                         'double', ...                       % NPVDiff
                         'double', 'double', 'double', ...  % BCRatio10yr and CI
                         'double', 'double', 'double', ...  % BCRatio30yr and CI
                         'double', 'double', 'double', ...  % BCRatioAll and CI
                         'double', 'double', 'double', ...  % Lives10yr and CI
                         'double', 'double', 'double', ...  % Lives30yr and CI
                         'double', 'double', 'double'});    % LivesAll and CI
    summary_table.Properties.VariableNames = {...
        'Category', 'Accent', 'Variation', ...
        'BenefitDiff', 'BenefitDiff_CI_low', 'BenefitDiff_CI_high', ...
        'CostDiff', 'CostDiff_CI_low', 'CostDiff_CI_high', ...
        'NPVDiff', ...
        'BCRatio10yr', 'BCRatio10yr_CI_low', 'BCRatio10yr_CI_high', ...
        'BCRatio30yr', 'BCRatio30yr_CI_low', 'BCRatio30yr_CI_high', ...
        'BCRatioAll', 'BCRatioAll_CI_low', 'BCRatioAll_CI_high', ...
        'Lives10yr', 'Lives10yr_CI_low', 'Lives10yr_CI_high', ...
        'Lives30yr', 'Lives30yr_CI_low', 'Lives30yr_CI_high', ...
        'LivesAll', 'LivesAll_CI_low', 'LivesAll_CI_high'};
    
    % Process each scenario
    for i = 1:length(scenarios)
        scen_name = scenarios(i);

        [category_name, accent, variation] = parse_scenario_name(scen_name);
        
        % Load scenario relative sums data
        scen_file = fullfile(processed_dir, sprintf('%s_relative_sums.mat', scen_name));
        load(scen_file, 'relative_sums');
        
        % Extract data from relative_sums structure
        n_sims = size(relative_sums.npv_all, 1);
        
        % Get point estimates (means)
        benefit_diff = mean(relative_sums.benefits_all);
        cost_diff = mean(relative_sums.costs_all);
        npv_diff = mean(relative_sums.npv_all);
        
        bc_ratio_10yr = mean(relative_sums.bcr_10yr);
        bc_ratio_30yr = mean(relative_sums.bcr_30yr);
        bc_ratio_all = mean(relative_sums.bcr_all);
        
        lives_10yr = mean(relative_sums.lives_10yr);
        lives_30yr = mean(relative_sums.lives_30yr);
        lives_all = mean(relative_sums.lives_all);
        
        % Bootstrap confidence intervals
        bootstrap_indices = randi(n_sims, n_sims, n_bootstrap);
        
        % Bootstrap for benefits
        benefit_boot = mean(relative_sums.benefits_all(bootstrap_indices), 1);
        benefit_ci = prctile(benefit_boot, [alpha/2 * 100, (1-alpha/2) * 100]);
        
        % Bootstrap for costs
        cost_boot = mean(relative_sums.costs_all(bootstrap_indices), 1);
        cost_ci = prctile(cost_boot, [alpha/2 * 100, (1-alpha/2) * 100]);
        
        % Bootstrap for BCR 10yr
        bcr_10yr_boot = mean(relative_sums.bcr_10yr(bootstrap_indices), 1);
        bcr_10yr_ci = prctile(bcr_10yr_boot, [alpha/2 * 100, (1-alpha/2) * 100]);
        
        % Bootstrap for BCR 30yr
        bcr_30yr_boot = mean(relative_sums.bcr_30yr(bootstrap_indices), 1);
        bcr_30yr_ci = prctile(bcr_30yr_boot, [alpha/2 * 100, (1-alpha/2) * 100]);
        
        % Bootstrap for BCR all
        bcr_all_boot = mean(relative_sums.bcr_all(bootstrap_indices), 1);
        bcr_all_ci = prctile(bcr_all_boot, [alpha/2 * 100, (1-alpha/2) * 100]);
        
        % Bootstrap for lives 10yr
        lives_10yr_boot = mean(relative_sums.lives_10yr(bootstrap_indices), 1);
        lives_10yr_ci = prctile(lives_10yr_boot, [alpha/2 * 100, (1-alpha/2) * 100]);
        
        % Bootstrap for lives 30yr
        lives_30yr_boot = mean(relative_sums.lives_30yr(bootstrap_indices), 1);
        lives_30yr_ci = prctile(lives_30yr_boot, [alpha/2 * 100, (1-alpha/2) * 100]);
        
        % Bootstrap for lives all
        lives_all_boot = mean(relative_sums.lives_all(bootstrap_indices), 1);
        lives_all_ci = prctile(lives_all_boot, [alpha/2 * 100, (1-alpha/2) * 100]);
        
        % Add to table
        summary_table(i,:) = {category_name, accent, variation, ...
                             benefit_diff, benefit_ci(1), benefit_ci(2), ...
                             cost_diff, cost_ci(1), cost_ci(2), ...
                             npv_diff, ...
                             bc_ratio_10yr, bcr_10yr_ci(1), bcr_10yr_ci(2), ...
                             bc_ratio_30yr, bcr_30yr_ci(1), bcr_30yr_ci(2), ...
                             bc_ratio_all, bcr_all_ci(1), bcr_all_ci(2), ...
                             lives_10yr, lives_10yr_ci(1), lives_10yr_ci(2), ...
                             lives_30yr, lives_30yr_ci(1), lives_30yr_ci(2), ...
                             lives_all, lives_all_ci(1), lives_all_ci(2)};
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

    % Convert to appropriate units (billions for monetary, thousands for lives)
    summary_data.NPVDiff = summary_data.NPVDiff / 1e9;
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9;
    summary_data.BenefitDiff_CI_low = summary_data.BenefitDiff_CI_low / 1e9;
    summary_data.BenefitDiff_CI_high = summary_data.BenefitDiff_CI_high / 1e9;
    summary_data.CostDiff = summary_data.CostDiff / 1e9;
    summary_data.CostDiff_CI_low = summary_data.CostDiff_CI_low / 1e9;
    summary_data.CostDiff_CI_high = summary_data.CostDiff_CI_high / 1e9;

    % Helper function to format value with CI
    function s = format_with_ci(val, ci_low, ci_high)
        round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));
        s = sprintf('%s (%s, %s)', round_nicely(val), round_nicely(ci_low), round_nicely(ci_high));
    end
    
    % Helper function to format lives with CI
    function s = format_lives_with_ci(val, ci_low, ci_high)
        round_lives = @(x) round(x, -2) * (x < 1e4) + round(x, -3) * (x >= 1e4);
        s = sprintf('%s (%s, %s)', comma_format(round_lives(val)), ...
                    comma_format(round_lives(ci_low)), comma_format(round_lives(ci_high)));
    end
    
    % Helper function to format BCR with CI
    function s = format_bcr_with_ci(val, ci_low, ci_high, less_than_zero_to_inf)
        round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));
        if (less_than_zero_to_inf && val < 0) || isinf(val)
            s = "$\infty$";
        else
            val_str = round_nicely(val);
            low_str = round_nicely(ci_low);
            high_str = round_nicely(ci_high);
            if (less_than_zero_to_inf && ci_high < 0) || isinf(ci_high)
                high_str = "$\infty$";
            end
            s = sprintf('%s (%s, %s)', val_str, low_str, high_str);
        end
    end

    % Format all values with CIs
    benefit_str = arrayfun(@(i) format_with_ci(summary_data.BenefitDiff(i), ...
        summary_data.BenefitDiff_CI_low(i), summary_data.BenefitDiff_CI_high(i)), ...
        (1:height(summary_data))', 'UniformOutput', false);
    
    cost_str = arrayfun(@(i) format_with_ci(summary_data.CostDiff(i), ...
        summary_data.CostDiff_CI_low(i), summary_data.CostDiff_CI_high(i)), ...
        (1:height(summary_data))', 'UniformOutput', false);
    
    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));
    npv_str = round_nicely(summary_data.NPVDiff);
    
    if include_ten_thirty
        lives_10yr_str = arrayfun(@(i) format_lives_with_ci(summary_data.Lives10yr(i), ...
            summary_data.Lives10yr_CI_low(i), summary_data.Lives10yr_CI_high(i)), ...
            (1:height(summary_data))', 'UniformOutput', false);
        
        lives_30yr_str = arrayfun(@(i) format_lives_with_ci(summary_data.Lives30yr(i), ...
            summary_data.Lives30yr_CI_low(i), summary_data.Lives30yr_CI_high(i)), ...
            (1:height(summary_data))', 'UniformOutput', false);
        
        bcr_10yr_str = arrayfun(@(i) format_bcr_with_ci(summary_data.BCRatio10yr(i), ...
            summary_data.BCRatio10yr_CI_low(i), summary_data.BCRatio10yr_CI_high(i), true), ...
            (1:height(summary_data))', 'UniformOutput', false);
        
        bcr_30yr_str = arrayfun(@(i) format_bcr_with_ci(summary_data.BCRatio30yr(i), ...
            summary_data.BCRatio30yr_CI_low(i), summary_data.BCRatio30yr_CI_high(i), true), ...
            (1:height(summary_data))', 'UniformOutput', false);
    end
    
    lives_all_str = arrayfun(@(i) format_lives_with_ci(summary_data.LivesAll(i), ...
        summary_data.LivesAll_CI_low(i), summary_data.LivesAll_CI_high(i)), ...
        (1:height(summary_data))', 'UniformOutput', false);
    
    bcr_all_str = arrayfun(@(i) format_bcr_with_ci(summary_data.BCRatioAll(i), ...
        summary_data.BCRatioAll_CI_low(i), summary_data.BCRatioAll_CI_high(i), true), ...
        (1:height(summary_data))', 'UniformOutput', false);

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
        '\\caption{\\textbf{Estimated expected benefits, costs, net value, and lives saved from advance investment programs.} ', ...
        'Monetary estimates are discounted. Values shown as point estimate (95\\%% CI). ', ...
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
        fprintf(fileID, '& & & & & 10 yr & 30 yr & 50 yr \\\\\n');
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
                    cost_str{i}, ...
                    benefit_str{i}, ...
                    npv_str(i), ...
                    lives_10yr_str{i}, ...
                    lives_30yr_str{i}, ...
                    lives_all_str{i});
            else
                fprintf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
                    summary_data.Category{i}, ...
                    summary_data.Accent{i}, ...
                    cost_str{i}, ...
                    benefit_str{i}, ...
                    npv_str(i), ...
                    lives_all_str{i});
            end
        end
    end
    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');

    % Table 2: Cost-effectiveness grouped, same display style
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated cost-effectiveness for advance investment programs.} ', ...
        'Ratios: discounted benefits/costs. Values shown as point estimate (95\\%% CI). ', ...
        'Values $>\\!$10 integer; $<\\!$10 one decimal. Lives saved rounded as above. ', ...
        'Scenario rows group program variants. }\n'
    ]; fprintf(fileID, caption_str);

    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c}\n');
    else
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c}\n');
    end

    fprintf(fileID, '\\hline\n');
    if include_ten_thirty
        fprintf(fileID, ...
            'Scenario & Accent & \\multicolumn{3}{c}{Benefit-cost ratio} \\\\\n');
        fprintf(fileID, '\\cline{3-5}\n');
        fprintf(fileID, '& & 10 yr & 30 yr & 50 yr \\\\\n');
    else
        fprintf(fileID, ...
            'Scenario & Accent & BCR \\\\\n');
    end
    fprintf(fileID, '\\hline\n');

    for c = 1:numel(unique_cats)
        idx = find(cat_idx == c);
        for ii = 1:numel(idx)
            i = idx(ii);
            if include_ten_thirty
                fprintf(fileID, '%s & %s & %s & %s & %s \\\\\n', ...
                    summary_data.Category{i}, ...
                    summary_data.Accent{i}, ...
                    bcr_10yr_str{i}, ...
                    bcr_30yr_str{i}, ...
                    bcr_all_str{i});
            else
                fprintf(fileID, '%s & %s & %s \\\\\n', ...
                    summary_data.Category{i}, ...
                    summary_data.Accent{i}, ...
                    bcr_all_str{i});
            end
        end
    end

    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_cost_effectiveness}\n');
    fprintf(fileID, '\\end{table}\n');

    fclose(fileID);
end
