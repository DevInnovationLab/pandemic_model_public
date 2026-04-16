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
    config = yaml.loadFile(fullfile(job_dir, 'run_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(strcmp(scenarios, 'baseline') | ...
                          (~contains(scenarios, "__and__") & ~contains(scenarios, "warning_prec")) | ...
                          (contains(scenarios, "universal_flu") & ~contains(scenarios, "warning_prec")));

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

    disp(surplus_summary_table)

    outpath = fullfile(processed_dir, "ufv_investigation_summary.tex");
    create_table(surplus_summary_table, outpath);
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


function create_table(summary_data, outpath)
    % Convert to billions, format rounding
    summary_data.NPVDiff     = summary_data.NPVDiff / 1e9;
    summary_data.CostDiff    = summary_data.CostDiff / 1e9;
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9;

    round_nicely = @(x) string((abs(x) >= 10).*round(x) + (abs(x) < 10).*round(x,1));
    summary_data.CostDiff    = round_nicely(summary_data.CostDiff);
    summary_data.BenefitDiff = round_nicely(summary_data.BenefitDiff);

    % Extract initial shares in sorted order
    shares = unique(summary_data.initial_share_ufv);
    shares = sort(shares);

    % Open file
    fid = fopen(outpath,'w');

    fprintf(fid, '\\begin{table}[htbp]\n\\centering\n');
    fprintf(fid, ['\\caption{\\textbf{Costs and benefits of universal flu vaccine (UFV) R\\&D and complementary ' ...
                  'investments, under two initial vaccination shares.} Monetary estimates are discounted.}\n']);
    
    % Column structure: | Investment | Cost (share1) | Benefit (share1) | Cost (share2) | Benefit (share2) |
    if length(shares) == 2
        fprintf(fid, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}}l c c c c}\n');
        fprintf(fid, '\\hline\n');
        share_perc = @(x) sprintf('%g\\%%', x*100);
        fprintf(fid, 'Pre-emptive UFV uptake & \\multicolumn{2}{c}{%s} & \\multicolumn{2}{c}{%s} \\\\\n', share_perc(shares(1)), share_perc(shares(2)));
        fprintf(fid, 'Investment & Cost (\\$~bn) & Benefit (\\$~bn) & Cost (\\$~bn) & Benefit (\\$~bn) \\\\\n');
    else
        % Fallback for arbitrary share count
        n = length(shares);
        fprintf(fid, '\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}}l');
        for k=1:n, fprintf(fid,' cc'); end
        fprintf(fid,'}\n\\hline\n');
        fprintf(fid,'Investment');
        for k=1:n
            share_perc = sprintf('%g\\%%', shares(k)*100);
            fprintf(fid,' & Cost (%s) & Benefit (%s)', share_perc, share_perc);
        end
        fprintf(fid,' \\\\\n');
    end

    fprintf(fid, '\\hline\n');

    % Helper: Get cost and benefit for all shares for a given logical index or return '--'
    function colset = get_cols_for_shares(cond)
        colset = cell(1, 2*length(shares));
        for s = 1:length(shares)
            idx = find(cond & summary_data.initial_share_ufv == shares(s));
            if isempty(idx)
                colset{2*s-1} = "--";
                colset{2*s}   = "--";
            else
                colset{2*s-1} = summary_data.CostDiff(idx);
                colset{2*s}   = summary_data.BenefitDiff(idx);
            end
        end
    end

    % 1. Universal flu vaccine R&D alone
    cond_ufv = summary_data.universal_flu & ...
               ~summary_data.advance_capacity & ...
               ~summary_data.early_warning & ...
               ~summary_data.neglected_pathogen;
    row = get_cols_for_shares(cond_ufv);
    fprintf(fid, 'Universal flu vaccine R\\&D alone');
    for v = 1:length(row), fprintf(fid, ' & %s', row{v}); end
    fprintf(fid, ' \\\\\n');

    % 2. Complementary investments
    complements = {
        'Advance capacity',       'advance_capacity';
        'Early warning',          'early_warning';
        'Neglected pathogen R\\&D','neglected_pathogen'
    };

    for c = 1:size(complements,1)
        label = complements{c,1};
        field = complements{c,2};

        fprintf(fid, '\\multicolumn{%d}{l}{\\textit{%s}} \\\\\n', 1 + 2*length(shares), label);

        % Alone: Only this complement is true (excluding universal_flu).
        cond_alone = summary_data.(field) & ...
                     ~summary_data.universal_flu & ...
                     (summary_data.advance_capacity == strcmp(field,'advance_capacity')) & ...
                     (summary_data.early_warning == strcmp(field,'early_warning')) & ...
                     (summary_data.neglected_pathogen == strcmp(field,'neglected_pathogen'));
        row = get_cols_for_shares(cond_alone);
        fprintf(fid, '\\hspace{3mm} Alone');
        for v = 1:length(row), fprintf(fid, ' & %s', row{v}); end
        fprintf(fid, ' \\\\\n');

        % Sum of programs: UFV alone + complement alone
        % For each share, sum cost and sum benefit where both exist, else '--'
        sum_row = cell(1, 2*length(shares));
        for s = 1:length(shares)
            % UFV alone for this share
            cond_ufv_s = (cond_ufv & summary_data.initial_share_ufv == shares(s));
            idx_ufv = find(cond_ufv_s);
            uv_cost = [];
            uv_ben = [];
            if ~isempty(idx_ufv)
                uv_cost = summary_data.CostDiff(idx_ufv);
                uv_ben = summary_data.BenefitDiff(idx_ufv);
            end
            % Complement alone
            cond_alone_s = (cond_alone);
            assert(sum(cond_alone) == 1)
            idx_comp = find(cond_alone_s);
            cp_cost = [];
            cp_ben = [];
            if ~isempty(idx_comp)
                cp_cost = summary_data.CostDiff(idx_comp);
                cp_ben = summary_data.BenefitDiff(idx_comp);
            end
            % Sum or '--'
            if isempty(uv_cost) || isempty(cp_cost)
                sum_row{2*s-1} = '--';
            else
                sum_row{2*s-1} = round_nicely(str2double(uv_cost) + str2double(cp_cost));
            end
            if isempty(uv_ben) || isempty(cp_ben)
                sum_row{2*s} = '--';
            else
                sum_row{2*s} = round_nicely(str2double(uv_ben) + str2double(cp_ben));
            end
        end
        fprintf(fid, '\\hspace{3mm} Sum of programs');
        for v = 1:length(sum_row), fprintf(fid, ' & %s', sum_row{v}); end
        fprintf(fid, ' \\\\\n');

        % Combined: Only UFV and this complement are true (2 programs exactly)
        cond_comb = summary_data.universal_flu & summary_data.(field) & ...
            ((summary_data.advance_capacity + summary_data.early_warning + summary_data.neglected_pathogen + summary_data.universal_flu) == 2);
        row = get_cols_for_shares(cond_comb);
        fprintf(fid, '\\hspace{3mm} Combined');
        for v = 1:length(row), fprintf(fid, ' & %s', row{v}); end
        fprintf(fid, ' \\\\\n');
    end

    fprintf(fid, '\\hline\n\\end{tabular*}\n');
    fprintf(fid, '\\label{tab:ufv_complement_table}\n');
    fprintf(fid, '\\end{table}\n');

    fclose(fid);
end
