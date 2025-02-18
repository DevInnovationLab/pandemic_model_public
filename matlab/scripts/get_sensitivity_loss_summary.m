function get_sensitivity_loss_summary(sensitivity_dir)
    % Loads and summarizes results from sensitivity analysis, calculating average losses
    % across different sensitivity parameters
    %
    % Args:
    %   sensitivity_dir (str): Path to sensitivity analysis output directory
    %
    % Returns:
    %   None, but saves summary statistics to files in the sensitivity directory

    % Load sensitivity config
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    sensitivity_varData = fieldnames(sensitivity_config.sensitivities);

    % Load baseline config to get reference values
    baseline_config = yaml.loadFile(fullfile(sensitivity_dir, 'baseline', 'job_config.yaml'));
    baseline_vsl = baseline_config.value_of_death;
    baseline_r = baseline_config.r;
    baseline_y = baseline_config.y;

    % First get baseline results from raw directory
    baseline_dir = fullfile(sensitivity_dir, 'baseline', 'raw');

    % Get baseline losses
    [baseline_mortality, baseline_economic, baseline_learning, baseline_total] = ...
        get_losses_for_dir(baseline_dir);

    % Initialize summary table with baseline
    summary_table = table('Size', [1 6], 'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Variable', 'Value', 'MortalityLoss', 'EconomicLoss', 'LearningLoss', 'TotalLoss'};
    [formatted_name, formatted_value] = format_names('baseline', 'baseline', baseline_vsl, baseline_r, baseline_y);
    summary_table(1,:) = {formatted_name, formatted_value, baseline_mortality, baseline_economic, baseline_learning, baseline_total};

    % Process each sensitivity variable
    row_idx = 2;
    for i = 1:length(sensitivity_varData)
        var_name = sensitivity_varData{i};
        var_values = sensitivity_config.sensitivities.(var_name);
        var_dir = fullfile(sensitivity_dir, var_name);

        % Load results for each value
        for j = 1:length(var_values)
            value_dir = fullfile(var_dir, sprintf('value_%d', j));
            run_config = yaml.loadFile(fullfile(value_dir, "job_config.yaml"));
            r = run_config.r;
            periods = run_config.sim_periods;
            [mortality_loss, economic_loss, learning_loss, total_loss] = get_losses_for_dir(raw_dir, r, periods);
            [formatted_name, formatted_value] = format_names(var_name, var_values{j}, baseline_vsl, baseline_r, baseline_y);
            summary_table(row_idx,:) = {formatted_name, formatted_value, mortality_loss, economic_loss, learning_loss, total_loss};
            row_idx = row_idx + 1;
        end
    end

    % Save summary table
    writetable(summary_table, fullfile(sensitivity_dir, 'sensitivity_loss_summary.csv'));
    write_to_latex(summary_table, fullfile(sensitivity_dir, "sensitivity_loss_summary.tex"))
end


% Function to load and process losses for a given directory
function [mortality_loss, economic_loss, learning_loss, total_loss] = get_losses_for_dir(raw_dir, r, periods)
    % Load and process mortality losses
    annualization_factor = (1 - (1 + r).^-periods) ./ r;

    mortality_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_mortality_losses.csv'));
    mortality_loss = mean(sum(mortality_ts, 2)) .* annualization_factor;
    
    % Load and process output losses
    output_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_output_losses.csv'));
    economic_loss = mean(sum(output_ts, 2)) .* annualization_factor;
    
    % Load and process learning losses
    learning_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_learning_losses.csv'));
    learning_loss = mean(sum(learning_ts, 2)) .* annualization_factor;
    
    % Calculate total losses
    total_ts = mortality_ts + output_ts + learning_ts;
    total_loss = mean(sum(total_ts, 2)) .* annualization_factor;
end


function write_to_latex(summary_data, outpath)
    arguments
        summary_data (:,:) table
        outpath (1,1) string
    end

    % Convert losses from dollars to trillions
    summary_data.MortalityLoss = summary_data.MortalityLoss / 1e12;
    summary_data.EconomicLoss = summary_data.EconomicLoss / 1e12;
    summary_data.LearningLoss = summary_data.LearningLoss / 1e12;
    summary_data.TotalLoss = summary_data.TotalLoss / 1e12;

    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');

    % Write LaTeX table header
    fprintf(fileID, '\\begin{table}[h]\n\\centering\n');
    fprintf(fileID, '\\begin{tabular}{l r r r r}\n');
    fprintf(fileID, '\\toprule\n');
    fprintf(fileID, '\\textbf{Scenario} & \\multicolumn{4}{c}{Expected annual pandemic losses (trillion dollars)} \\\\\n');
    fprintf(fileID, '\\cmidrule{2-5}\n');
    fprintf(fileID, '& Mortality & Economic & Learning & Total \\\\\n');
    fprintf(fileID, '& $AV(ML)$ & $AV(OL)$ & $AV(LL)$ & $AV(TL)$ \\\\\n');
    fprintf(fileID, '\\midrule\n');

    % Identify unique scenario categories (Variable column)
    uniqueVars = unique(summary_data.Variable);

    for i = 1:length(uniqueVars)
        % Get rows for the current scenario
        varRows = strcmp(summary_data.Variable, uniqueVars{i});
        varData = summary_data(varRows, :);
        
        % Print main scenario name (not indented)
        fprintf(fileID, '%s \\\\\n', uniqueVars{i});

        for j = 1:height(varData)
            % Format the value with indentation
            fprintf(fileID, '\\hspace{3mm} %s & ', varData.Value{j});
            
            % Print numerical values with one decimal place
            fprintf(fileID, '%.1f & %.1f & %.1f & %.1f \\\\\n', ...
                    varData.MortalityLoss(j), varData.EconomicLoss(j), ...
                    varData.LearningLoss(j), varData.TotalLoss(j));
        end
    end

    % Write LaTeX table footer
    fprintf(fileID, '\\bottomrule\n\\end{tabular}\n');
    fprintf(fileID, '\\caption{Expected annual global pandemic losses}\n');
    fprintf(fileID, '\\label{tab:pandemic_losses}\n');
    fprintf(fileID, '\\end{table}\n');

    % Close the file
    fclose(fileID);

    disp('LaTeX table successfully written to pandemic_losses_table.tex');
end


function [formatted_name, formatted_value] = format_names(var_name, var_value, baseline_vsl, baseline_r, baseline_y)
    % Maps sensitivity variable names and values to nicely formatted strings for tables
    %
    % Args:
    %   var_name (string): Name of sensitivity variable
    %   var_value: Value of sensitivity variable (can be string or numeric)
    %   baseline_vsl (double): Baseline value of statistical life
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
            formatted_name = "Value of statistical life (VSL)";
            if var_value < baseline_vsl
                formatted_value = sprintf("Reduce to \\$%g million", var_value/1e6);
            elseif var_value > baseline_vsl
                formatted_value = sprintf("Increase to \\$%g million", var_value/1e6);
            end
        case "severity_dist_config"
            formatted_name = "Severity distribution";
            if contains(var_value, "half_arrival")
                formatted_value = "Halve arrival rate";
            elseif contains(var_value, "double_arrival")
                formatted_value = "Double arrival rate";
            elseif contains(var_value, "truncate_half")
                formatted_value = "Halve upper truncation";
            end
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