function get_sensitivity_loss_summary(sensitivity_dir)
    % Loads and summarizes results from sensitivity analysis, calculating average losses
    % and deaths across different sensitivity parameters using unmitigated loss outputs.
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
    baseline_arrival_dist = baseline_config.arrival_dist_config;
    baseline_vsl = baseline_config.value_of_death;
    baseline_r = baseline_config.r;
    baseline_y = baseline_config.y;
    baseline_periods = baseline_config.sim_periods;

    % First get baseline results from raw directory
    baseline_dir = fullfile(sensitivity_dir, 'baseline');

    % Get baseline losses and deaths
    [baseline_deaths, baseline_mortality, baseline_economic, baseline_learning, baseline_total] = ...
        get_unmitigated_losses_for_dir(baseline_dir, baseline_r, baseline_periods);

    % Initialize annualized summary table with baseline
    annualized_summary_table = table('Size', [1 7], ...
        'VariableTypes', {'string', 'string', 'cell', 'cell', 'cell', 'cell', 'cell'});
    annualized_summary_table.Properties.VariableNames = {...
        'Variable', 'Value', 'AnnualDeaths', 'MortalityLoss', 'EconomicLoss', 'LearningLoss', 'TotalLoss'};
    [formatted_name, formatted_value] = format_names('baseline', 'baseline', baseline_arrival_dist, ...
                                                     baseline_vsl, baseline_r, baseline_y);
    annualized_summary_table(1,:) = {...
        formatted_name,...
        formatted_value, ...
        {get_mean_and_iqr(baseline_deaths)} ...
        {get_mean_and_iqr(baseline_mortality)}, ...
        {get_mean_and_iqr(baseline_economic)}, ...
        {get_mean_and_iqr(baseline_learning)}, ...
        {get_mean_and_iqr(baseline_total)}, ...
    };

    % Initialize total loss summary table with baseline
    total_summary_table = table('Size', [1 7], ...
        'VariableTypes', {'string', 'string', 'cell', 'cell', 'cell', 'cell', 'cell'});
    total_summary_table.Properties.VariableNames = {...
        'Variable', 'Value', 'TotalDeaths', 'TotalMortalityLoss', 'TotalEconomicLoss', 'TotalLearningLoss', 'TotalLoss'};
    % Compute total (not annualized) values for baseline
    baseline_annualization_factor = (baseline_r * (1 + baseline_r)^baseline_periods) / ((1 + baseline_r)^baseline_periods - 1);
    total_summary_table(1,:) = {...
        formatted_name,...
        formatted_value, ...
        {get_mean_and_iqr(baseline_deaths * baseline_periods)} ...
        {get_mean_and_iqr(baseline_mortality / baseline_annualization_factor)} ...
        {get_mean_and_iqr(baseline_economic / baseline_annualization_factor)} ...
        {get_mean_and_iqr(baseline_learning / baseline_annualization_factor)} ...
        {get_mean_and_iqr(baseline_total / baseline_annualization_factor)} ...
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
            run_config = yaml.loadFile(fullfile(value_dir, "job_config.yaml"));
            r = run_config.r;
            periods = run_config.sim_periods;
            [annual_deaths, mortality_loss, economic_loss, learning_loss, total_loss] = ...
                get_unmitigated_losses_for_dir(value_dir, r, periods);
            [formatted_name, formatted_value] = format_names(var_name, var_values{j}, baseline_arrival_dist, baseline_vsl, baseline_r, baseline_y);

            % Annualized summary
            annualized_summary_table(row_idx,:) = {...
                formatted_name, ...
                formatted_value, ...
                {get_mean_and_iqr(annual_deaths)} ...
                {get_mean_and_iqr(mortality_loss)}, ...
                {get_mean_and_iqr(economic_loss)}, ...
                {get_mean_and_iqr(learning_loss)}, ...
                {get_mean_and_iqr(total_loss)}, ...
            };

            % Total loss summary (convert annualized losses back to total by dividing by annualization factor)
            annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);
            total_summary_table(row_idx,:) = {...
                formatted_name, ...
                formatted_value, ...
                {get_mean_and_iqr(annual_deaths * periods)} ...
                {get_mean_and_iqr(mortality_loss / annualization_factor)} ...
                {get_mean_and_iqr(economic_loss / annualization_factor)} ...
                {get_mean_and_iqr(learning_loss / annualization_factor)} ...
                {get_mean_and_iqr(total_loss / annualization_factor)} ...
            };

            row_idx = row_idx + 1;
        end
    end

    % Save latex tables
    write_to_latex(annualized_summary_table, fullfile(sensitivity_dir, "sensitivity_annualized_loss_summary.tex"))
    write_to_latex(total_summary_table, fullfile(sensitivity_dir, "sensitivity_total_loss_summary.tex"))

    %% Prepare and save CSVs (means only, snake_case column names)

    % Helper to extract mean from a cell containing a struct
    function m = get_mean(cellval)
        m = cellval{1}.mean;
    end

    % Convert summary table to new CSV table (means only)
    function csv_table = summary_table_to_csv(summary_table)
        csv_data = cell(size(summary_table));
        for row = 1:height(csv_data)
            csv_data{row,1} = summary_table{row,1}; % variable
            csv_data{row,2} = summary_table{row,2}; % value
            csv_data{row,3} = get_mean(summary_table{row,3});
            csv_data{row,4} = get_mean(summary_table{row,4});
            csv_data{row,5} = get_mean(summary_table{row,5});
            csv_data{row,6} = get_mean(summary_table{row,6});
            csv_data{row,7} = get_mean(summary_table{row,7});
        end
        csv_table = cell2table(csv_data, 'VariableNames', summary_table.Properties.VariableNames);
    end

    % Convert and write annualized summary
    annualized_csv = summary_table_to_csv(annualized_summary_table);
    writetable(annualized_csv, fullfile(sensitivity_dir, 'sensitivity_annualized_loss_summary.csv'));

    % Convert and write total summary
    total_csv = summary_table_to_csv(total_summary_table);
    writetable(total_csv, fullfile(sensitivity_dir, 'sensitivity_total_loss_summary.csv'));
end

function [annual_deaths, mortality_losses, economic_losses, learning_losses, total_losses] = get_unmitigated_losses_for_dir(value_dir, r, periods)
    % Load and process losses and deaths from a MAT file saved by estimate_unmitigated_losses.
    %
    % Args:
    %   raw_dir (string): Directory containing the results MAT file.
    %   r (double): Discount rate.
    %   periods (integer): Number of simulation periods.
    %
    % Returns:
    %   annual_deaths (vector): Average annual deaths.
    %   mortality_losses (vector): Annualized mortality losses.
    %   economic_losses (vector): Annualized economic losses.
    %   learning_losses (vector): Annualized learning losses.
    %   total_losses (vector): Annualized total losses.

    % Compute annualization factor
    annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);

    % Find the MAT file (assume only one *_unmitigated_losses.mat in the directory)
    mat_file = fullfile(value_dir, 'unmitigated_losses.mat');
    assert(isfile(mat_file), 'No unmitigated losses MAT file found in %s', value_dir);

    % Load only the needed arrays
    S = load(mat_file, 'deaths',... 
                       'mortality_losses', ...
                       'output_losses', ...
                       'learning_losses', ...
                       'total_losses');

    % Each variable is [N x T] (N = runs, T = time steps)
    deaths_ts = S.deaths;
    mortality_ts = S.mortality_losses;
    output_ts = S.output_losses;
    learning_ts = S.learning_losses;
    total_ts = S.total_losses;

    % Sum over time for each run, then annualize
    annual_deaths = sum(deaths_ts, 2) ./ periods;
    mortality_losses = sum(mortality_ts, 2) .* annualization_factor;
    economic_losses = sum(output_ts, 2) .* annualization_factor;
    learning_losses = sum(learning_ts, 2) .* annualization_factor;
    total_losses = sum(total_ts, 2) .* annualization_factor;
end

function stats = get_mean_and_iqr(sample)
    % Returns a struct with mean, 25th, and 75th percentiles

    assert(isvector(sample)); % Throw error if matrix is passed.
    stats.mean = mean(sample) / 1e12; % convert to trillions for losses, millions for deaths later
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
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    fprintf(fileID, '\\caption{\\textbf{Expected global pandemic deaths and losses in the absence of mitigations.} Monetized losses are discounted. Each cell presents the mean estimates in the center with the interquartile range in square brackets below.}\n');
    fprintf(fileID, '\\vskip 3pt');
    fprintf(fileID, '\\small\n\\renewcommand{\\arraystretch}{0.9}\n');
    fprintf(fileID, '\\begin{tabular}{l c c c c c}\n');
    fprintf(fileID, '\\hline\\hline\n');
    fprintf(fileID, '\\noalign{\\vskip 3pt}\n');
    fprintf(fileID, 'Scenario & \\shortstack[c]{Expected annual deaths\\\\(millions)} & \\multicolumn{4}{c}{\\shortstack[c]{Expected annualized pandemic losses \\\\ (\\$ trillion)}}\\\\\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, ' & & Mortality & Economic & Learning & Total \\\\\n');
    fprintf(fileID, ' & $\\overline{D}$ & $AV\\!\\left(\\overline{ML}\\right)$ & $AV\\!\\left(\\overline{OL}\\right)$ & $AV\\!\\left(\\overline{LL}\\right)$ & $AV\\!\\left(\\overline{TL}\\right)$\\\\\n');
    fprintf(fileID, '\\hline\n');
    
    % Identify unique scenario categories (Variable column)
    uniqueVars = unique(summary_data.Variable);
    baselineIdx = strcmp(uniqueVars, 'Baseline');
    uniqueVars = [uniqueVars(baselineIdx); uniqueVars(~baselineIdx)];
    
    for i = 1:length(uniqueVars)
        varRows = strcmp(summary_data.Variable, uniqueVars{i});
        varData = summary_data(varRows, :);
    
        % Print main scenario name (not indented for Baseline)
        if strcmp(uniqueVars{i}, 'Baseline')
            fprintf(fileID, '%s ', uniqueVars{i});
        else
            fprintf(fileID, '%s \\\\\n', uniqueVars{i});
        end
    
        for j = 1:height(varData)
            fprintf(fileID, '\\hspace{3mm} %s & ', varData.Value{j});
    
            % Columns k = 1..5 in varData stats:
            %   We assume k==1 is DEATHS; k==2..5 are losses in $ trillions.
            %   Adjust if your column order differs.
            for k = 1:5
                stat = varData{j, 2+k}{1}; % struct in a cell: fields mean, p25, p75
    
                if k == 1
                    % Annual deaths (millions): convert people → millions
                    top = stat.mean .* 1e6;
                    lo  = stat.p25  .* 1e6;
                    hi  = stat.p75  .* 1e6;
                else
                    % Losses ($ trillion)
                    top = stat.mean;
                    lo  = stat.p25;
                    hi  = stat.p75;
                end
    
                % Multiline cell without makecell: nested tabular
                cellstr = sprintf('\\begin{tabular}[c]{@{}c@{}}%.1f \\\\[-0.7em] \\footnotesize [%.1f, %.1f]\\end{tabular}', top, lo, hi);
    
                if k < 5
                    fprintf(fileID, '%s & ', cellstr);
                else
                    fprintf(fileID, '%s \\\\\n', cellstr);
                end
            end
        end
    end
    
    % Write LaTeX table footer
    fprintf(fileID, '\\hline\\hline\n\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:pandemic_losses}\n');
    fprintf(fileID, '\\end{table}\n');
    
    fclose(fileID);
    fprintf('LaTeX table successfully written to %s\n', outpath);
end

function [formatted_name, formatted_value] = format_names(var_name, var_value, baseline_arrival_dist, ...
                                                          baseline_vsl, baseline_r, baseline_y)
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
    b_meta = parse_arrival_dist_fp(baseline_arrival_dist);

    % Format variable names
    switch var_name
        case "value_of_death"
            formatted_name = "Value of statistical life (VSL)";
            if var_value < baseline_vsl
                formatted_value = sprintf("Reduce to \\$%g million", var_value/1e6);
            elseif var_value > baseline_vsl
                formatted_value = sprintf("Increase to \\$%g million", var_value/1e6);
            end
        case "arrival_dist_config"
            % Compare baseline and sensitivity meta for intensity upper bound and lower threshold
            s_meta = parse_arrival_dist_fp(var_value);
            trunc_diff = s_meta.trunc_value ~= b_meta.trunc_value;
            threshold_diff = s_meta.lower_threshold ~= b_meta.lower_threshold;
            airborne = strcmp(s_meta.scope, "airborne"); 

            if trunc_diff
                formatted_name = "Severity upper bound ($\overline{s}$)";
                formatted_value = sprintf("%g SU", s_meta.trunc_value);
            elseif threshold_diff
                formatted_name = "Lower severity threshold ($\underline{s}$)";
                formatted_value = sprintf("%g SU", s_meta.lower_threshold);
            elseif airborne
                formatted_name = "Pathogen types";
                formatted_value = "Airborne pathogens only";
            end
        case "duration_dist_config"
            formatted_name = "Duration upper bound ($\overline{d}$)";
            [~, config_name, ~] = fileparts(var_value);
            config_metadata = split(config_name, "_");
            trunc_value = config_metadata(8);
            formatted_value = sprintf("%g years", trunc_value);
        case "y"
            formatted_name = "Per capita GDP growth rate ($y$)";
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