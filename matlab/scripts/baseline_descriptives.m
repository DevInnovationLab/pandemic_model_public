function baseline_descriptives(job_dir)
    % Load job config and simulation data
    config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    sim_results = readtable(fullfile(job_dir, "raw", "baseline_pandemic_table.csv"));
    
    % Load severity thresholds from data
    pand_df = readtable("./data/raw/epidemics_marani_240816.xlsx", "TextType", "string");
    
    % Get COVID and Spanish Fluseverity (ex post)
    covid_severity = pand_df.severity_smu(strcmp(pand_df.disease, "covid-19"));
    spanish_flu_severity = pand_df.severity_smu(strcmp(pand_df.disease, "influenza") & pand_df.year_start == 1918);
    
    % Calculate pandemic frequencies by simulation
    num_sims = config.num_simulations;
    sim_periods = config.sim_periods;
    
    % Get all true pandemics across simulations
    true_pandemics = sim_results(~sim_results.is_false, :);
    severities = true_pandemics.ex_post_severity;
    
    % Calculate COVID and Spanish Flu equivalents across all simulations
    total_periods = sim_periods * num_sims;
    covid_eq = total_periods / sum(severities >= covid_severity);
    spflu_eq = total_periods / sum(severities >= spanish_flu_severity);
    
    % Calculate annual mortality across all simulations
    annual_mortality = sum(severities) / total_periods;
    
    % Initialize arrays for per-simulation statistics
    pandemics_per_sim = zeros(num_sims, 1);
    total_losses_per_sim = zeros(num_sims, 1);

    loss_cols = ["m_mortality_losses", "m_output_losses", "m_learning_losses"];
    
    % Calculate statistics for each simulation
    for i = 1:num_sims
        % Get data for this simulation
        sim_data = sim_results(sim_results.sim_num == i, :);
        true_pandemics_sim = sim_data(~sim_data.is_false, :);
        
        % Count pandemics
        pandemics_per_sim(i) = height(true_pandemics_sim);
        
        % Calculate total losses for simulation
        total_losses_per_sim(i) = sum(sum(true_pandemics_sim{:, loss_cols}), 2);
    end
    
    % Create table of summary statistics
    stat_names = ["covid_eq_freq", "spflu_eq_freq", "pandemic_per_sim", ...
                  "total_losses_trillions", "exp_annual_severity"];
    
    means = [covid_eq; 
             spflu_eq;
             mean(pandemics_per_sim);
             mean(total_losses_per_sim)/1e12;
             annual_mortality];
         
    pct_5 = [nan;
             nan;
             prctile(pandemics_per_sim, 5);
             prctile(total_losses_per_sim, 5)/1e12;
             nan];
         
    pct_95 = [nan;
              nan;
              prctile(pandemics_per_sim, 95);
              prctile(total_losses_per_sim, 95)/1e12;
              nan];
    
    % Create table
    summary_stats = table(stat_names', means, pct_5, pct_95, ...
        'VariableNames', {'statistic', 'mean', 'pct_5', 'pct_95'});
    
    % Write to CSV
    writetable(summary_stats, fullfile(job_dir, 'baseline_descriptives.csv'));

    % Create latex table
    write_descriptives_latex(summary_stats, fullfile(job_dir, "baseline_descriptives_table.tex"));
end


function write_descriptives_latex(summary_stats, outpath)
    % Creates a LaTeX table from baseline descriptive statistics
    %
    % Args:
    %   summary_stats (table): Table containing descriptive statistics
    %   outpath (string): Path to save the LaTeX table
    %
    % Returns:
    %   None, but saves LaTeX table to specified path

    % Open LaTeX file for writing
    fileID = fopen(outpath, 'w');

    % Write LaTeX table header
    fprintf(fileID, '\\begin{table}[h]\n\\centering\n');
    fprintf(fileID, '\\begin{tabular}{l r r r}\n');
    fprintf(fileID, '\\toprule\n');
    fprintf(fileID, '\\textbf{Statistic} & Mean & 5th Pct. & 95th Pct. \\\\\n');
    fprintf(fileID, '\\midrule\n');

    % Write each row
    for i = 1:height(summary_stats)
        stat = summary_stats.statistic(i);
        
        % Format statistic name
        switch stat
            case 'covid_eq_freq'
                stat_name = 'COVID-19 Equivalent Frequency (Years)';
            case 'spflu_eq_freq'
                stat_name = 'Spanish Flu Equivalent Frequency (Years)';
            case 'pandemic_per_sim'
                stat_name = 'Pandemics per Simulation';
            case 'total_losses_trillions'
                stat_name = 'Total Losses (Trillion USD)';
            case 'exp_annual_severity'
                stat_name = 'Expected Annual Severity';
        end

        % Format values, handling NaN appropriately
        mean_val = summary_stats.mean(i);
        pct_5_val = summary_stats.pct_5(i);
        pct_95_val = summary_stats.pct_95(i);

        if isnan(pct_5_val) && isnan(pct_95_val)
            fprintf(fileID, '%s & %.2f & -- & -- \\\\\n', ...
                stat_name, mean_val);
        else
            fprintf(fileID, '%s & %.2f & %.2f & %.2f \\\\\n', ...
                stat_name, mean_val, pct_5_val, pct_95_val);
        end
    end

    % Write LaTeX table footer
    fprintf(fileID, '\\bottomrule\n\\end{tabular}\n');
    fprintf(fileID, '\\caption{Baseline pandemic simulation descriptive statistics}\n');
    fprintf(fileID, '\\label{tab:baseline_descriptives}\n');
    fprintf(fileID, '\\end{table}\n');

    % Close the file
    fclose(fileID);
end
