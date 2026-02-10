function get_detailed_invest_scenario_table(job_dir, varargin)
    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'recompute_ci', false, @islogical);
    parse(p, varargin{:});
    recompute_ci = p.Results.recompute_ci;

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
    
    fprintf('Processing %d scenarios\n', length(scenarios));
    
    % Check if CI file exists
    ci_file = fullfile(processed_dir, 'detailed_invest_confidence_intervals.mat');
    ci_exists = exist(ci_file, 'file');
    
    if ~recompute_ci && ci_exists
        fprintf('Loading existing confidence intervals from %s\n', ci_file);
        ci_data = load(ci_file);
        ci_table = ci_data.ci_table;
        
        % Verify that all scenarios are present
        if all(ismember(scenarios, ci_table.Scenario))
            fprintf('All scenarios found in saved CI data\n');
            use_saved_ci = true;
        else
            fprintf('Some scenarios missing from saved CI data, recomputing...\n');
            use_saved_ci = false;
        end
    else
        if recompute_ci
            fprintf('Recomputing confidence intervals as requested\n');
        else
            fprintf('No saved confidence intervals found, computing...\n');
        end
        use_saved_ci = false;
    end
    
    % Initialize table with confidence intervals
    summary_table = table('Size', [length(scenarios) 37], ...
        'VariableTypes', {'string', 'string', 'string', ...
                         'double', 'double', 'double', ...  % BenefitDiff and CI
                         'double', 'double', 'double', ...  % CostDiff and CI
                         'double', ...                       % NPVDiff
                         'double', 'double', 'double', ...  % BCRatio10yr and CI
                         'double', 'double', 'double', ...  % BCRatio30yr and CI
                         'double', 'double', 'double', ...  % BCRatioAll and CI
                         'double', 'double', 'double', ...  % Lives10yr and CI
                         'double', 'double', 'double', ...  % Lives30yr and CI
                         'double', 'double', 'double', ...  % LivesAll and CI
                         'double', 'double', 'double', ...  % CostPerLife10yr and CI
                         'double', 'double', 'double', ...  % CostPerLife30yr and CI
                         'double', 'double', 'double'}, ...  % CostPerLifeAll and CI
        'VariableNames', {...
        'Category', 'Accent', 'Variation', ...
        'BenefitDiff', 'BenefitDiff_CI_low', 'BenefitDiff_CI_high', ...
        'CostDiff', 'CostDiff_CI_low', 'CostDiff_CI_high', ...
        'NPVDiff', ...
        'BCRatio10yr', 'BCRatio10yr_CI_low', 'BCRatio10yr_CI_high', ...
        'BCRatio30yr', 'BCRatio30yr_CI_low', 'BCRatio30yr_CI_high', ...
        'BCRatioAll', 'BCRatioAll_CI_low', 'BCRatioAll_CI_high', ...
        'Lives10yr', 'Lives10yr_CI_low', 'Lives10yr_CI_high', ...
        'Lives30yr', 'Lives30yr_CI_low', 'Lives30yr_CI_high', ...
        'LivesAll', 'LivesAll_CI_low', 'LivesAll_CI_high', ...
        'CostPerLife10yr', 'CostPerLife10yr_CI_low', 'CostPerLife10yr_CI_high', ...
        'CostPerLife30yr', 'CostPerLife30yr_CI_low', 'CostPerLife30yr_CI_high', ...
        'CostPerLifeAll', 'CostPerLifeAll_CI_low', 'CostPerLifeAll_CI_high'});
    
    % Initialize CI table if computing
    if ~use_saved_ci
        ci_table = table('Size', [length(scenarios) 23], ...
            'VariableTypes', {'string', ...
                             'double', 'double', ...  % BenefitDiff CI
                             'double', 'double', ...  % CostDiff CI
                             'double', 'double', ...  % BCRatio10yr CI
                             'double', 'double', ...  % BCRatio30yr CI
                             'double', 'double', ...  % BCRatioAll CI
                             'double', 'double', ...  % Lives10yr CI
                             'double', 'double', ...  % Lives30yr CI
                             'double', 'double', ...  % LivesAll CI
                             'double', 'double', ...  % CostPerLife10yr CI
                             'double', 'double', ...  % CostPerLife30yr CI
                             'double', 'double'}, ...  % CostPerLifeAll CI
            'VariableNames', {...
            'Scenario', ...
            'BenefitDiff_CI_low', 'BenefitDiff_CI_high', ...
            'CostDiff_CI_low', 'CostDiff_CI_high', ...
            'BCRatio10yr_CI_low', 'BCRatio10yr_CI_high', ...
            'BCRatio30yr_CI_low', 'BCRatio30yr_CI_high', ...
            'BCRatioAll_CI_low', 'BCRatioAll_CI_high', ...
            'Lives10yr_CI_low', 'Lives10yr_CI_high', ...
            'Lives30yr_CI_low', 'Lives30yr_CI_high', ...
            'LivesAll_CI_low', 'LivesAll_CI_high', ...
            'CostPerLife10yr_CI_low', 'CostPerLife10yr_CI_high', ...
            'CostPerLife30yr_CI_low', 'CostPerLife30yr_CI_high', ...
            'CostPerLifeAll_CI_low', 'CostPerLifeAll_CI_high'});
    end
    
    % Process each scenario
    for i = 1:length(scenarios)
        scen_name = scenarios(i);
        fprintf('Processing scenario %d/%d: %s\n', i, length(scenarios), scen_name);

        [category_name, accent, variation] = parse_scenario_name(scen_name);
        
        % Load scenario relative sums data
        scen_file = fullfile(processed_dir, sprintf('%s_relative_sums.mat', scen_name));
        fprintf('  Loading file: %s\n', scen_file);
        tic;
        load(scen_file, 'all_relative_sums');
        relative_sums = all_relative_sums;
        fprintf('  Loaded in %.2f seconds\n', toc);
        
        % Get point estimates (means)
        fprintf('  Computing means...\n');
        tic;
        benefit_diff = mean(relative_sums.tot_benefits_pv_full);
        cost_diff = mean(relative_sums.costs_adv_invest_pv_full);
        npv_diff = benefit_diff - cost_diff;
        
        % Calculate BCRs from benefits and costs, treating 0/0 as 0
        benefits_10yr = mean(relative_sums.tot_benefits_pv_10_years);
        costs_10yr = mean(relative_sums.costs_adv_invest_pv_10_years);
        if abs(costs_10yr) < 1e-7 && abs(benefits_10yr) < 1e-7
            bc_ratio_10yr = 0;
        else
            bc_ratio_10yr = benefits_10yr / costs_10yr;
        end
        
        benefits_30yr = mean(relative_sums.tot_benefits_pv_30_years);
        costs_30yr = mean(relative_sums.costs_adv_invest_pv_30_years);
        if abs(costs_30yr) < 1e-7  && abs(benefits_30yr) < 1e-7
            bc_ratio_30yr = 0;
        else
            bc_ratio_30yr = benefits_30yr / costs_30yr;
        end
        
        if abs(cost_diff) < 1e-7  && abs(benefit_diff) < 1e-7
            bc_ratio_all = 0;
        else
            bc_ratio_all = benefit_diff / cost_diff;
        end
        
        lives_10yr = mean(relative_sums.lives_saved_10_years);
        lives_30yr = mean(relative_sums.lives_saved_30_years);
        lives_all = mean(relative_sums.lives_saved_full);
        
        % Calculate cost per life saved
        cost_per_life_10yr = costs_10yr / lives_10yr;
        cost_per_life_30yr = costs_30yr / lives_30yr;
        cost_per_life_all = cost_diff / lives_all;
        
        fprintf('  Means computed in %.2f seconds\n', toc);
        
        % Get or compute confidence intervals
        if use_saved_ci
            % Look up CI from saved data
            ci_row = ci_table(ci_table.Scenario == scen_name, :);
            benefit_ci = [ci_row.BenefitDiff_CI_low; ci_row.BenefitDiff_CI_high];
            cost_ci = [ci_row.CostDiff_CI_low; ci_row.CostDiff_CI_high];
            bcr_10yr_ci = [ci_row.BCRatio10yr_CI_low; ci_row.BCRatio10yr_CI_high];
            bcr_30yr_ci = [ci_row.BCRatio30yr_CI_low; ci_row.BCRatio30yr_CI_high];
            bcr_all_ci = [ci_row.BCRatioAll_CI_low; ci_row.BCRatioAll_CI_high];
            lives_10yr_ci = [ci_row.Lives10yr_CI_low; ci_row.Lives10yr_CI_high];
            lives_30yr_ci = [ci_row.Lives30yr_CI_low; ci_row.Lives30yr_CI_high];
            lives_all_ci = [ci_row.LivesAll_CI_low; ci_row.LivesAll_CI_high];
            cost_per_life_10yr_ci = [ci_row.CostPerLife10yr_CI_low; ci_row.CostPerLife10yr_CI_high];
            cost_per_life_30yr_ci = [ci_row.CostPerLife30yr_CI_low; ci_row.CostPerLife30yr_CI_high];
            cost_per_life_all_ci = [ci_row.CostPerLifeAll_CI_low; ci_row.CostPerLifeAll_CI_high];
            fprintf('  Using saved confidence intervals\n');
        else
            % Compute 90% confidence intervals using bootstrap
            fprintf('  Computing benefit CI...\n');
            tic;
            benefit_ci = bootci(200, {@mean, relative_sums.tot_benefits_pv_full}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  Benefit CI computed in %.2f seconds\n', toc);

            fprintf('  Computing cost CI...\n');
            tic;
            cost_ci = bootci(200, {@mean, relative_sums.costs_adv_invest_pv_full}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  Cost CI computed in %.2f seconds\n', toc);

            % For all "ratio" stats, follow proper rules of expectation:
            % Compute bootstrap CIs for mean(b ./ c), not mean(b)/mean(c)

            fprintf('  Computing BCR 10yr CI...\n');
            tic;
            bcr_10yr_ci = bootci(200, {@(b,c) mean(b ./ c), relative_sums.tot_benefits_pv_10_years, relative_sums.costs_adv_invest_pv_10_years}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  BCR 10yr CI computed in %.2f seconds\n', toc);

            fprintf('  Computing BCR 30yr CI...\n');
            tic;
            bcr_30yr_ci = bootci(200, {@(b,c) mean(b ./ c), relative_sums.tot_benefits_pv_30_years, relative_sums.costs_adv_invest_pv_30_years}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  BCR 30yr CI computed in %.2f seconds\n', toc);

            fprintf('  Computing BCR all CI...\n');
            tic;
            bcr_all_ci = bootci(200, {@(b,c) mean(b ./ c), relative_sums.tot_benefits_pv_full, relative_sums.costs_adv_invest_pv_full}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  BCR all CI computed in %.2f seconds\n', toc);

            % For "Lives Saved" stats, we want CI for mean(l), just like before
            fprintf('  Computing lives 10yr CI...\n');
            tic;
            lives_10yr_ci = bootci(200, {@mean, relative_sums.lives_saved_10_years}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  Lives 10yr CI computed in %.2f seconds\n', toc);

            fprintf('  Computing lives 30yr CI...\n');
            tic;
            lives_30yr_ci = bootci(200, {@mean, relative_sums.lives_saved_30_years}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  Lives 30yr CI computed in %.2f seconds\n', toc);

            fprintf('  Computing lives all CI...\n');
            tic;
            lives_all_ci = bootci(200, {@mean, relative_sums.lives_saved_full}, 'alpha', 0.1, 'type', 'percentile');
            fprintf('  Lives all CI computed in %.2f seconds\n', toc);

            % Cost per life: compute CI for mean(cost./lives)
            fprintf('  Computing cost per life 10yr CI...\n');
            tic;
            try
                cost_per_life_10yr_ci = bootci(200, {@(c,l) mean(c ./ l), relative_sums.costs_adv_invest_pv_10_years, relative_sums.lives_saved_10_years}, 'alpha', 0.1, 'type', 'percentile');
            catch
                warning('bootci failed for cost_per_life_10yr_ci, setting to [Inf, Inf]');
                cost_per_life_10yr_ci = [Inf, Inf];
            end
            fprintf('  Cost per life 10yr CI computed in %.2f seconds\n', toc);

            fprintf('  Computing cost per life 30yr CI...\n');
            tic;
            try
                cost_per_life_30yr_ci = bootci(200, {@(c,l) mean(c ./ l), relative_sums.costs_adv_invest_pv_30_years, relative_sums.lives_saved_30_years}, 'alpha', 0.1, 'type', 'percentile');
            catch
                warning('bootci failed for cost_per_life_30yr_ci, setting to [Inf, Inf]');
                cost_per_life_30yr_ci = [Inf, Inf];
            end
            fprintf('  Cost per life 30yr CI computed in %.2f seconds\n', toc);

            fprintf('  Computing cost per life all CI...\n');
            tic;
            try
                cost_per_life_all_ci = bootci(200, {@(c,l) mean(c ./ l), relative_sums.costs_adv_invest_pv_full, relative_sums.lives_saved_full}, 'alpha', 0.1, 'type', 'percentile');
            catch
                warning('bootci failed for cost_per_life_all_ci, setting to [Inf, Inf]');
                cost_per_life_all_ci = [Inf, Inf];
            end
            fprintf('  Cost per life all CI computed in %.2f seconds\n', toc);
                        
            % Save to CI table
            ci_table(i, :) = {scen_name, ...
                             benefit_ci(1), benefit_ci(2), ...
                             cost_ci(1), cost_ci(2), ...
                             bcr_10yr_ci(1), bcr_10yr_ci(2), ...
                             bcr_30yr_ci(1), bcr_30yr_ci(2), ...
                             bcr_all_ci(1), bcr_all_ci(2), ...
                             lives_10yr_ci(1), lives_10yr_ci(2), ...
                             lives_30yr_ci(1), lives_30yr_ci(2), ...
                             lives_all_ci(1), lives_all_ci(2), ...
                             cost_per_life_10yr_ci(1), cost_per_life_10yr_ci(2), ...
                             cost_per_life_30yr_ci(1), cost_per_life_30yr_ci(2), ...
                             cost_per_life_all_ci(1), cost_per_life_all_ci(2)};
        end
        
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
                             lives_all, lives_all_ci(1), lives_all_ci(2), ...
                             cost_per_life_10yr, cost_per_life_10yr_ci(1), cost_per_life_10yr_ci(2), ...
                             cost_per_life_30yr, cost_per_life_30yr_ci(1), cost_per_life_30yr_ci(2), ...
                             cost_per_life_all, cost_per_life_all_ci(1), cost_per_life_all_ci(2)};
        fprintf('  Scenario %s complete\n\n', scen_name);
    end
    
    % Save CI table if we computed it
    if ~use_saved_ci
        fprintf('Saving confidence intervals to %s\n', ci_file);
        save(ci_file, 'ci_table');
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

    % Convert to appropriate units (billions for monetary, thousands for lives and cost per life)
    summary_data.NPVDiff = summary_data.NPVDiff / 1e9;
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9;
    summary_data.BenefitDiff_CI_low = summary_data.BenefitDiff_CI_low / 1e9;
    summary_data.BenefitDiff_CI_high = summary_data.BenefitDiff_CI_high / 1e9;
    summary_data.CostDiff = summary_data.CostDiff / 1e9;
    summary_data.CostDiff_CI_low = summary_data.CostDiff_CI_low / 1e9;
    summary_data.CostDiff_CI_high = summary_data.CostDiff_CI_high / 1e9;
    
    % Convert lives to thousands
    summary_data.Lives10yr = summary_data.Lives10yr / 1e3;
    summary_data.Lives10yr_CI_low = summary_data.Lives10yr_CI_low / 1e3;
    summary_data.Lives10yr_CI_high = summary_data.Lives10yr_CI_high / 1e3;
    summary_data.Lives30yr = summary_data.Lives30yr / 1e3;
    summary_data.Lives30yr_CI_low = summary_data.Lives30yr_CI_low / 1e3;
    summary_data.Lives30yr_CI_high = summary_data.Lives30yr_CI_high / 1e3;
    summary_data.LivesAll = summary_data.LivesAll / 1e3;
    summary_data.LivesAll_CI_low = summary_data.LivesAll_CI_low / 1e3;
    summary_data.LivesAll_CI_high = summary_data.LivesAll_CI_high / 1e3;
    
    % Convert cost per life to thousands
    summary_data.CostPerLife10yr = summary_data.CostPerLife10yr / 1e3;
    summary_data.CostPerLife10yr_CI_low = summary_data.CostPerLife10yr_CI_low / 1e3;
    summary_data.CostPerLife10yr_CI_high = summary_data.CostPerLife10yr_CI_high / 1e3;
    summary_data.CostPerLife30yr = summary_data.CostPerLife30yr / 1e3;
    summary_data.CostPerLife30yr_CI_low = summary_data.CostPerLife30yr_CI_low / 1e3;
    summary_data.CostPerLife30yr_CI_high = summary_data.CostPerLife30yr_CI_high / 1e3;
    summary_data.CostPerLifeAll = summary_data.CostPerLifeAll / 1e3;
    summary_data.CostPerLifeAll_CI_low = summary_data.CostPerLifeAll_CI_low / 1e3;
    summary_data.CostPerLifeAll_CI_high = summary_data.CostPerLifeAll_CI_high / 1e3;

    % Helper function to round nicely
    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));
    
    % Helper function to format value with CI using nested tabular
    function s = format_with_ci(val, ci_low, ci_high)
        s = sprintf('\\begin{tabular}[c]{@{}c@{}}%s \\\\[-0.7em] \\footnotesize [%s, %s]\\end{tabular}', ...
                    round_nicely(val), round_nicely(ci_low), round_nicely(ci_high));
    end
    
    % Helper function to format lives with CI using nested tabular (now in thousands)
    function s = format_lives_with_ci(val, ci_low, ci_high)
        s = sprintf('\\begin{tabular}[c]{@{}c@{}}%s \\\\[-0.7em] \\footnotesize [%s, %s]\\end{tabular}', ...
                    round_nicely(val), round_nicely(ci_low), round_nicely(ci_high));
    end
    
    % Helper function to format BCR with CI using nested tabular
    function s = format_bcr_with_ci(val, ci_low, ci_high, less_than_zero_to_inf)
        if (less_than_zero_to_inf && val < 0) || isinf(val)
            s = "$\infty$";
        else
            val_str = round_nicely(val);
            low_str = round_nicely(ci_low);
            high_str = round_nicely(ci_high);
            if (less_than_zero_to_inf && ci_high < 0) || isinf(ci_high)
                high_str = "$\infty$";
            end
            s = sprintf('\\begin{tabular}[c]{@{}c@{}}%s \\\\[-0.7em] \\footnotesize [%s, %s]\\end{tabular}', ...
                        val_str, low_str, high_str);
        end
    end
    
    % Helper function to format cost per life with CI using nested tabular
    function s = format_cost_per_life_with_ci(val, ci_low, ci_high)
        if isinf(val)
            s = "$\infty$";
        else
            val_str = round_nicely(val);
            low_str = round_nicely(ci_low);
            high_str = round_nicely(ci_high);
            if isinf(val)
                val_str = "$\infty$";
            end
            if isinf(ci_low)
                low_str = "$\infty$";
            end
            if isinf(ci_high)
                high_str = "$\infty$";
            end
            s = sprintf('\\begin{tabular}[c]{@{}c@{}}%s \\\\[-0.7em] \\footnotesize [%s, %s]\\end{tabular}', ...
                        val_str, low_str, high_str);
        end
    end

    % Escape LaTeX special chars & in names
    summary_data.Category = replace(string(summary_data.Category), "&", "\&");
    summary_data.Accent = replace(string(summary_data.Accent), "&", "\&");
    summary_data.Variation = replace(string(summary_data.Variation), "&", "\&");

    % Sort data: alphabetically by Category (with "Combined" last), then by Accent
    is_combined = strcmp(summary_data.Category, "Combined");
    non_combined_data = summary_data(~is_combined, :);
    combined_data = summary_data(is_combined, :);
    
    % Sort non-combined by Category, then Accent
    [~, sort_idx] = sortrows(non_combined_data, {'Category', 'Accent'});
    non_combined_data = non_combined_data(sort_idx, :);
    
    % Sort combined by Accent
    if height(combined_data) > 0
        [~, sort_idx] = sortrows(combined_data, 'Accent');
        combined_data = combined_data(sort_idx, :);
    end
    
    % Concatenate: non-combined first, then combined
    summary_data = [non_combined_data; combined_data];
    
    % Format all values with CIs (must be done after sorting to maintain correct indices)
    benefit_str = arrayfun(@(i) format_with_ci(summary_data.BenefitDiff(i), ...
        summary_data.BenefitDiff_CI_low(i), summary_data.BenefitDiff_CI_high(i)), ...
        (1:height(summary_data))', 'UniformOutput', false);
    
    cost_str = arrayfun(@(i) format_with_ci(summary_data.CostDiff(i), ...
        summary_data.CostDiff_CI_low(i), summary_data.CostDiff_CI_high(i)), ...
        (1:height(summary_data))', 'UniformOutput', false);
    
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
        
        cost_per_life_10yr_str = arrayfun(@(i) format_cost_per_life_with_ci(summary_data.CostPerLife10yr(i), ...
            summary_data.CostPerLife10yr_CI_low(i), summary_data.CostPerLife10yr_CI_high(i)), ...
            (1:height(summary_data))', 'UniformOutput', false);
        
        cost_per_life_30yr_str = arrayfun(@(i) format_cost_per_life_with_ci(summary_data.CostPerLife30yr(i), ...
            summary_data.CostPerLife30yr_CI_low(i), summary_data.CostPerLife30yr_CI_high(i)), ...
            (1:height(summary_data))', 'UniformOutput', false);
    end
    
    lives_all_str = arrayfun(@(i) format_lives_with_ci(summary_data.LivesAll(i), ...
        summary_data.LivesAll_CI_low(i), summary_data.LivesAll_CI_high(i)), ...
        (1:height(summary_data))', 'UniformOutput', false);
    
    bcr_all_str = arrayfun(@(i) format_bcr_with_ci(summary_data.BCRatioAll(i), ...
        summary_data.BCRatioAll_CI_low(i), summary_data.BCRatioAll_CI_high(i), true), ...
        (1:height(summary_data))', 'UniformOutput', false);
    
    cost_per_life_all_str = arrayfun(@(i) format_cost_per_life_with_ci(summary_data.CostPerLifeAll(i), ...
        summary_data.CostPerLifeAll_CI_low(i), summary_data.CostPerLifeAll_CI_high(i)), ...
        (1:height(summary_data))', 'UniformOutput', false);

    % Group programs so only unique Category rows start scenario, others indented
    [unique_cats,~,cat_idx] = unique(summary_data.Category, 'stable');

    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');

    % Table 1: Effects summary (costs, benefits, net, lives)
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated expected benefits, costs, net value, and lives saved from advance investment programs.} ', ...
        'Monetary estimates are discounted. Bootstrapped 90\\%% confidence intervals shown in brackets.}\n'
    ]; fprintf(fileID, caption_str);

    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c c}\n');
    else
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c}\n');
    end

    fprintf(fileID, '\\hline\n');
    if include_ten_thirty
        fprintf(fileID, ...
            'Scenario & Accent & Costs (\\$~bn) & Benefits (\\$~bn) & Net value (\\$~bn) & \\multicolumn{3}{c}{Lives saved (thousands)} \\\\\n');
        fprintf(fileID, '\\cline{6-8}\n');
        fprintf(fileID, '& & & & & 10 yr & 30 yr & 50 yr \\\\\n');
    else
        fprintf(fileID, ...
            'Scenario & Accent & Costs (\\$~bn) & Benefits (\\$~bn) & Net value (\\$~bn) & Lives saved (thousands) \\\\\n');
    end
    fprintf(fileID, '\\hline\n');
    % Print data in grouped scenario style
    for c = 1:numel(unique_cats)
        idx = find(cat_idx == c);
        for ii = 1:numel(idx)
            i = idx(ii);
            % Only print category for first row of each category group
            if ii == 1
                cat_str = summary_data.Category{i};
            else
                cat_str = '';
            end
            
            if include_ten_thirty
                fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s & %s \\\\\n', ...
                    cat_str, ...
                    summary_data.Accent{i}, ...
                    cost_str{i}, ...
                    benefit_str{i}, ...
                    npv_str(i), ...
                    lives_10yr_str{i}, ...
                    lives_30yr_str{i}, ...
                    lives_all_str{i});
            else
                fprintf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
                    cat_str, ...
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
        'Ratios: mean discounted benefits/mean costs. Bootstrapped 90\\%% confidence intervals shown in brackets.}\n'
    ]; fprintf(fileID, caption_str);

    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c c}\n');
    else
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c}\n');
    end

    fprintf(fileID, '\\hline\n');
    if include_ten_thirty
        fprintf(fileID, ...
            'Scenario & Accent & \\multicolumn{3}{c}{Benefit-cost ratio} & \\multicolumn{3}{c}{\\$ thousands per life saved} \\\\\n');
        fprintf(fileID, '\\cline{3-5}\\cline{6-8}\n');
        fprintf(fileID, '& & 10 yr & 30 yr & 50 yr & 10 yr & 30 yr & 50 yr \\\\\n');
    else
        fprintf(fileID, ...
            'Scenario & Accent & BCR & \\$ thousands per life saved \\\\\n');
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
                    bcr_10yr_str{i}, ...
                    bcr_30yr_str{i}, ...
                    bcr_all_str{i}, ...
                    cost_per_life_10yr_str{i}, ...
                    cost_per_life_30yr_str{i}, ...
                    cost_per_life_all_str{i});
            else
                fprintf(fileID, '%s & %s & %s & %s \\\\\n', ...
                    summary_data.Category{i}, ...
                    summary_data.Accent{i}, ...
                    bcr_all_str{i}, ...
                    cost_per_life_all_str{i});
            end
        end
    end

    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_cost_effectiveness}\n');
    fprintf(fileID, '\\end{table}\n');

    fclose(fileID);
end
