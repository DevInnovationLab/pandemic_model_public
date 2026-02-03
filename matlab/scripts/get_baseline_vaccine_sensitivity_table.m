function get_baseline_vaccine_sensitivity_table()
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
    sensitivity_dir = "./output/sensitivity/baseline_vaccine_program";
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    
    % Load baseline configuration to get reference values
    baseline_config = yaml.loadFile(fullfile(sensitivity_dir, 'baseline', 'job_config.yaml'));
    
    % Calculate baseline vaccine benefits
    baseline_benefits = calculate_vaccine_benefits(fullfile(sensitivity_dir, 'baseline'));
    
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
        param_values = sensitivity_config.sensitivities.(param_name);
        param_dir = fullfile(sensitivity_dir, param_name);

        % Get baseline value for this parameter
        baseline_value = baseline_config.(param_name);

        if strcmp(param_name, 'duration_dist_config')
            parts = split(baseline_value, "_");
            baseline_value = parts(10);
        end

        % Calculate benefits for low and high values
        benefits_value_1 = calculate_vaccine_benefits(fullfile(param_dir, 'value_1'));
        benefits_value_2 = calculate_vaccine_benefits(fullfile(param_dir, 'value_2'));

        % Determine which benefit is low/high
        if benefits_value_1 < benefits_value_2
            low_benefits = benefits_value_1;
            high_benefits = benefits_value_2;
        else
            low_benefits = benefits_value_2;
            high_benefits = benefits_value_1;
        end

        % Determine which parameter value is low/high
        if param_values{1} < param_values{2}
            low_value = param_values{1};
            high_value = param_values{2};
        else
            low_value = param_values{2};
            high_value = param_values{1};
        end

        if strcmp(param_name, 'duration_dist_config')
            parts = split(low_value, "_");
            low_value = parts(10);
            parts = split(high_value, "_");
            high_value = parts(10);
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
    generate_latex_table(summary_table, fullfile(sensitivity_dir, 'sensitivity_summary.tex'), baseline_benefits);
    
    fprintf('Sensitivity summary generated and saved to %s\n', sensitivity_dir);
end

function benefits = calculate_vaccine_benefits(scenario_dir)
    %% Calculate the total discounted benefits from vaccines for a scenario
    % Args:
    %   scenario_dir (string): Path to scenario output directory
    %
    % Returns:
    %   benefits (double): Mean total discounted benefits from vaccines

    % Get all chunk directories
    raw_dir = fullfile(scenario_dir, 'raw');
    chunk_dirs = dir(fullfile(raw_dir, 'chunk_*'));
    chunk_dirs = chunk_dirs([chunk_dirs.isdir]);
    
    if isempty(chunk_dirs)
        error('No chunk directories found in %s', raw_dir);
    end
    
    % Extract chunk numbers and sort
    chunk_numbers = zeros(length(chunk_dirs), 1);
    for i = 1:length(chunk_dirs)
        tokens = regexp(chunk_dirs(i).name, 'chunk_(\d+)', 'tokens');
        chunk_numbers(i) = str2double(tokens{1}{1});
    end
    [chunk_numbers, sort_idx] = sort(chunk_numbers);
    chunk_dirs = chunk_dirs(sort_idx);
    
    % Check that chunk numbers are contiguous
    expected_chunks = 1:length(chunk_dirs);
    if ~isequal(chunk_numbers', expected_chunks)
        error('Chunk numbers are not contiguous. Found: %s, Expected: %s', ...
              mat2str(chunk_numbers'), mat2str(expected_chunks));
    end
    
    % Load first chunk to get dimensions
    first_chunk_path = fullfile(raw_dir, chunk_dirs(1).name, 'baseline_annual.mat');
    S_first = load(first_chunk_path, 'benefits_vaccine');
    [n_sims_per_chunk, n_periods] = size(S_first.benefits_vaccine);
    n_chunks = length(chunk_dirs);
    
    % Preallocate array for all benefits
    all_benefits = zeros(n_sims_per_chunk * n_chunks, n_periods);
    % Preallocate array for sum of benefits per simulation
    sum_benefits = zeros(n_sims_per_chunk * n_chunks, 1);
    
    % Load benefits_vaccine from all chunks and calculate sums
    for i = 1:n_chunks
        chunk_path = fullfile(raw_dir, chunk_dirs(i).name, 'baseline_annual.mat');
        S = load(chunk_path, 'benefits_vaccine');
        start_idx = (i-1) * n_sims_per_chunk + 1;
        end_idx = i * n_sims_per_chunk;
        sum_benefits(start_idx:end_idx) = sum(S.benefits_vaccine, 2);
    end
    
    % Calculate mean of sums
    benefits = mean(sum_benefits);
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
    
    % Return formatted name if available, otherwise return original
    if isKey(param_map, param_name)
        formatted_name = param_map(param_name);
    else
        formatted_name = param_name;
    end
end


function generate_latex_table(summary_table, output_path, baseline_benefits)
    %% Generate LaTeX table from sensitivity analysis results
    %
    % Args:
    %   summary_table (table): Table with sensitivity analysis results
    %   output_path (string): Path to save the LaTeX table
    %   baseline_benefits (double): Baseline benefits value
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
    fprintf(fileID, '\\textbf{Default parameters} & & & \\textbf{%.0f} \\\\\n', baseline_benefits/1e12);

    % Parameters that should be displayed as percentages
    percentage_params = {'y', 'r', 'gamma', 'theta', 'f_m', 'f_o', 'g_m', 'g_o', 'rental_share', 'capacity_kept'};
    
    % Write parameter rows
    for i = 2:height(summary_table)
        raw_param = summary_table.Parameter{i};
        param = format_parameter_name(raw_param);
        baseline_val = format_value(summary_table.BaselineValue(i), raw_param);
        low_val = summary_table.LowValue(i);
        high_val = summary_table.HighValue(i);
        low_benefit = summary_table.LowBenefit(i)/1e12;
        high_benefit = summary_table.HighBenefit(i)/1e12;
        
        % Only add units to first and last values in range
        if any(strcmp(raw_param, percentage_params))
            fprintf(fileID, '%s & %s & %.0f--%.0f\\%% & %.0f--%.0f \\\\\n', ...
                param, baseline_val, low_val*100, high_val*100, low_benefit, high_benefit);
        elseif contains(raw_param, 'tau')
            fprintf(fileID, '%s & %s & %.0f--%.0f months & %.0f--%.0f \\\\\n', ...
                param, baseline_val, low_val, high_val, low_benefit, high_benefit);
        elseif startsWith(raw_param, 'k_') || startsWith(raw_param, 'c_')
            fprintf(fileID, '%s & %s & \\$%.0f--%.0f & %.0f--%.0f \\\\\n', ...
                param, baseline_val, low_val, high_val, low_benefit, high_benefit);
        else
            fprintf(fileID, '%s & %s & %g--%g & %.0f--%.0f \\\\\n', ...
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
    disp(value)
    
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

