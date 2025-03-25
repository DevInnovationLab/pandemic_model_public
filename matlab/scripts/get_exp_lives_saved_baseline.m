function get_exp_lives_saved_baseline(job_dir)
    % Calculates and writes a table of expected lives saved by vaccines in the baseline
    % scenario over 10 and 30 year periods by comparing unmitigated and mitigated deaths
    %
    % Args:
    %   job_dir (string): Directory containing job configuration and results
    
    % Set up paths
    rawdata_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");
    
    % Load death data
    unmitigated_deaths = readmatrix(fullfile(rawdata_dir, "baseline_ts_u_deaths.csv"));
    mitigated_deaths = readmatrix(fullfile(rawdata_dir, "baseline_ts_m_deaths.csv"));
    
    % Calculate differences in deaths
    lives_saved = unmitigated_deaths - mitigated_deaths;
    
    % Calculate mean differences over first 10 and 30 years
    lives_10yr = mean(sum(lives_saved(:,1:10), 2));
    lives_30yr = mean(sum(lives_saved(:,1:30), 2));
    
    % Create summary table
    summary_table = table('Size', [1 3], ...
        'VariableTypes', {'string', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'Lives10yr', 'Lives30yr'};
    summary_table(1,:) = {'Baseline', lives_10yr, lives_30yr};
    
    % Save table to CSV
    writetable(summary_table, fullfile(processed_dir, 'baseline_lives_saved_summary.csv'));
    
    % Write to LaTeX
    write_baseline_lives_saved_table_latex(summary_table, ...
        fullfile(processed_dir, 'baseline_lives_saved_summary.tex'));
end

function write_baseline_lives_saved_table_latex(summary_data, outpath)
    % Write LaTeX table summarizing baseline lives saved by vaccines
    %
    % Args:
    %   summary_data (table): Table containing lives saved data
    %   outpath (string): Path to save LaTeX file
    
    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');
    
    % Write LaTeX table header
    fprintf(fileID, '\\begin{table}[h]\n\\centering\n');
    fprintf(fileID, '\\caption{Expected lives saved by vaccines in baseline scenario}\n');
    fprintf(fileID, '\\begin{tabular}{l r r}\n');
    fprintf(fileID, '\\toprule\n');
    fprintf(fileID, 'Scenario & \\multicolumn{2}{c}{Lives saved} \\\\\n');
    fprintf(fileID, '\\cmidrule{2-3}\n');
    fprintf(fileID, '& First 10 years & First 30 years \\\\\n');
    fprintf(fileID, '\\midrule\n');
    
    % Write data row
    fprintf(fileID, '%s & %.0f & %.0f \\\\\n', ...
        summary_data.Scenario{1}, ...
        summary_data.Lives10yr(1), ...
        summary_data.Lives30yr(1));
    
    % Write LaTeX table footer
    fprintf(fileID, '\\bottomrule\n\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:baseline_lives_saved}\n');
    fprintf(fileID, '\\end{table}\n');
    
    % Close file
    fclose(fileID);
end
