function get_detailed_invest_scenario_table(job_dir, varargin)
    % Parse optional arguments
    p = inputParser;
    parse(p, varargin{:});

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
    
    % Initialize summary table: Remove CI columns. Add BCR column after NPVDiff.
    summary_table = table('Size', [length(scenarios) 10], ...
        'VariableTypes', {'string', 'string', 'string', ...
                         'double', ... % BenefitDiff
                         'double', ... % CostDiff
                         'double', ... % NPVDiff
                         'double', ... % BCRatio all
                         'double', ... % Lives10yr
                         'double', ... % Lives30yr
                         'double'}, ...% LivesAll
        'VariableNames', {'Category', 'Accent', 'Variation', ...
        'BenefitDiff', 'CostDiff', 'NPVDiff', 'BCRatioAll', ...
        'Lives10yr', 'Lives30yr', 'LivesAll'});

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
        
        % Calculate BCR (all years): benefit/cost, treating 0/0 as 0
        if abs(cost_diff) < 1e-7  && abs(benefit_diff) < 1e-7
            bc_ratio_all = 0;
        else
            bc_ratio_all = benefit_diff / cost_diff;
        end
        
        % Lives saved
        lives_10yr = mean(relative_sums.lives_saved_10_years);
        lives_30yr = mean(relative_sums.lives_saved_30_years);
        lives_all = mean(relative_sums.lives_saved_full);
        
        fprintf('  Means computed in %.2f seconds\n', toc);
        
        % Add row to table
        summary_table(i,:) = {category_name, accent, variation, ...
                             benefit_diff, cost_diff, npv_diff, bc_ratio_all, ...
                             lives_10yr, lives_30yr, lives_all};
        fprintf('  Scenario %s complete\n\n', scen_name);
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
    summary_data.CostDiff = summary_data.CostDiff / 1e9;
    
    % Convert lives to thousands
    summary_data.Lives10yr = summary_data.Lives10yr / 1e3;
    summary_data.Lives30yr = summary_data.Lives30yr / 1e3;
    summary_data.LivesAll = summary_data.LivesAll / 1e3;

    % Helper function to insert commas for thousands
    function s = commafy(x)
        if isnan(x)
            s = "";
        elseif abs(x) < 1000
            if mod(x,1)==0
                % Integer but <1000
                s = sprintf("%.0f", x);
            else
                s = sprintf("%.1f", x);
            end
        else
            if mod(x,1)==0
                s = regexprep(sprintf('%.0f',x), '\d(?=(\d{3})+$)', '$&,');
            else
                s = regexprep(sprintf('%.1f',x), '\d(?=(\d{3})+\.)', '$&,');
            end
        end
        s = string(s);
    end

    % Helper function to round nicely and format with commas
    round_and_comma = @(x) arrayfun(@(v) commafy((v >= 10).*round(v) + (v < 10).*round(v,1)), x);

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
    
    % Prepare formatted strings for table
    benefit_str = round_and_comma(summary_data.BenefitDiff);
    cost_str = round_and_comma(summary_data.CostDiff);
    npv_str = round_and_comma(summary_data.NPVDiff);
    bcr_str = round_and_comma(summary_data.BCRatioAll);
    lives_10yr_str = round_and_comma(summary_data.Lives10yr);
    lives_30yr_str = round_and_comma(summary_data.Lives30yr);
    lives_all_str = round_and_comma(summary_data.LivesAll);

    % Group programs so only unique Category rows start scenario, others indented
    [unique_cats,~,cat_idx] = unique(summary_data.Category, 'stable');

    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');

    % Table: Effects summary (costs, benefits, net, BCR, lives)
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = [
        '\\caption{\\textbf{Estimated expected benefits, costs, net value, benefit--cost ratio, and lives saved from advance investment programs.} ', ...
        'Monetary estimates are discounted.}\n'
    ]; fprintf(fileID, caption_str);

    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c c c}\n');
    else
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c}\n');
    end

    fprintf(fileID, '\\hline\n');
    % First row: labels
    if include_ten_thirty
        fprintf(fileID, ['Scenario & Accent & Costs & Benefits & Net value & BCR & \\multicolumn{3}{c}{Lives saved} \\\\\n']);
        fprintf(fileID, ['& & (\\$~bn) & (\\$~bn) & (\\$~bn) & & 10 yr & 30 yr & 50 yr \\\\\n']);
    else
        fprintf(fileID, ['Scenario & Accent & Costs & Benefits & Net value & BCR & Lives saved \\\\\n']);
        fprintf(fileID, ['& & (\\$~bn) & (\\$~bn) & (\\$~bn) & & (thousands) \\\\\n']);
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
                fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s & %s & %s \\\\\n', ...
                    cat_str, ...
                    summary_data.Accent{i}, ...
                    cost_str(i), ...
                    benefit_str(i), ...
                    npv_str(i), ...
                    bcr_str(i), ...
                    lives_10yr_str(i), ...
                    lives_30yr_str(i), ...
                    lives_all_str(i));
            else
                fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s \\\\\n', ...
                    cat_str, ...
                    summary_data.Accent{i}, ...
                    cost_str(i), ...
                    benefit_str(i), ...
                    npv_str(i), ...
                    bcr_str(i), ...
                    lives_all_str(i));
            end
        end
    end
    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');

    fclose(fileID);
end
