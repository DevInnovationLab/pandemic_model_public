function get_baseline_vaccine_sensitivity_table(sensitivity_dir)
    %% Generate summary table for sensitivity analysis results.
    %   To be used for the all risk
    %
    % Args:
    %
    % This function:
    % 1. Loads results from all sensitivity runs
    % 2. Calculates vaccine benefits for each scenario
    % 3. Creates a summary table with baseline and ranges
    % 4. Outputs the table in CSV and LaTeX formats
    
    % Load sensitivity configuration
    sensitivity_dir = char(sensitivity_dir);
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    
    % Load baseline vaccine benefits from aggregated results
    baseline_results_path = fullfile(sensitivity_dir, 'processed', 'baseline_benefits_summary.mat');
    baseline_data = load(baseline_results_path, 'mean_benefits', 'run_config');
    baseline_benefits = baseline_data.mean_benefits;
    baseline_config = baseline_data.run_config;
    
    % Initialize summary table
    parameters = fieldnames(sensitivity_config.sensitivities);
    num_rows = length(parameters) + 1; % +1 for baseline

    % Add columns for percent differences and max absolute percent difference
    summary_table = table('Size', [num_rows, 9], ...
                         'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                         'VariableNames', {'Parameter', 'BaselineValue', 'LowValue', 'HighValue', 'LowBenefit', 'HighBenefit', ...
                                           'LowBenefitPctDiff', 'HighBenefitPctDiff', 'MaxAbsPctDiff'});

    % Add baseline row (percent differences are zero for baseline)
    summary_table(1,:) = {'Baseline', NaN, NaN, NaN, baseline_benefits, baseline_benefits, 0, 0, 0};

    % Process each parameter
    for i = 1:length(parameters)
        param_name = parameters{i};
        param_entry = sensitivity_config.sensitivities.(param_name);

        if sensitivity_entry_is_multiparameter(param_entry)
            % Single scenario with multiple overridden fields (see expand_sensitivities).
            benefits_path = fullfile(sensitivity_dir, 'processed', sprintf('%s_benefits_summary.mat', param_name));
            bd = load(benefits_path, 'mean_benefits');
            variant_benefits = bd.mean_benefits;
            low_benefits = variant_benefits;
            high_benefits = variant_benefits;
            low_benefit_pct_diff = 100 * (low_benefits - baseline_benefits) / baseline_benefits;
            high_benefit_pct_diff = low_benefit_pct_diff;
            max_abs_pct_diff = abs(low_benefit_pct_diff);
            % Placeholders; LaTeX uses baseline_config and param_entry for display.
            summary_table(i+1,:) = {param_name, NaN, NaN, NaN, ...
                low_benefits, high_benefits, ...
                low_benefit_pct_diff, high_benefit_pct_diff, max_abs_pct_diff};
            continue
        end

        % One-parameter sweep: value_1 and value_2 runs
        % Get baseline value for this parameter
        baseline_value = baseline_config.(param_name);

        if strcmp(param_name, 'duration_dist_config')
            parts = split(baseline_value, "_");
            baseline_value = str2double(parts{10});
        end

        % Load benefits from aggregated results
        value_1_path = fullfile(sensitivity_dir, 'processed', sprintf('%s_value_1_benefits_summary.mat', param_name));
        value_2_path = fullfile(sensitivity_dir, 'processed', sprintf('%s_value_2_benefits_summary.mat', param_name));
        
        value_1_data = load(value_1_path, 'mean_benefits', 'run_config');
        value_2_data = load(value_2_path, 'mean_benefits', 'run_config');
        
        benefits_value_1 = value_1_data.mean_benefits;
        benefits_value_2 = value_2_data.mean_benefits;
        
        % Get parameter values from job configs
        param_value_1 = value_1_data.run_config.(param_name);
        param_value_2 = value_2_data.run_config.(param_name);
        
        % Handle duration_dist_config specially
        if strcmp(param_name, 'duration_dist_config')
            parts = split(param_value_1, "_");
            param_value_1 = str2double(parts{10});
            parts = split(param_value_2, "_");
            param_value_2 = str2double(parts{10});
        end
        % Order by parameter value (low/high) and benefits (low/high) independently
        if param_value_1 < param_value_2
            low_value = param_value_1;
            high_value = param_value_2;
        else
            low_value = param_value_2;
            high_value = param_value_1;
        end
        
        if benefits_value_1 < benefits_value_2
            low_benefits = benefits_value_1;
            high_benefits = benefits_value_2;
        else
            low_benefits = benefits_value_2;
            high_benefits = benefits_value_1;
        end

        % Calculate percent differences from baseline
        low_benefit_pct_diff = 100 * (low_benefits - baseline_benefits) / baseline_benefits;
        high_benefit_pct_diff = 100 * (high_benefits - baseline_benefits) / baseline_benefits;
        max_abs_pct_diff = max(abs([low_benefit_pct_diff, high_benefit_pct_diff]));

        % Add to summary table
        summary_table(i+1,:) = {param_name, baseline_value, low_value, high_value, ...
                                low_benefits, high_benefits, ...
                                low_benefit_pct_diff, high_benefit_pct_diff, max_abs_pct_diff};
    end
    disp(summary_table)

    % Save summary table as CSV
    writetable(summary_table, fullfile(sensitivity_dir, 'sensitivity_summary.csv'));

    % Generate LaTeX table
    generate_latex_table(summary_table, fullfile(sensitivity_dir, 'sensitivity_summary.tex'), baseline_benefits, ...
        sensitivity_config, baseline_config);
    
    fprintf('Sensitivity summary generated and saved to %s\n', sensitivity_dir);
end


function formatted_name = format_parameter_name(param_name)
    %% Format parameter names for display in the table
    %   Consider moving elsewhere
    %
    % Args:
    %   param_name (string): Raw parameter name
    %
    % Returns:
    %   formatted_name (string): Formatted parameter name
    
    % Map of parameter names to their formatted versions
    param_map = containers.Map();
    param_map('value_of_death') = 'Value of statistical life (VSL)';
    param_map('y') = 'GDP growth rate';
    param_map('r') = 'Social discount rate';
    param_map('gamma') = 'Harm mitigated by vaccine';
    param_map('capacity_kept') = 'Surge capacity kept after pandemic';
    param_map('k_m') = 'mRNA capacity unit cost';
    param_map('k_o') = 'Traditional capacity unit cost';
    param_map('c_m') = 'mRNA vaccine unit cost';
    param_map('c_o') = 'Traditional vaccine unit cost';
    param_map('epsilon') = 'Decreasing returns to surge capacity';
    param_map('f_m') = 'mRNA capacity successful';
    param_map('f_o') = 'Traditional capacity successful';
    param_map('g_m') = 'mRNA capacity repurposable';
    param_map('g_o') = 'Traditional capacity repurposable';
    param_map('tau_a') = 'Time to vaccine without prototype';
    param_map('tau_m') = 'Repurposing delay mRNA';
    param_map('tau_o') = 'Repurposing delay traditional';
    param_map('rental_share') = 'Advance capacity rental share';
    param_map('false_positive_rate') = 'False positive rate';
    param_map('duration_dist_config') = 'Max pandemic duration (years)';
    param_map('max_capacity') = 'Max capacity (annual courses)';
    param_map('delta') = 'Annual maintenance cost (\% of capital value)';
    param_map('response_threshold_path') = 'Response threshold (deaths / 10,000)';
    param_map('ptrs_pathogen_gamma1') = 'Vaccines always succeed and $\gamma = 1$';
    
    % Return formatted name if available, otherwise return original
    if isKey(param_map, param_name)
        formatted_name = param_map(param_name);
    else
        formatted_name = param_name;
    end
end


function generate_latex_table(summary_table, output_path, baseline_benefits, sensitivity_config, baseline_config)
    %% Generate LaTeX table from sensitivity analysis results
    %
    % Args:
    %   summary_table (table): Table with sensitivity analysis results
    %   output_path (string): Path to save the LaTeX table
    %   baseline_benefits (double): Baseline benefits value
    %   sensitivity_config (struct): Loaded sensitivity YAML (sensitivities field used)
    %   baseline_config (struct): Baseline run_config for default column text
    % Open file for writing
    fileID = fopen(output_path, 'w');
    
    % Write LaTeX table header
    fprintf(fileID, '\\begin{table}[htbp]\n');
    fprintf(fileID, '\\centering\n');
    fprintf(fileID, '\\caption{Benefits from baseline vaccine response.}\n');
    fprintf(fileID, '\\begin{tabular}{p{5.5cm}ccc}\n');
    fprintf(fileID, '\\hline\\hline\n');
    fprintf(fileID, 'Parameter & Default & Sensitivity & Net present value \\\\\n');
    fprintf(fileID, ' & & & (\\$ trillion) \\\\\n');
    fprintf(fileID, '\\hline\n');
    
    % Write baseline row
    fprintf(fileID, '\\textbf{Default parameters} & & & \\textbf{%.1f} \\\\\n', baseline_benefits/1e12);

    % Parameters that should be displayed as percentages
    percentage_params = {'y', 'r', 'gamma', 'theta', 'f_m', 'f_o', 'g_m', 'g_o', 'rental_share', 'capacity_kept'};
    
    % Write parameter rows
    for i = 2:height(summary_table)
        raw_param = summary_table.Parameter{i};
        param = format_parameter_name(raw_param);
        param_entry = sensitivity_config.sensitivities.(raw_param);

        if sensitivity_entry_is_multiparameter(param_entry)
            default_str = format_multiparameter_baseline_display(param_entry, baseline_config);
            variant_str = format_multiparameter_variant_display(param_entry);
            benefit_trillion = summary_table.LowBenefit(i) / 1e12;
            if isnan(benefit_trillion)
                fprintf(fileID, '%s & %s & %s & -- \\\\\n', param, default_str, variant_str);
            else
                fprintf(fileID, '%s & %s & %s & %.1f \\\\\n', ...
                    param, default_str, variant_str, benefit_trillion);
            end
            continue
        end

        baseline_val = format_value(summary_table.BaselineValue(i), raw_param);
        low_val = summary_table.LowValue(i);
        high_val = summary_table.HighValue(i);
        low_benefit = summary_table.LowBenefit(i)/1e12;
        high_benefit = summary_table.HighBenefit(i)/1e12;
        
        % Only add units to first and last values in range
        if any(strcmp(raw_param, percentage_params))
            fprintf(fileID, '%s & %s & %.0f--%.0f\\%% & %.1f--%.1f \\\\\n', ...
                param, baseline_val, low_val*100, high_val*100, low_benefit, high_benefit);
        elseif contains(raw_param, 'tau')
            fprintf(fileID, '%s & %s & %.0f--%.0f months & %.1f--%.1f \\\\\n', ...
                param, baseline_val, low_val, high_val, low_benefit, high_benefit);
        elseif startsWith(raw_param, 'k_') || startsWith(raw_param, 'c_')
            % Print dollars with up to 2 decimals, but display as integer if possible
            if mod(low_val,1)==0 && mod(high_val,1)==0
                fmt = '%s & %s & \\$%d--%d & %.1f--%.1f \\\\\n';
                fprintf(fileID, fmt, param, baseline_val, round(low_val), round(high_val), low_benefit, high_benefit);
            else
                fmt = '%s & %s & \\$%.2f--%.2f & %.1f--%.1f \\\\\n';
                fprintf(fileID, fmt, param, baseline_val, low_val, high_val, low_benefit, high_benefit);
            end
        else
            fprintf(fileID, '%s & %s & %g--%g & %.1f--%.1f \\\\\n', ...
                param, baseline_val, low_val, high_val, low_benefit, high_benefit);
        end
    end
    
    % Write table footer
    fprintf(fileID, '\\hline\\hline\n');
    fprintf(fileID, '\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:sensitivity_analysis}\n');
    fprintf(fileID, '\\end{table}\n');
    
    % Close file
    fclose(fileID);
end


function formatted_value = format_value(value, param_name)
    %% Format parameter values appropriately based on parameter type
    %
    % Args:
    %   value (double): Parameter value to format
    %   param_name (string): Raw parameter name (not formatted)
    %
    % Returns:
    %   formatted_value (string): Formatted value string
    
    % Parameters that should be displayed as percentages
    percentage_params = {'y', 'r', 'gamma', 'theta', 'f_m', 'f_o', 'g_m', 'g_o', 'rental_share', 'capacity_kept'};
    
    % Parameters that should be displayed in millions
    million_params = {'value_of_death'};
    
    % Format based on parameter type
    if any(strcmp(param_name, percentage_params))
        formatted_value = sprintf('%.0f\\%%', value * 100);
    elseif any(strcmp(param_name, million_params))
        formatted_value = sprintf('\\$%.1f million', value/1e6);
    elseif contains(param_name, 'tau')
        formatted_value = sprintf('%.0f months', value);
    elseif startsWith(param_name, 'k_') || startsWith(param_name, 'c_')
        formatted_value = sprintf('\\$%.0f', value);
    elseif strcmp(param_name, "duration_dist_config")
        formatted_value = sprintf('%g years', value);
    else
        formatted_value = sprintf('%g', value);
    end
end


function tf = sensitivity_entry_is_multiparameter(val)
    % True if sensitivity YAML entry is a multi-parameter override (struct), per expand_sensitivities.
    tf = isstruct(val) && ~isempty(fieldnames(val));
end


function s = format_multiparameter_baseline_display(override_struct, baseline_config)
    % Build default-column text for fields touched by a multi-parameter sensitivity scenario.
    fields = fieldnames(override_struct);
    parts = cell(length(fields), 1);
    for k = 1:length(fields)
        fn = fields{k};
        if isfield(baseline_config, fn)
            parts{k} = format_multiparameter_field_display(fn, baseline_config.(fn));
        else
            parts{k} = fn;
        end
    end
    s = strjoin(parts, '; ');
end


function s = format_multiparameter_variant_display(override_struct)
    % Build sensitivity-column text from the override struct (scenario values).
    fields = fieldnames(override_struct);
    parts = cell(length(fields), 1);
    for k = 1:length(fields)
        fn = fields{k};
        parts{k} = format_multiparameter_field_display(fn, override_struct.(fn));
    end
    s = strjoin(parts, '; ');
end


function s = format_multiparameter_field_display(field_name, value)
    % Format one field for LaTeX table cells (sentence case labels).
    if strcmp(field_name, 'ptrs_pathogen')
        s = format_ptrs_pathogen_cell(value);
    elseif strcmp(field_name, 'gamma') && isnumeric(value)
        s = sprintf('Gamma %.0f\\%%', value * 100);
    elseif isstring(value) || ischar(value)
        s = sprintf('%s', strip(string(value)));
    elseif isnumeric(value) && isscalar(value)
        s = sprintf('%g', value);
    else
        s = char(string(value));
    end
end


function s = format_ptrs_pathogen_cell(path_spec)
    % Short PTRS table label for LaTeX (basename, underscores escaped).
    p = char(path_spec);
    [~, base, ~] = fileparts(p);
    if contains(lower(base), 'always_succeed')
        s = 'PTRs: vaccines always succeed';
    else
        base_tex = strrep(base, '_', '\_');
        s = ['PTRs \texttt{' base_tex '}'];
    end
end
