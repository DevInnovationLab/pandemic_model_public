function [annualized_summary_table, total_summary_table] = build_sensitivity_loss_tables(sensitivity_dir)
    % Build annualized and total loss summary tables from sensitivity run directories.
    %
    % Loads unmitigated loss outputs for baseline and each sensitivity value (from
    % value_dir/unmitigated_losses.mat), annualizes, computes mean and 10/90 percentiles,
    % and writes the summary CSVs. Run aggregate_unmitigated_losses per scenario first
    % if results were chunked.
    %
    % total_summary_table lists discounted horizon totals in Total* loss columns; the
    % last column is total unmitigated loss with no discounting (clearly named).
    %
    % Args:
    %   sensitivity_dir (char or string): Path to sensitivity output directory
    %     (e.g. output/sensitivity_runs/no_mitigation_all).
    %
    % Returns:
    %   annualized_summary_table (table): Table with Variable, Value, and loss columns (cell of structs).
    %   total_summary_table (table): Horizon totals; loss columns through TotalLoss are discounted;
    %     TotalUnmitigatedLossUndiscounted is undiscounted (see estimate_unmitigated_losses).
    %
    % Also writes:
    %   sensitivity_dir/sensitivity_runs_annualized_loss_summary.csv
    %   sensitivity_dir/sensitivity_runs_total_loss_summary.csv

    sensitivity_dir = char(sensitivity_dir);
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    [scenario_ids, scenario_paths] = get_sensitivity_scenarios(sensitivity_dir);

    baseline_config = yaml.loadFile(fullfile(sensitivity_dir, 'baseline', 'run_config.yaml'));
    baseline_r = baseline_config.r;
    baseline_periods = baseline_config.sim_periods;
    baseline_dir = fullfile(sensitivity_dir, 'baseline');

    n_rows = 1 + length(scenario_ids);
    annualized_summary_table = table('Size', [n_rows, 7], ...
        'VariableTypes', {'string', 'string', 'cell', 'cell', 'cell', 'cell', 'cell'});
    annualized_summary_table.Properties.VariableNames = ...
        {'Variable', 'Value', 'AnnualDeaths', 'MortalityLoss', 'EconomicLoss', 'LearningLoss', 'TotalLoss'};
    total_summary_table = table('Size', [n_rows, 8], ...
        'VariableTypes', {'string', 'string', 'cell', 'cell', 'cell', 'cell', 'cell', 'cell'});
    total_summary_table.Properties.VariableNames = ...
        {'Variable', 'Value', 'TotalDeaths', 'TotalMortalityLoss', 'TotalEconomicLoss', 'TotalLearningLoss', ...
        'TotalLoss', 'TotalUnmitigatedLossUndiscounted'};

    [vname, vval] = format_names('baseline', '', baseline_config, baseline_config);
    mat_file = fullfile(baseline_dir, 'unmitigated_losses.mat');
    S = load(mat_file, 'sim_total_deaths', 'sim_mortality_loss', 'sim_output_loss', ...
        'sim_learning_loss', 'sim_total_loss', 'sim_total_loss_undiscounted');
    [ann_row, tot_row] = build_table_rows_from_sim(S, baseline_r, baseline_periods, vname, vval);
    annualized_summary_table(1, :) = ann_row;
    total_summary_table(1, :) = tot_row;

    for k = 1:length(scenario_ids)
        scenario_id = scenario_ids{k};
        value_dir = scenario_paths{k};
        run_config = yaml.loadFile(fullfile(value_dir, "run_config.yaml"));
        tok = regexp(scenario_id, '^(.+)_value_(\d+)$', 'tokens');
        if isempty(tok)
            var_name = scenario_id;
            var_value = '';
        else
            var_name = tok{1}{1};
            j = str2double(tok{1}{2});
            var_values = sensitivity_config.sensitivities.(var_name);
            if isnumeric(var_values)
                var_value = var_values(j);
            else
                var_value = var_values{j};
            end
        end
        [vname, vval] = format_names(var_name, var_value, baseline_config, run_config);
        mat_file = fullfile(value_dir, 'unmitigated_losses.mat');
        S = load(mat_file, 'sim_total_deaths', 'sim_mortality_loss', 'sim_output_loss', ...
            'sim_learning_loss', 'sim_total_loss', 'sim_total_loss_undiscounted');
        [ann_row, tot_row] = build_table_rows_from_sim(S, run_config.r, run_config.sim_periods, vname, vval);
        annualized_summary_table(k + 1, :) = ann_row;
        total_summary_table(k + 1, :) = tot_row;
    end

    annualized_csv = summary_table_to_csv(annualized_summary_table);
    total_csv = summary_table_to_csv(total_summary_table);
    writetable(annualized_csv, fullfile(sensitivity_dir, 'sensitivity_annualized_loss_summary.csv'));
    writetable(total_csv, fullfile(sensitivity_dir, 'sensitivity_total_loss_summary.csv'));
    fprintf('Sensitivity loss tables and CSVs written to %s\n', sensitivity_dir);
end

function [annualized_row, total_row] = build_table_rows_from_sim(S, r, periods, variable, value)
    % One scenario: build the two table rows from loaded unmitigated_losses.mat fields.
    % Annualized losses use the same annuity factor as estimate_unmitigated_losses (sim_* .* ann).
    % Horizon loss columns are raw discounted sums over periods; last column is undiscounted total.
    ann = annualization_factor(r, periods);
    annualized_row = {...
        variable, value, ...
        {get_mean_and_percentiles(S.sim_total_deaths ./ periods)}, ...
        {get_mean_and_percentiles(S.sim_mortality_loss .* ann)}, ...
        {get_mean_and_percentiles(S.sim_output_loss .* ann)}, ...
        {get_mean_and_percentiles(S.sim_learning_loss .* ann)}, ...
        {get_mean_and_percentiles(S.sim_total_loss .* ann)}, ...
    };
    total_row = {...
        variable, value, ...
        {get_mean_and_percentiles(S.sim_total_deaths)}, ...
        {get_mean_and_percentiles(S.sim_mortality_loss)}, ...
        {get_mean_and_percentiles(S.sim_output_loss)}, ...
        {get_mean_and_percentiles(S.sim_learning_loss)}, ...
        {get_mean_and_percentiles(S.sim_total_loss)}, ...
        {get_mean_and_percentiles(S.sim_total_loss_undiscounted)}, ...
    };
end

function ann = annualization_factor(r, periods)
    % Converts horizon discounted loss sums to annualized equivalents (matches estimate_unmitigated_losses).
    ann = (r * (1 + r)^periods) / ((1 + r)^periods - 1);
end

function csv_table = summary_table_to_csv(summary_table)
    function m = get_mean(cellval)
        m = cellval{1}.mean;
    end
    ncols = width(summary_table);
    csv_data = cell(height(summary_table), ncols);
    for row = 1:height(summary_table)
        csv_data{row, 1} = summary_table{row, 1};
        csv_data{row, 2} = summary_table{row, 2};
        for col = 3:ncols
            csv_data{row, col} = get_mean(summary_table{row, col});
        end
    end
    csv_table = cell2table(csv_data, 'VariableNames', summary_table.Properties.VariableNames);
end

function stats = get_mean_and_percentiles(sample)
    assert(isvector(sample));
    stats.mean = mean(sample) / 1e12;
    pctiles = prctile(sample, [10 90]) / 1e12;
    stats.p10 = pctiles(1);
    stats.p90 = pctiles(2);
end

function [formatted_name, formatted_value] = format_names(var_name, var_value, baseline_config, run_config)
    % Row labels for sensitivity summary tables. Baseline vs scenario run_config encodes combined
    % pathogen (arrival + duration) settings; struct scenarios share the same logic as list sweeps.

    baseline_vsl = baseline_config.value_of_death;
    baseline_r = baseline_config.r;
    baseline_y = baseline_config.y;

    switch var_name
        case "value_of_death"
            formatted_name = "Value of statistical life ($v$)";
            if var_value < baseline_vsl
                formatted_value = sprintf("Reduce to \\$%g million", var_value/1e6);
            elseif var_value > baseline_vsl
                formatted_value = sprintf("Increase to \\$%g million", var_value/1e6);
            else
                formatted_value = string(var_value);
            end
        case "y"
            formatted_name = "Per capita GDP growth rate ($r_g$)";
            if var_value < baseline_y
                formatted_value = sprintf("Reduce to %.1f\\%%", var_value * 100);
            elseif var_value > baseline_y
                formatted_value = sprintf("Increase to %.1f\\%%", var_value * 100);
            else
                formatted_value = string(var_value);
            end
        case "r"
            formatted_name = "Social discount rate ($r_s$)";
            if var_value < baseline_r
                formatted_value = sprintf("Reduce to %.1f\\%%", var_value * 100);
            elseif var_value > baseline_r
                formatted_value = sprintf("Increase to %.1f\\%%", var_value * 100);
            else
                formatted_value = string(var_value);
            end
        case "ptrs_pathogen_gamma1"
            formatted_name = "Vaccines always succeed, $\\gamma = 1$";
            formatted_value = "";
        case "baseline"
            formatted_name = "Baseline";
            formatted_value = "";
        otherwise
            [pn, pv] = pathogen_and_duration_labels(baseline_config, run_config);
            if strlength(pn) > 0
                formatted_name = pn;
                formatted_value = pv;
            elseif strcmp(char(var_name), 'duration_dist_config')
                formatted_name = "Duration upper bound ($\overline{d}$)";
                rt = duration_stem_trunc_years(var_value);
                formatted_value = sprintf("%g years", rt);
            else
                formatted_name = humanize_scenario_key(var_name);
                formatted_value = "";
            end
    end
end

function [name, val] = pathogen_and_duration_labels(baseline_config, run_config)
    % Compare merged pathogen inputs vs baseline (arrival GPD + duration CSV paths).
    name = "";
    val = "";
    b_arr = char(baseline_config.arrival_dist_config);
    r_arr = char(run_config.arrival_dist_config);

    if strcmp(b_arr, r_arr)
        [name, val] = duration_only_labels(baseline_config, run_config);
        return;
    end

    b_meta = parse_arrival_dist_fp(b_arr);
    s_meta = parse_arrival_dist_fp(r_arr);
    trunc_diff = s_meta.trunc_value ~= b_meta.trunc_value;
    threshold_diff = s_meta.lower_threshold ~= b_meta.lower_threshold;
    year_min_diff = s_meta.year_min ~= b_meta.year_min;
    airborne = strcmp(s_meta.scope, "airborne");
    incl_unid = s_meta.has_unid_token && s_meta.incl_unid;

    if trunc_diff
        name = "Severity ceiling ($\overline{s}$)";
        if s_meta.trunc_value == 1000
            val = "Increase to 1,000 deaths per 10,000";
        elseif s_meta.trunc_value == 10000
            val = "Increase to 10,000 deaths per 10,000";
        else
            val = sprintf("Increase to %g deaths per 10,000", s_meta.trunc_value);
        end
        return;
    elseif threshold_diff
        name = "Severity floor ($\underline{s}$)";
        if s_meta.lower_threshold == 1
            val = "Increase to 1 death per 10,000 per year";
        else
            val = sprintf("Increase to %g deaths per 10,000 per year", s_meta.lower_threshold);
        end
        return;
    elseif year_min_diff
        name = "Pathogen data";
        if s_meta.year_min == 1950
            val = "Novel viral since 1950";
        else
            val = sprintf("Novel viral since %g", s_meta.year_min);
        end
        return;
    elseif airborne
        name = "Pathogen data";
        val = "Airborne novel viral outbreaks";
        return;
    elseif s_meta.year_thresh_only
        name = "Pathogen data";
        val = "All outbreaks since 1900";
        return;
    elseif incl_unid
        name = "Pathogen data";
        val = "Novel + unidentified viral";
        return;
    end
end

function [name, val] = duration_only_labels(baseline_config, run_config)
    name = "";
    val = "";
    if ~isfield(baseline_config, 'duration_dist_config') || ~isfield(run_config, 'duration_dist_config')
        return;
    end
    bd = char(baseline_config.duration_dist_config);
    rd = char(run_config.duration_dist_config);
    if strcmp(bd, rd)
        return;
    end
    bt = duration_stem_trunc_years(bd);
    rt = duration_stem_trunc_years(rd);
    if isnan(bt) || isnan(rt)
        return;
    end
    name = "Duration upper bound ($\overline{d}$)";
    val = sprintf("%g years", rt);
end

function ty = duration_stem_trunc_years(path_or_stem)
    [~, stem, ~] = fileparts(char(path_or_stem));
    tok = regexp(stem, 'trunc(\d+)_', 'tokens', 'once');
    if isempty(tok)
        ty = NaN;
    else
        ty = str2double(tok{1});
    end
end

function s = humanize_scenario_key(k)
    t = strrep(char(k), '_', ' ');
    if ~isempty(t)
        t(1) = upper(t(1));
    end
    s = string(t);
end
