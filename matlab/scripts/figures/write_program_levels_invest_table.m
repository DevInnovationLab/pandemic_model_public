function write_program_levels_invest_table(job_dir, varargin)
    % Build NPV summary table for program-level investment scenarios (advance capacity
    % intensity and neglected pathogen R&D scope) and write CSV + LaTeX.
    %
    % Accounting matches write_invest_scenario_table preparedness rows: incremental
    % tot_benefits minus advance investment costs from relative_sums. Status quo
    % baseline is not included in this table.
    %
    % Expects processed outputs from a job whose scenario_configs include
    % capacity_prototype_variations (or the same scenario stems).
    %
    % Args:
    %   job_dir (char/string): Job output directory containing processed/ and job_config.yaml.

    p = inputParser;
    parse(p, varargin{:});

    job_dir = char(string(job_dir));
    processed_dir = fullfile(job_dir, "processed");
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    available = string(fieldnames(config.scenarios));
    available = available(~strcmp(available, 'baseline'));

    scenarios = get_program_levels_scenario_order(available);
    if isempty(scenarios)
        warning('write_program_levels_invest_table:NoScenarios', ...
            'No program-level scenarios found in job config (expected advance_capacity_share_* and neglected_pathogen_rd_num_*).');
        return;
    end

    fprintf('write_program_levels_invest_table: processing %d scenarios\n', length(scenarios));

    summary_table = load_program_levels_means(processed_dir, scenarios);

    writetable(summary_table, fullfile(processed_dir, 'npv_summary_program_levels.csv'));

    write_program_levels_table_latex(summary_table, ...
        fullfile(processed_dir, 'program_levels_investment_summary.tex'), ...
        'IncludeTenThirtyYearStats', true);

    write_program_levels_table_latex(summary_table, ...
        fullfile(processed_dir, 'program_levels_investment_summary_no_10_30.tex'), ...
        'IncludeTenThirtyYearStats', false);
end


function scenarios = get_program_levels_scenario_order(available)
    % Fixed order: advance capacity shares, then neglected pathogen num (top-k).
    order = ["advance_capacity_share_050", "advance_capacity_share_100", ...
             "advance_capacity_share_150", "advance_capacity_share_200", ...
             "neglected_pathogen_rd_num_1", "neglected_pathogen_rd_num_2", ...
             "neglected_pathogen_rd_num_3"];
    scenarios = order(ismember(order, available));
end


function summary_table = load_program_levels_means(processed_dir, scenarios)
    % Same benefit/cost definitions as write_invest_scenario_table preparedness rows.

    n = length(scenarios);

    summary_table = table('Size', [n, 9], ...
        'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'Category', 'Variation', 'BenefitDiff', 'CostDiff', 'NPVDiff', 'BCRatioAll', 'Lives10yr', 'Lives30yr', 'LivesAll'});

    for i = 1:n
        scen_name = scenarios(i);
        S = load(fullfile(processed_dir, scen_name + "_relative_sums.mat"), 'all_relative_sums');
        r = S.all_relative_sums;
        benefit = mean(r.tot_benefits_pv_full);
        cost = mean(r.costs_adv_invest_pv_full);
        npv = benefit - cost;
        bcr = bcr_ratio(benefit, cost);
        [cat_name, variation] = program_levels_labels(scen_name);
        summary_table(i, :) = {cat_name, variation, benefit, cost, npv, bcr, ...
            mean(r.lives_saved_10_years), mean(r.lives_saved_30_years), mean(r.lives_saved_full)};
    end
end


function b = bcr_ratio(benefit, cost)
    b = 0;
    if abs(cost) >= 1e-7 || abs(benefit) >= 1e-7
        b = benefit / cost;
    end
end


function [category_name, variation] = program_levels_labels(scenario_name)
    % Map scenario stem to display group (Category) and sub-label (Variation).
    sn = string(scenario_name);

    if startsWith(sn, "advance_capacity_share_")
        category_name = "Advance capacity";
        rest = erase(sn, "advance_capacity_share_");
        if rest == "050"
            variation = "50% of standard program";
        elseif rest == "100"
            variation = "100% of standard program";
        elseif rest == "150"
            variation = "150% of standard program";
        elseif rest == "200"
            variation = "200% of standard program";
        else
            variation = "Share " + rest;
        end
    elseif startsWith(sn, "neglected_pathogen_rd_num_")
        category_name = "Prototype vaccine R&D";
        k = sscanf(char(extractAfter(sn, "neglected_pathogen_rd_num_")), '%d');
        if k == 1
            variation = "R&D for top priority pathogen";
        else
            variation = sprintf('R&D for top %d pathogens', k);
        end
        variation = string(variation);
    else
        category_name = sn;
        variation = "";
    end
end


function write_program_levels_table_latex(summary_data, outpath, varargin)
    % LaTeX table with group headers (Advance capacity / Prototype vaccine R&D) and
    % indented sub-rows for each variation.

    p = inputParser;
    addParameter(p, 'IncludeTenThirtyYearStats', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    include_ten_thirty = p.Results.IncludeTenThirtyYearStats;

    summary_data.NPVDiff = summary_data.NPVDiff / 1e9;
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9;
    summary_data.CostDiff = summary_data.CostDiff / 1e9;
    summary_data.Lives10yr = summary_data.Lives10yr / 1e6;
    summary_data.Lives30yr = summary_data.Lives30yr / 1e6;
    summary_data.LivesAll = summary_data.LivesAll / 1e6;

    function s = commafy(x)
        if isnan(x)
            s = "";
        elseif abs(x) < 1000
            if mod(x, 1) == 0
                s = sprintf("%.0f", x);
            else
                s = sprintf("%.1f", x);
            end
        else
            if mod(x, 1) == 0
                s = regexprep(sprintf('%.0f', x), '\d(?=(\d{3})+$)', '$&,');
            else
                s = regexprep(sprintf('%.1f', x), '\d(?=(\d{3})+\.)', '$&,');
            end
        end
        s = string(s);
    end

    round_and_comma = @(x) arrayfun(@(v) commafy((v >= 10) .* round(v) + (v < 10) .* round(v, 1)), x);

    summary_data.Category = replace(string(summary_data.Category), "&", "\&");
    summary_data.Variation = replace(string(summary_data.Variation), "&", "\&");

    benefit_str = round_and_comma(summary_data.BenefitDiff);
    cost_str = round_and_comma(summary_data.CostDiff);
    npv_str = round_and_comma(summary_data.NPVDiff);
    bcr_str = round_and_comma(summary_data.BCRatioAll);
    lives_10yr_str = round_and_comma(summary_data.Lives10yr);
    lives_30yr_str = round_and_comma(summary_data.Lives30yr);
    lives_all_str = round_and_comma(summary_data.LivesAll);

    fileID = fopen(outpath, 'w');

    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    fprintf(fileID, ['\\caption{\\textbf{Expected benefits, costs, net value, benefit--cost ratio, and lives saved ', ...
        'by program intensity and scope.} Monetary estimates are discounted.}\n']);

    if include_ten_thirty
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c c c}\n');
    else
        fprintf(fileID, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c c}\n');
    end

    fprintf(fileID, '\\hline\n');
    if include_ten_thirty
        fprintf(fileID, ['Program & Costs & Benefits & Net value & BCR & \\multicolumn{3}{c}{Lives saved} \\\\\n']);
        fprintf(fileID, ['& (billion \\$) & (billion \\$) & (billion \\$) & & 10 yr & 30 yr & 50 yr \\\\\n']);
    else
        fprintf(fileID, ['Program & Costs & Benefits & Net value & BCR & Lives saved \\\\\n']);
        fprintf(fileID, ['& (billion \\$) & (billion \\$) & (billion \\$) & & (millions) \\\\\n']);
    end
    fprintf(fileID, '\\hline\n');

    ncols = 8;
    if ~include_ten_thirty
        ncols = 6;
    end

    prev_cat = "";
    for r = 1:height(summary_data)
        cat = char(summary_data.Category(r));
        var = char(summary_data.Variation(r));
        if ~strcmp(cat, prev_cat)
            if strlength(prev_cat) > 0
                fprintf(fileID, '\\hline\n');
            end
            fprintf(fileID, '\\multicolumn{%d}{l}{\\textbf{%s}} \\\\\n', ncols, cat);
            prev_cat = cat;
        end
        var_tex = strrep(var, '%', '\%');
        sublabel = ['\\hspace{1.5em}', var_tex];
        if include_ten_thirty
            fprintf(fileID, '%s & %s & %s & %s & %s & %s & %s & %s \\\\\n', ...
                sublabel, cost_str(r), benefit_str(r), npv_str(r), bcr_str(r), ...
                lives_10yr_str(r), lives_30yr_str(r), lives_all_str(r));
        else
            fprintf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
                sublabel, cost_str(r), benefit_str(r), npv_str(r), bcr_str(r), lives_all_str(r));
        end
    end

    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:program_levels_investment}\n');
    fprintf(fileID, '\\end{table}\n\n');

    fclose(fileID);
end
