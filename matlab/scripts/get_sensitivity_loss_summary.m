function get_sensitivity_loss_summary(sensitivity_dir)
    % Loads and summarizes results from sensitivity analysis, calculating average losses
    % across different sensitivity parameters
    %
    % Args:
    %   sensitivity_dir (str): Path to sensitivity analysis output directory
    %
    % Returns:
    %   None, but saves summary statsistics to files in the sensitivity directory

    % Load sensitivity config
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    sensitivity_varData = fieldnames(sensitivity_config.sensitivities);

    % Load baseline config to get reference values
    baseline_config = yaml.loadFile(fullfile(sensitivity_dir, 'baseline', 'job_config.yaml'));
    baseline_vsl = baseline_config.value_of_death;
    baseline_r = baseline_config.r;
    baseline_y = baseline_config.y;
    baseline_periods = baseline_config.sim_periods;

    % First get baseline results from raw directory
    baseline_dir = fullfile(sensitivity_dir, 'baseline', 'raw');

    % Get baseline losses
    [baseline_mortality, baseline_economic, baseline_learning, baseline_total] = ...
        get_losses_for_dir(baseline_dir, baseline_r, baseline_periods);

    % Initialize summary table with baseline
    summary_table = table('Size', [1 6], 'VariableTypes', {'string', 'string', 'cell', 'cell', 'cell', 'cell'});
    summary_table.Properties.VariableNames = {...
        'Variable', 'Value', 'MortalityLoss', 'EconomicLoss', 'LearningLoss', 'TotalLoss'};
    [formatted_name, formatted_value] = format_names('baseline', 'baseline', baseline_vsl, baseline_r, baseline_y);
    summary_table(1,:) = {...
        formatted_name,...
        formatted_value, ...
        {get_mean_and_iqr(baseline_mortality)}, ...
        {get_mean_and_iqr(baseline_economic)}, ...
        {get_mean_and_iqr(baseline_learning)}, ...
        {get_mean_and_iqr(baseline_total)}...
    };

    % Process each sensitivity variable
    row_idx = 2;
    for i = 1:length(sensitivity_varData)
        var_name = sensitivity_varData{i};
        var_values = sensitivity_config.sensitivities.(var_name);
        var_dir = fullfile(sensitivity_dir, var_name);

        % Load results for each value
        for j = 1:length(var_values)
            value_dir = fullfile(var_dir, sprintf('value_%d', j));
            raw_dir = fullfile(value_dir, "raw");
            run_config = yaml.loadFile(fullfile(value_dir, "job_config.yaml"));
            r = run_config.r;
            periods = run_config.sim_periods;
            [mortality_loss, economic_loss, learning_loss, total_loss] = get_losses_for_dir(raw_dir, r, periods);
            [formatted_name, formatted_value] = format_names(var_name, var_values{j}, baseline_vsl, baseline_r, baseline_y);
            summary_table(row_idx,:) = {...
                formatted_name, ...
                formatted_value, ...
                {get_mean_and_iqr(mortality_loss)}, ...
                {get_mean_and_iqr(economic_loss)}, ...
                {get_mean_and_iqr(learning_loss)}, ...
                {get_mean_and_iqr(total_loss)} ...
            };
            row_idx = row_idx + 1;
        end
    end

    % Save summary table
    writetable(summary_table, fullfile(sensitivity_dir, 'sensitivity_loss_summary.csv'));
    write_to_latex(summary_table, fullfile(sensitivity_dir, "sensitivity_loss_summary.tex"))
end


% Function to load and process losses for a given directory
function [mortality_losses, economic_losses, learning_losses, total_losses] = get_losses_for_dir(raw_dir, r, periods)
    % Load and process mortality losses
    annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);

    mortality_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_mortality_losses.csv'));
    mortality_losses = sum(mortality_ts, 2) .* annualization_factor;
    
    % Load and process output losses
    output_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_output_losses.csv'));
    economic_losses = sum(output_ts, 2) .* annualization_factor;
    
    % Load and process learning losses
    learning_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_learning_losses.csv'));
    learning_losses = sum(learning_ts, 2) .* annualization_factor;
    
    % Calculate total losses
    total_ts = mortality_ts + output_ts + learning_ts;
    total_losses = sum(total_ts, 2) .* annualization_factor;
end


function stats = get_mean_and_iqr(sample)
    % Returns a struct with mean, 25th, and 75th percentiles

    assert(isvector(sample)); % Throw error is matrix is passed.
    stats.mean = mean(sample) / 1e12; % convert to trillions
    pctiles = prctile(sample, [25 75]) / 1e12;
    stats.p25 = pctiles(1);
    stats.p75 = pctiles(2);
end


function write_to_latex(summary_data, outpath)
    arguments
        summary_data (:,:) table
        outpath (1,1) string
    end

    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');

    % Write LaTeX table header
    fprintf(fileID, '\\begin{table}[h]\n\\centering\n');
    fprintf(fileID, '\\begin{tabular}{l r r r c}\n');
    fprintf(fileID, '\\toprule\n');
    fprintf(fileID, 'Scenario & \\multicolumn{4}{c}{Expected annualized pandemic losses (\\$ trillion)} \\\\\n');
    fprintf(fileID, '\\cmidrule{2-5}\n');
    fprintf(fileID, '& Mortality & Economic & Learning & Total \\\\\n');
    fprintf(fileID, '& $AV\\left(\\bar{ML}\\right)$ & $AV\\left(\\bar{OL}\\right)$ & $AV\\left(\\bar{LL}\\right)$ & $AV\\left(\\bar{TL}\\right)$ \\\\\n');
    fprintf(fileID, '\\midrule\n');
    % Identify unique scenario categories (Variable column)
    uniqueVars = unique(summary_data.Variable);
    baselineIdx = strcmp(uniqueVars, 'Baseline');
    uniqueVars = [uniqueVars(baselineIdx); uniqueVars(~baselineIdx)];

    for i = 1:length(uniqueVars)
        varRows = strcmp(summary_data.Variable, uniqueVars{i});
        varData = summary_data(varRows, :);

        % Print main scenario name (not indented)
        if strcmp(uniqueVars{i}, 'Baseline')
            fprintf(fileID, '%s ', uniqueVars{i});
        else
            fprintf(fileID, '%s \\\\\n', uniqueVars{i});
        end

        for j = 1:height(varData)
            fprintf(fileID, '\\hspace{3mm} %s & ', varData.Value{j});

            % For each loss type, print mean and IQR in smaller text
            for k = 1:4
                stat = varData{j, 2+k}{1}; % cell containing struct
                cellstr = sprintf('\\makecell{%.1f \\\\ \\footnotesize [%.1f, %.1f]}', ...
                    stat.mean, stat.p25, stat.p75);
                if k < 4
                    fprintf(fileID, '%s & ', cellstr);
                else
                    fprintf(fileID, '%s \\\\\n', cellstr);
                end
            end
        end
    end

    % Write LaTeX table footer
    fprintf(fileID, '\\bottomrule\n\\end{tabular}\n');
    fprintf(fileID, '\\caption{Expected global pandemic losses. For each cell, the top number represents the mean value and the numbers in brackets below show the interquartile range (25th to 75th percentiles).}\n');
    fprintf(fileID, '\\label{tab:pandemic_losses}\n');
    fprintf(fileID, '\\end{table}\n');

    fclose(fileID);
    disp('LaTeX table successfully written to pandemic_losses_table.tex');
end


function [formatted_name, formatted_value] = format_names(var_name, var_value, baseline_vsl, baseline_r, baseline_y)
    % Maps sensitivity variable names and values to nicely formatted strings for tables
    %
    % Args:
    %   var_name (string): Name of sensitivity variable
    %   var_value: Value of sensitivity variable (can be string or numeric)
    %   baseline_vsl (double): Baseline value of statsistical life
    %   baseline_r (double): Baseline discount rate
    %   baseline_y (double): Baseline GDP growth rate
    %
    % Returns:
    %   formatted_name (string): Formatted variable name
    %   formatted_value (string): Formatted value

    % Initialize formatted strings
    formatted_name = var_name;
    formatted_value = string(var_value);

    % Format variable names
    switch var_name
        case "value_of_death"
            formatted_name = "Value of statsistical life (VSL)";
            if var_value < baseline_vsl
                formatted_value = sprintf("Reduce to \\$%g million", var_value/1e6);
            elseif var_value > baseline_vsl
                formatted_value = sprintf("Increase to \\$%g million", var_value/1e6);
            end
        case "arrival_dist_config"
            formatted_name = "Intensity upper bound";
            [~, config_name, ~] = fileparts(var_value);
            config_metadata = split(config_name, "_");
            trunc_value = config_metadata(6);
            formatted_value = sprintf("%s SU", trunc_value);
        case "duration_dist_config"
            formatted_name = "Duration upper bound";
            [~, config_name, ~] = fileparts(var_value);
            config_metadata = split(config_name, "_");
            trunc_value = config_metadata(6);
            formatted_value = sprintf("%s years", trunc_value);
        case "y"
            formatted_name = "GDP growth rate $y$";
            if var_value < baseline_y
                formatted_value = sprintf("Reduce to %.1f\\%%", var_value * 100);
            elseif var_value > baseline_y
                formatted_value = sprintf("Increase to %.1f\\%%", var_value * 100);
            end
        case "r"
            formatted_name = "Social discount rate $r$";
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