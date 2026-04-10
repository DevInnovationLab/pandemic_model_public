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
    %     (e.g. output/sensitivity/no_mitigation_all).
    %
    % Returns:
    %   annualized_summary_table (table): Table with Variable, Value, and loss columns (cell of structs).
    %   total_summary_table (table): Horizon totals; loss columns through TotalLoss are discounted;
    %     TotalUnmitigatedLossUndiscounted is undiscounted (see estimate_unmitigated_losses).
    %
    % Also writes:
    %   sensitivity_dir/sensitivity_annualized_loss_summary.csv
    %   sensitivity_dir/sensitivity_total_loss_summary.csv

    sensitivity_dir = char(sensitivity_dir);
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    [scenario_ids, scenario_paths] = get_sensitivity_scenarios(sensitivity_dir);

    baseline_config = yaml.loadFile(fullfile(sensitivity_dir, 'baseline', 'job_config.yaml'));
    baseline_arrival_dist = baseline_config.arrival_dist_config;
    baseline_vsl = baseline_config.value_of_death;
    baseline_r = baseline_config.r;
    baseline_y = baseline_config.y;
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

    [vname, vval] = format_names('baseline', 'baseline', baseline_arrival_dist, baseline_vsl, baseline_r, baseline_y);
    mat_file = fullfile(baseline_dir, 'unmitigated_losses.mat');
    S = load(mat_file, 'sim_total_deaths', 'sim_mortality_loss', 'sim_output_loss', ...
        'sim_learning_loss', 'sim_total_loss', 'sim_total_loss_undiscounted');
    [ann_row, tot_row] = build_table_rows_from_sim(S, baseline_r, baseline_periods, vname, vval);
    annualized_summary_table(1, :) = ann_row;
    total_summary_table(1, :) = tot_row;

    for k = 1:length(scenario_ids)
        scenario_id = scenario_ids{k};
        value_dir = scenario_paths{k};
        run_config = yaml.loadFile(fullfile(value_dir, "job_config.yaml"));
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
        [vname, vval] = format_names(var_name, var_value, baseline_arrival_dist, baseline_vsl, baseline_r, baseline_y);
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

function [formatted_name, formatted_value] = format_names(var_name, var_value, baseline_arrival_dist, ...
                                                          baseline_vsl, baseline_r, baseline_y)
    formatted_name = var_name;
    formatted_value = string(var_value);
    b_meta = parse_arrival_dist_fp(baseline_arrival_dist);
    switch var_name
        case "value_of_death"
            formatted_name = "Value of statistical life ($v$)";
            if var_value < baseline_vsl
                formatted_value = sprintf("Reduce to \\$%g million", var_value/1e6);
            elseif var_value > baseline_vsl
                formatted_value = sprintf("Increase to \\$%g million", var_value/1e6);
            end
        case "arrival_dist_config"
            s_meta = parse_arrival_dist_fp(var_value);
            trunc_diff = s_meta.trunc_value ~= b_meta.trunc_value;
            threshold_diff = s_meta.lower_threshold ~= b_meta.lower_threshold;
            year_min_diff = s_meta.year_min ~= b_meta.year_min;
            airborne = strcmp(s_meta.scope, "airborne");
            incl_unid = s_meta.has_unid_token && s_meta.incl_unid;
            if trunc_diff
                % Severity ceiling in deaths per 10,000
                formatted_name = "Severity ceiling ($\overline{s}$)";
                if s_meta.trunc_value == 1000
                    formatted_value = "Increase to 1,000 deaths per 10,000";
                elseif s_meta.trunc_value == 10000
                    formatted_value = "Increase to 10,000 deaths per 10,000";
                else
                    formatted_value = sprintf("Increase to %g deaths per 10,000", s_meta.trunc_value);
                end
            elseif threshold_diff
                % Severity floor in deaths per 10,000 per year
                formatted_name = "Severity floor ($\underline{s}$)";
                if s_meta.lower_threshold == 1
                    formatted_value = "Increase to 1 death per 10,000 per year";
                else
                    formatted_value = sprintf("Increase to %g deaths per 10,000 per year", s_meta.lower_threshold);
                end
            elseif year_min_diff
                % Pathogen data: sample period (e.g. outbreaks since 1950)
                formatted_name = "Pathogen data";
                if s_meta.year_min == 1950
                    formatted_value = "Novel viral since 1950";
                else
                    formatted_value = sprintf("Novel viral since %g", s_meta.year_min);
                end
            elseif airborne
                formatted_name = "Pathogen data";
                formatted_value = "Airborne novel viral outbreaks";
            elseif s_meta.year_thresh_only
                formatted_name = "Pathogen data";
                formatted_value = "All outbreaks since 1900";
            elseif incl_unid
                formatted_name = "Pathogen data";
                formatted_value = "Novel + unidentified viral";
            end
        case "duration_dist_config"
            formatted_name = "Duration upper bound ($\overline{d}$)";
            [~, config_name, ~] = fileparts(var_value);
            config_metadata = split(config_name, "_");
            trunc_value = config_metadata(8);
            formatted_value = sprintf("%g years", trunc_value);
        case "y"
            formatted_name = "Per capita GDP growth rate ($r_g$)";
            if var_value < baseline_y
                formatted_value = sprintf("Reduce to %.1f\\%%", var_value * 100);
            elseif var_value > baseline_y
                formatted_value = sprintf("Increase to %.1f\\%%", var_value * 100);
            end
        case "r"
            formatted_name = "Social discount rate ($r_s$)";
            if var_value < baseline_r
                formatted_value = sprintf("Reduce to %.1f\\%%", var_value * 100);
            elseif var_value > baseline_r
                formatted_value = sprintf("Increase to %.1f\\%%", var_value * 100);
            end
        case "ptrs_pathogen_gamma1"
            formatted_name = "Vaccines always succeed, $\\gamma = 1$";
            formatted_value = "";
        case "baseline"
            formatted_name = "Baseline";
            formatted_value = "";
    end
end
