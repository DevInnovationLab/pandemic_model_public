function get_exp_lives_saved_invest(job_dir)
    % Calculates and writes a table of expected lives saved for different advance investment
    % programs relative to baseline over 10 and 30 year periods
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results

    % Load config and get scenarios
    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = string(fieldnames(config.scenarios));
    
    % Set up paths
    rawdata_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");
    
    % Load baseline data
    baseline_mortality = readmatrix(fullfile(rawdata_dir, "baseline_ts_m_deaths.csv"));
    
    % Initialize table
    summary_table = table('Size', [length(scenarios)-1 3], ...
        'VariableTypes', {'string', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'Lives10yr', 'Lives30yr'};
    
    % Process each non-baseline scenario
    row = 1;
    for i = 1:length(scenarios)
        scenario = scenarios(i);
        if strcmp(scenario, "baseline")
            continue;
        end
        
        % Load scenario data
        scen_mortality = readmatrix(fullfile(rawdata_dir, strcat(scenario, "_ts_m_deaths.csv")));
        
        % Calculate differences from baseline
        lives_diff = baseline_mortality - scen_mortality;
        lives_diff(lives_diff < 0)
        
        % Calculate mean differences over first 10 and 30 years
        lives_10yr = mean(sum(lives_diff(:,1:10), 2));
        lives_30yr = mean(sum(lives_diff(:,1:30), 2));
        
        % Add to table
        summary_table(row,:) = {scenario, lives_10yr, lives_30yr};
        row = row + 1;
    end
    
    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'lives_saved_summary.csv'));
    
    % Write to LaTeX
    write_lives_saved_table_latex(summary_table, fullfile(processed_dir, 'lives_saved_summary.tex'));
end

function write_lives_saved_table_latex(summary_data, outpath)
    % Write LaTeX table summarizing lives saved
    %
    % Args:
    %   summary_data (table): Table containing lives saved data
    %   outpath (string): Path to save LaTeX file
    
    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');
    
    % Write LaTeX table header
    fprintf(fileID, '\\begin{table}[h]\n\\centering\n');
    fprintf(fileID, '\\caption{Expected lives saved relative to baseline}\n');
    fprintf(fileID, '\\begin{tabular}{l r r}\n');
    fprintf(fileID, '\\toprule\n');
    fprintf(fileID, 'Scenario & \\multicolumn{2}{c}{Lives saved} \\\\\n');
    fprintf(fileID, '\\cmidrule{2-3}\n');
    fprintf(fileID, '& First 10 years & First 30 years \\\\\n');
    fprintf(fileID, '\\midrule\n');
    
    % Write data rows
    for i = 1:height(summary_data)
        fprintf(fileID, '%s & %.0f & %.0f \\\\\n', ...
            summary_data.Scenario{i}, ...
            summary_data.Lives10yr(i), ...
            summary_data.Lives30yr(i));
    end
    
    % Write LaTeX table footer
    fprintf(fileID, '\\bottomrule\n\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:lives_saved}\n');
    fprintf(fileID, '\\end{table}\n');
    
    % Close the file
    fclose(fileID);
end
