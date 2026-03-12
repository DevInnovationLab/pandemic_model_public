function [annualized_summary_table, total_summary_table] = build_sensitivity_loss_tables(sensitivity_dir)
    % Build annualized and total loss summary tables from sensitivity run directories.
    %
    % Loads unmitigated loss outputs for baseline and each sensitivity value (from
    % value_dir/unmitigated_losses.mat), annualizes, computes mean and 10/90 percentiles,
    % and writes the summary CSVs. Run aggregate_unmitigated_losses per scenario first
    % if results were chunked.
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
        get_unmitigated_losses_for_dir(baseline_dir, baseline_r, baseline_periods);

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
            [annual_deaths, mortality_loss, economic_loss, learning_loss, total_loss] = ...
                get_unmitigated_losses_for_dir(value_dir, r, periods);
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
    get_unmitigated_losses_for_dir(value_dir, r, periods)
    % Load value_dir/unmitigated_losses.mat (total_* vectors) and return annualized loss vectors.
    mat_file = fullfile(value_dir, 'unmitigated_losses.mat');
    assert(isfile(mat_file), 'No unmitigated_losses.mat in %s. Run estimate_unmitigated_losses then aggregate_unmitigated_losses if chunked.', value_dir);
    S = load(mat_file, 'total_deaths', 'total_mortality_losses', 'total_output_losses', ...
        'total_learning_losses', 'total_total_losses');
    ann = (r * (1 + r)^periods) / ((1 + r)^periods - 1);
    annual_deaths = S.total_deaths ./ periods;
    mortality_losses = S.total_mortality_losses .* ann;
    economic_losses = S.total_output_losses .* ann;
    learning_losses = S.total_learning_losses .* ann;
    total_losses = S.total_total_losses .* ann;
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
                % Intensity floor in deaths per 10,000 per year
                formatted_name = "Intensity floor ($\underline{x}$)";
                if s_meta.lower_threshold == 1
                    formatted_value = "Increase to 1 death per 10,000 per year";
                else
                    formatted_value = sprintf("Increase to %g deaths per 10,000 per year", s_meta.lower_threshold);
                end
            elseif year_min_diff
                % Pathogen data: sample period (e.g. outbreaks since 1950)
                formatted_name = "Pathogen data";
                if s_meta.year_min == 1950
                    formatted_value = "Outbreaks since 1950";
                else
                    formatted_value = sprintf("Outbreaks since %g", s_meta.year_min);
                end
            elseif airborne
                formatted_name = "Pathogen data";
                formatted_value = "Airborne novel viral oubreaks";
            elseif s_meta.year_thresh_only
                formatted_name = "Pathogen data";
                formatted_value = "All outbreaks since 1900";
            elseif incl_unid
                formatted_name = "Pathogen data";
                formatted_value = "Noval + unidentified viral";
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
        case "baseline"
            formatted_name = "Baseline";
            formatted_value = "";
    end
end
