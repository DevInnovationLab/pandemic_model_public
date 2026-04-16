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

    % Get scenarios from config.
    config = yaml.loadFile(fullfile(job_dir, 'run_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    % Only early warning (alone & combos), keep 'baseline'
    scenarios = scenarios(strcmp(scenarios, 'baseline') | ... 
                          (~contains(scenarios, "__and__") & ~contains(scenarios, "prevac")) | ...
                          (contains(scenarios, "universal_flu") & ~contains(scenarios, "prevac")));

    % Categorize scenarios into blocks (solo, combos, etc)
    blocks = struct( ...
        'title', {'Early warning alone', ...
                  'Advance capacity + Early warning', ...
                  'Neglected pathogen R&D + Early warning', ...
                  'Universal flu vaccine + Early warning'}, ...
        'match', { ...
            @(s) contains(s, "early_warning") & ~contains(s, "advance_capacity") & ...
                  ~contains(s, "neglected_pathogen") & ~contains(s, "universal_flu"), ...
            @(s) contains(s, "early_warning") & contains(s, "advance_capacity") & ...
                 ~contains(s, "neglected_pathogen") & ~contains(s, "universal_flu"), ...
            @(s) contains(s, "early_warning") & contains(s, "neglected_pathogen") & ...
                 ~contains(s, "advance_capacity") & ~contains(s, "universal_flu"), ...
            @(s) contains(s, "early_warning") & contains(s, "universal_flu") & ...
                 ~contains(s, "advance_capacity") & ~contains(s, "neglected_pathogen") ...
        });

    % Build summary table: For each scenario, compute stats
    summary_table = table('Size', [length(scenarios) 13], ...
        'VariableTypes', {'string', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double', 'double', ...
                         'double', 'double', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'BenefitDiff', 'CostDiff', 'NPVDiff',  ...
        'BCRatio10yr', 'BCRatio30yr', 'BCRatioAll', 'Lives10yr', 'Lives30yr', ...
        'LivesAll', 'CostPerLife10yr', 'CostPerLife30yr', 'CostPerLifeAll'};

    precisions = nan(length(scenarios),1);
    recalls = nan(length(scenarios),1);
    early_warning_flags = false(length(scenarios),1);
    advance_capacity_flags = false(length(scenarios),1);
    neglected_pathogen_flags = false(length(scenarios),1);
    universal_flu_flags = false(length(scenarios),1);

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
        total_scen_costs_10yr = mean(sum(scen_costs(:,1:10), 2));
        total_baseline_costs_10yr = mean(sum(baseline_costs(:,1:10), 2));
        total_scen_benefits_10yr = mean(sum(scen_benefits(:,1:10), 2));
        total_baseline_benefits_10yr = mean(sum(baseline_npv(:,1:10) + baseline_costs(:,1:10), 2));
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

        summary_table(i,:) = {scen_name, benefit_diff, cost_diff, npv_diff, ...
                             bc_ratio_10yr, bc_ratio_30yr, bc_ratio_all, lives_10yr, lives_30yr, ...
                             lives_all, cost_per_life_10yr, cost_per_life_30yr, cost_per_life_all};

        % Extract scenario parameters
        if ~strcmp(scen_name, 'baseline')
            scenario_params = config.scenarios.(scen_name);
            precisions(i) = scenario_params.improved_early_warning.precision;
            recalls(i) = scenario_params.improved_early_warning.recall;
            
            % Flag which interventions are present
            early_warning_flags(i) = contains(scen_name, 'early_warning');
            advance_capacity_flags(i) = contains(scen_name, 'advance_capacity');
            neglected_pathogen_flags(i) = contains(scen_name, 'neglected_pathogen');
            universal_flu_flags(i) = contains(scen_name, 'universal_flu');
        end
    end

    summary_table.precision = precisions;
    summary_table.recall = recalls;
    summary_table.early_warning = early_warning_flags;
    summary_table.advance_capacity = advance_capacity_flags;
    summary_table.neglected_pathogen = neglected_pathogen_flags;
    summary_table.universal_flu = universal_flu_flags;

    % Save wide summary table for reference
    writetable(summary_table, fullfile(processed_dir, 'early_warning_variant_summary.csv'));

    disp(summary_table.Scenario);

    % Make block-structured latex table with precision, recall as columns
    outpath = fullfile(processed_dir, "early_warning_variant_summary.tex");
    create_blocked_ew_table(summary_table, blocks, outpath);
end
function create_blocked_ew_table(summary_data, blocks, outpath)
    % Convert to appropriate units for reporting
    summary_data.BenefitDiff = summary_data.BenefitDiff / 1e9;
    summary_data.CostDiff = summary_data.CostDiff / 1e9;
    summary_data.CostPerLifeAll = summary_data.CostPerLifeAll / 1e3;

    % Nice rounding
    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x,1));
    summary_data.precision = round_nicely(summary_data.precision);
    summary_data.recall = round_nicely(summary_data.recall);
    summary_data.BenefitDiff = round_nicely(summary_data.BenefitDiff);
    summary_data.CostDiff = round_nicely(summary_data.CostDiff);

    % Escape LaTeX special chars in scenario names
    summary_data.Scenario = replace(string(summary_data.Scenario), "&", "\&");

    % Reorder blocks if needed: Early warning block should come first
    ew_idx = find(strcmp({blocks.title}, 'Early warning alone'), 1, 'first');
    ufv_idx = find(strcmp({blocks.title}, 'Universal flu vaccine + Early warning'), 1, 'first');
    % If both blocks found, and ufv is before ew, swap order
    if ~isempty(ew_idx) && ~isempty(ufv_idx) && ufv_idx < ew_idx
        order = 1:numel(blocks);
        order([ew_idx ufv_idx]) = order([ufv_idx ew_idx]);
        blocks = blocks(order);
    end

    fileID = fopen(outpath, 'w');
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    caption_str = ['\\caption{Estimated expected costs and benefits of early warning investments ' ...
                   'alone and in combination with other interventions, comparing combined programs and sums of standalone programs. ' ...
                   'Each block summarizes a group. Monetary estimates are discounted.}\n'];
    fprintf(fileID, caption_str);

    % Remove bold and vertical separator as per user's new LaTeX output
    fprintf(fileID, ['\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}} l c c c c c}\n']);
    fprintf(fileID, '\\noalign{\\vskip 3pt}\n');
    fprintf(fileID, '\\hline\n');

    % Header row: no bold, no vertical line
    fprintf(fileID, ' & & Combined program & & Sum of standalones & \\\\\n');
    fprintf(fileID, 'Sensitivity & Precision & Costs (\\$~bn) & Benefits (\\$~bn) & Costs (\\$~bn) & Benefits (\\$~bn) \\\\\n');
    fprintf(fileID, '\\hline\n');

    for b = 1:length(blocks)
        block = blocks(b);
        mask = block.match(summary_data.Scenario);
        rows = find(mask & ~strcmp(summary_data.Scenario, 'baseline'));

        if isempty(rows)
            continue
        end

        % Block row title, centered over all columns
        fprintf(fileID, '\\multicolumn{6}{c}{%s} \\\\\n', block.title);

        for i = rows'
            cost_comb = summary_data.CostDiff(i);
            ben_comb  = summary_data.BenefitDiff(i);
            
            this_prec = summary_data.precision(i);
            this_reca = summary_data.recall(i);

            % Determine which interventions are present in this row
            ew_present = summary_data.early_warning(i);
            ac_present = summary_data.advance_capacity(i);
            np_present = summary_data.neglected_pathogen(i);
            ufv_present = summary_data.universal_flu(i);
            
            num_present = ew_present + ac_present + np_present + ufv_present;

            % For standalone programs: only show for combinations (2+ interventions)
            standalone_cost = "--";
            standalone_ben = "--";
            
            if num_present >= 2
                standalone_costs = [];
                standalone_bens = [];
                
                % Find each component alone - note that standalone interventions don't have precision/recall
                if ew_present
                    idx = find(summary_data.early_warning & ~summary_data.advance_capacity & ...
                              ~summary_data.neglected_pathogen & ~summary_data.universal_flu & ...
                              summary_data.precision == this_prec & summary_data.recall == this_reca, 1);
                    if ~isempty(idx)
                        standalone_costs(end+1) = str2double(summary_data.CostDiff(idx));
                        standalone_bens(end+1) = str2double(summary_data.BenefitDiff(idx));
                    end
                end
                
                if ac_present
                    % Advance capacity standalone doesn't have precision/recall, so don't filter on them
                    idx = find(summary_data.advance_capacity & ~summary_data.early_warning & ...
                              ~summary_data.neglected_pathogen & ~summary_data.universal_flu, 1);
                    if ~isempty(idx)
                        standalone_costs(end+1) = str2double(summary_data.CostDiff(idx));
                        standalone_bens(end+1) = str2double(summary_data.BenefitDiff(idx));
                    end
                end
                
                if np_present
                    % Neglected pathogen standalone doesn't have precision/recall, so don't filter on them
                    idx = find(summary_data.neglected_pathogen & ~summary_data.early_warning & ...
                              ~summary_data.advance_capacity & ~summary_data.universal_flu, 1);
                    if ~isempty(idx)
                        standalone_costs(end+1) = str2double(summary_data.CostDiff(idx));
                        standalone_bens(end+1) = str2double(summary_data.BenefitDiff(idx));
                    end
                end
                
                if ufv_present
                    % Universal flu standalone doesn't have precision/recall, so don't filter on them
                    idx = find(summary_data.universal_flu & ~summary_data.early_warning & ...
                              ~summary_data.advance_capacity & ~summary_data.neglected_pathogen, 1);
                    if ~isempty(idx)
                        standalone_costs(end+1) = str2double(summary_data.CostDiff(idx));
                        standalone_bens(end+1) = str2double(summary_data.BenefitDiff(idx));
                    end
                end

                % Sum the standalone components
                if ~isempty(standalone_costs)
                    standalone_cost = round_nicely(sum(standalone_costs));
                end
                if ~isempty(standalone_bens)
                    standalone_ben = round_nicely(sum(standalone_bens));
                end
            end

            fprintf(fileID, '%s & %s & %s & %s & %s & %s \\\\\n', ...
                summary_data.recall(i), ...
                summary_data.precision(i), ...
                cost_comb, ben_comb, ...
                standalone_cost, standalone_ben);
        end
    end

    fprintf(fileID, '\\hline\n\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:early_warning_comparison}\n');
    fprintf(fileID, '\\end{table}\n\n');
    fclose(fileID);
end
