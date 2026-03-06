function get_detailed_invest_scenario_table(job_dir, varargin)
    % Build NPV summary table for advance investment scenarios and write CSV + LaTeX.
    % Scenario order and which scenarios to include are defined in get_scenario_order().

    p = inputParser;
    parse(p, varargin{:});

    processed_dir = fullfile(job_dir, "processed");
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    available = string(fieldnames(config.scenarios));
    available = available(~strcmp(available, 'baseline'));

    scenarios = get_scenario_order(available);
    fprintf('Processing %d scenarios\n', length(scenarios));

    summary_table = load_scenario_means(processed_dir, scenarios);

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

function scenarios = get_scenario_order(available)
    % Return scenario names in display order. Only scenarios in available are included.
    % Excludes moderate programs (9-month, single pathogen, BCR-accepting combined).
    order = ["improved_early_warning_low_threshold", ...
             "universal_flu_rd_invest_both", ...
             "advance_capacity_6_month", ...
             "neglected_pathogen_rd_all", ...
             "combined_invest_surplus_acc"];
    scenarios = order(ismember(order, available));
end

function summary_table = load_scenario_means(processed_dir, scenarios)
    % Load scenario means with regime: baseline = vaccine benefits vs response costs;
    % preparedness rows = (vaccine benefits - baseline response costs) vs advance investment cost.
    %
    % Baseline: Benefits = benefits_vaccine, Costs = inp costs (admin, surge, R&D, tailoring).
    % Preparedness: Benefits = benefits_vaccine_scenario - baseline_inp_costs, Costs = advance investment only.

    n = length(scenarios);

    baseline_net = NaN;
    baseline_row = {};
    baseline_file = fullfile(processed_dir, 'baseline_annual_sums.mat');
    if exist(baseline_file, 'file')
        r = load(baseline_file).all_baseline_sums;
        % Baseline: benefits = vaccine benefits, costs = response costs (inp)
        benefit0 = mean(r.benefits_vaccine_full);
        cost0 = mean(r.costs_inp_pv_full);
        npv0 = benefit0 - cost0;
        bcr0 = 0;
        if abs(cost0) >= 1e-7 || abs(benefit0) >= 1e-7
            bcr0 = benefit0 / cost0;
        end
        lives10_0 = mean(r.lives_saved_10_years);
        lives30_0 = mean(r.lives_saved_30_years);
        livesAll_0 = mean(r.lives_saved_full);
        baseline_row = {"Status quo response", "", benefit0, cost0, npv0, bcr0, ...
                        lives10_0, lives30_0, livesAll_0};
    else
        warning('get_detailed_invest_scenario_table:BaselineMissing', ...
            'baseline_annual_sums.mat not found in %s. Baseline row will be omitted.', processed_dir);
    end

    has_baseline = ~isempty(baseline_row);

    summary_table = table('Size', [n + has_baseline, 9], ...
        'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'Category', 'Variation', 'BenefitDiff', 'CostDiff', 'NPVDiff', 'BCRatioAll', 'Lives10yr', 'Lives30yr', 'LivesAll'});

    row_idx = 1;
    if has_baseline
        summary_table(row_idx, :) = baseline_row;
        row_idx = row_idx + 1;
    end

    for i = 1:n
        scen_name = scenarios(i);
        S = load(fullfile(processed_dir, scen_name + "_relative_sums.mat"), 'all_relative_sums');
        r = S.all_relative_sums;
        benefit = mean(r.tot_benefits_pv_full);
        cost = mean(r.costs_adv_invest_pv_full);
        npv = benefit - cost;
        bcr = 0;
        if abs(cost) >= 1e-7 || abs(benefit) >= 1e-7
            bcr = benefit / cost;
        end
        [cat_name, variation] = parse_scenario_name(scen_name);
        summary_table(row_idx, :) = {cat_name, variation, benefit, cost, npv, bcr, ...
            mean(r.lives_saved_10_years), mean(r.lives_saved_30_years), mean(r.lives_saved_full)};
        row_idx = row_idx + 1;
    end
end

function [category_name, variation] = parse_scenario_name(scenario_name)
    % Returns category and variation for display (single row per program).
    if startsWith(scenario_name, "combined_invest")
        category_name = "Combined";
        variation = "";
    elseif startsWith(scenario_name, "advance_capacity")
        category_name = "Advance capacity";
        variation = "";
    elseif startsWith(scenario_name, "universal_flu_rd")
        category_name = "Universal flu vaccine R&D";
        variation = "";
    elseif startsWith(scenario_name, "neglected_pathogen_rd")
        category_name = "Neglected pathogen R&D";
        variation = "";
    elseif startsWith(scenario_name, "improved_early_warning")
        category_name = "Improved early warning";
        variation = "";
    else
        category_name = scenario_name;
        variation = "";
    end
end

function write_advance_investment_table_latex(summary_data, outpath, varargin)
    % Write LaTeX table: one row per scenario (category name only, no indentation).
    p = inputParser;

    % Parse optional arguments
    addParameter(p, 'IncludeTenThirtyYearStats', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    include_ten_thirty = p.Results.IncludeTenThirtyYearStats;

    % Convert to billions and thousands
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

    % Escape LaTeX special chars
    summary_data.Category = replace(string(summary_data.Category), "&", "\&");
    summary_data.Variation = replace(string(summary_data.Variation), "&", "\&");

    % Format numeric columns
    benefit_str = round_and_comma(summary_data.BenefitDiff);
    cost_str = round_and_comma(summary_data.CostDiff);
    npv_str = round_and_comma(summary_data.NPVDiff);
    bcr_str = round_and_comma(summary_data.BCRatioAll);
    lives_10yr_str = round_and_comma(summary_data.Lives10yr);
    lives_30yr_str = round_and_comma(summary_data.Lives30yr);
    lives_all_str = round_and_comma(summary_data.LivesAll);

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
    if include_ten_thirty
        fprintf(fileID, ['Scenario & Costs & Benefits & Net value & BCR & \\multicolumn{3}{c}{Lives saved} \\\\\n']);
        fprintf(fileID, ['& (\\$~bn) & (\\$~bn) & (\\$~bn) & & 10 yr & 30 yr & 50 yr \\\\\n']);
    else
        fprintf(fileID, ['Scenario & Costs & Benefits & Net value & BCR & Lives saved \\\\\n']);
        fprintf(fileID, ['& (\\$~bn) & (\\$~bn) & (\\$~bn) & & (thousands) \\\\\n']);
    end
    fprintf(fileID, '\\hline\n');

    % Print data: one row per scenario (category name, no indentation)
    for i = 1:height(summary_data)
        label_str = char(summary_data.Category{i});
        if include_ten_thirty
            fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s & %s \\\\\n', ...
                label_str, cost_str(i), benefit_str(i), npv_str(i), bcr_str(i), ...
                lives_10yr_str(i), lives_30yr_str(i), lives_all_str(i));
        else
            fprintf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
                label_str, cost_str(i), benefit_str(i), npv_str(i), bcr_str(i), lives_all_str(i));
        end
    end
    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:adv_invest_summary}\n');
    fprintf(fileID, '\\end{table}\n\n');

    fclose(fileID);
end
