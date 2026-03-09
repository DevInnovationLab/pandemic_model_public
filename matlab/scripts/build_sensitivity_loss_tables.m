function [annualized_summary_table, total_summary_table] = build_sensitivity_loss_tables(sensitivity_dir)
    % Build annualized and total loss summary tables from sensitivity run directories.
    %
    % Loads unmitigated loss outputs for baseline and each sensitivity value, computes
    % mean and 10/90 percentiles, and writes the summary CSVs. Loads from
    % sensitivity_dir/processed/*_unmitigated_losses_summary.mat when present (after
    % agg_sensitivity_unmitigated_losses), otherwise from value_dir/unmitigated_losses.mat.
    %
    % Args:
    %   sensitivity_dir (char or string): Path to sensitivity output directory
    %     (e.g. output/sensitivity/no_mitigation_all).
    %
    % Returns:
    %   annualized_summary_table (table): Table with Variable, Value, and loss columns (cell of structs).
    %   total_summary_table (table): Table with Variable, Value, and total loss columns (cell of structs).
    %
    % Also writes:
    %   sensitivity_dir/sensitivity_annualized_loss_summary.csv
    %   sensitivity_dir/sensitivity_total_loss_summary.csv

    sensitivity_dir = char(sensitivity_dir);
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    sensitivity_varData = fieldnames(sensitivity_config.sensitivities);

    baseline_config = yaml.loadFile(fullfile(sensitivity_dir, 'baseline', 'job_config.yaml'));
    baseline_arrival_dist = baseline_config.arrival_dist_config;
    baseline_vsl = baseline_config.value_of_death;
    baseline_r = baseline_config.r;
    baseline_y = baseline_config.y;
    baseline_periods = baseline_config.sim_periods;
    baseline_dir = fullfile(sensitivity_dir, 'baseline');

    [baseline_deaths, baseline_mortality, baseline_economic, baseline_learning, baseline_total] = ...
        get_unmitigated_losses_for_dir(baseline_dir, baseline_r, baseline_periods, sensitivity_dir, 'baseline');

    annualized_summary_table = table('Size', [1 7], ...
        'VariableTypes', {'string', 'string', 'cell', 'cell', 'cell', 'cell', 'cell'});
    annualized_summary_table.Properties.VariableNames = ...
        {'Variable', 'Value', 'AnnualDeaths', 'MortalityLoss', 'EconomicLoss', 'LearningLoss', 'TotalLoss'};
    [formatted_name, formatted_value] = format_names('baseline', 'baseline', baseline_arrival_dist, ...
                                                     baseline_vsl, baseline_r, baseline_y);
    annualized_summary_table(1,:) = {...
        formatted_name, formatted_value, ...
        {get_mean_and_percentiles(baseline_deaths)}, ...
        {get_mean_and_percentiles(baseline_mortality)}, ...
        {get_mean_and_percentiles(baseline_economic)}, ...
        {get_mean_and_percentiles(baseline_learning)}, ...
        {get_mean_and_percentiles(baseline_total)}, ...
    };

    total_summary_table = table('Size', [1 7], ...
        'VariableTypes', {'string', 'string', 'cell', 'cell', 'cell', 'cell', 'cell'});
    total_summary_table.Properties.VariableNames = ...
        {'Variable', 'Value', 'TotalDeaths', 'TotalMortalityLoss', 'TotalEconomicLoss', 'TotalLearningLoss', 'TotalLoss'};
    baseline_annualization_factor = (baseline_r * (1 + baseline_r)^baseline_periods) / ((1 + baseline_r)^baseline_periods - 1);
    total_summary_table(1,:) = {...
        formatted_name, formatted_value, ...
        {get_mean_and_percentiles(baseline_deaths * baseline_periods)}, ...
        {get_mean_and_percentiles(baseline_mortality / baseline_annualization_factor)}, ...
        {get_mean_and_percentiles(baseline_economic / baseline_annualization_factor)}, ...
        {get_mean_and_percentiles(baseline_learning / baseline_annualization_factor)}, ...
        {get_mean_and_percentiles(baseline_total / baseline_annualization_factor)}, ...
    };

    row_idx = 2;
    for i = 1:length(sensitivity_varData)
        var_name = sensitivity_varData{i};
        var_values = sensitivity_config.sensitivities.(var_name);
        var_dir = fullfile(sensitivity_dir, var_name);
        for j = 1:length(var_values)
            value_dir = fullfile(var_dir, sprintf('value_%d', j));
            run_config = yaml.loadFile(fullfile(value_dir, "job_config.yaml"));
            r = run_config.r;
            periods = run_config.sim_periods;
            scenario_id = sprintf('%s_value_%d', var_name, j);
            [annual_deaths, mortality_loss, economic_loss, learning_loss, total_loss] = ...
                get_unmitigated_losses_for_dir(value_dir, r, periods, sensitivity_dir, scenario_id);
            [formatted_name, formatted_value] = format_names(var_name, var_values{j}, baseline_arrival_dist, baseline_vsl, baseline_r, baseline_y);

            annualized_summary_table(row_idx,:) = {...
                formatted_name, formatted_value, ...
                {get_mean_and_percentiles(annual_deaths)}, ...
                {get_mean_and_percentiles(mortality_loss)}, ...
                {get_mean_and_percentiles(economic_loss)}, ...
                {get_mean_and_percentiles(learning_loss)}, ...
                {get_mean_and_percentiles(total_loss)}, ...
            };

            annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);
            total_summary_table(row_idx,:) = {...
                formatted_name, formatted_value, ...
                {get_mean_and_percentiles(annual_deaths * periods)}, ...
                {get_mean_and_percentiles(mortality_loss / annualization_factor)}, ...
                {get_mean_and_percentiles(economic_loss / annualization_factor)}, ...
                {get_mean_and_percentiles(learning_loss / annualization_factor)}, ...
                {get_mean_and_percentiles(total_loss / annualization_factor)}, ...
            };
            row_idx = row_idx + 1;
        end
    end

    % Write CSVs (means only) so write_unmitigated_loss_figures and others can use them.
    annualized_csv = summary_table_to_csv(annualized_summary_table);
    total_csv = summary_table_to_csv(total_summary_table);
    writetable(annualized_csv, fullfile(sensitivity_dir, 'sensitivity_annualized_loss_summary.csv'));
    writetable(total_csv, fullfile(sensitivity_dir, 'sensitivity_total_loss_summary.csv'));
    fprintf('Sensitivity loss tables and CSVs written to %s\n', sensitivity_dir);
end

function csv_table = summary_table_to_csv(summary_table)
    function m = get_mean(cellval)
        m = cellval{1}.mean;
    end
    csv_data = cell(size(summary_table));
    for row = 1:height(summary_table)
        csv_data{row,1} = summary_table{row,1};
        csv_data{row,2} = summary_table{row,2};
        csv_data{row,3} = get_mean(summary_table{row,3});
        csv_data{row,4} = get_mean(summary_table{row,4});
        csv_data{row,5} = get_mean(summary_table{row,5});
        csv_data{row,6} = get_mean(summary_table{row,6});
        csv_data{row,7} = get_mean(summary_table{row,7});
    end
    csv_table = cell2table(csv_data, 'VariableNames', summary_table.Properties.VariableNames);
end

function [annual_deaths, mortality_losses, economic_losses, learning_losses, total_losses] = ...
    get_unmitigated_losses_for_dir(value_dir, r, periods, sensitivity_dir, scenario_id)
    % Load unmitigated loss vectors from processed/ (if present) or value_dir/unmitigated_losses.mat.
    if nargin >= 5 && ~isempty(sensitivity_dir) && ~isempty(scenario_id)
        processed_path = fullfile(sensitivity_dir, 'processed', [scenario_id '_unmitigated_losses_summary.mat']);
        if isfile(processed_path)
            S = load(processed_path, 'annual_deaths', 'mortality_losses', 'economic_losses', ...
                'learning_losses', 'total_losses');
            annual_deaths = S.annual_deaths;
            mortality_losses = S.mortality_losses;
            economic_losses = S.economic_losses;
            learning_losses = S.learning_losses;
            total_losses = S.total_losses;
            return;
        end
    end
    annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);
    mat_file = fullfile(value_dir, 'unmitigated_losses.mat');
    assert(isfile(mat_file), 'No unmitigated losses MAT file found in %s (and no processed summary)', value_dir);
    S = load(mat_file, 'deaths', 'mortality_losses', 'output_losses', 'learning_losses', 'total_losses');
    annual_deaths = sum(S.deaths, 2) ./ periods;
    mortality_losses = sum(S.mortality_losses, 2) .* annualization_factor;
    economic_losses = sum(S.output_losses, 2) .* annualization_factor;
    learning_losses = sum(S.learning_losses, 2) .* annualization_factor;
    total_losses = sum(S.total_losses, 2) .* annualization_factor;
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
            formatted_name = "Value of statistical life (VSL)";
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
                formatted_name = "Severity upper bound ($\overline{s}$)";
                formatted_value = sprintf("%g SU", s_meta.trunc_value);
            elseif threshold_diff
                formatted_name = "Lower severity threshold ($\underline{s}$)";
                formatted_value = sprintf("%g SU", s_meta.lower_threshold);
            elseif year_min_diff
                formatted_name = "Sample period";
                formatted_value = sprintf("Outbreaks after %g only", s_meta.year_min);
            elseif airborne
                formatted_name = "Pathogen types";
                formatted_value = "Airborne pathogens only";
            elseif s_meta.year_thresh_only
                formatted_name = "Pathogen types";
                formatted_value = "All outbreaks since 1900";
            elseif incl_unid
                formatted_name = "Pathogen types";
                formatted_value = "Include unidentified pathogens";
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
            formatted_name = "Social discount rate $r_s$";
            if var_value < baseline_r
                formatted_value = sprintf("Reduce to %.1f\\%%", var_value * 100);
            elseif var_value > baseline_r
                formatted_value = sprintf("Increase to %.1f\\%%", var_value * 100);
            end
        case "baseline"
            formatted_name = "Baseline";
            formatted_value = "";
    end
end
