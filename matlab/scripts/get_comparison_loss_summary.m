function get_comparison_loss_summary(sensitivity_dir)
    % Loads and summarizes results from multiparameter sensitivity analysis, calculating 
    % average losses across different sensitivity scenarios where multiple parameters
    % are varied simultaneously
    %
    % Args:
    %   sensitivity_dir (str): Path to sensitivity analysis output directory
    %
    % Returns:
    %   None, but saves summary statistics to files in the sensitivity directory

    % Load sensitivity config
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    sensitivity_scenarios = fieldnames(sensitivity_config.sensitivities);

    % Load baseline config to get reference values
    baseline_config = yaml.loadFile(fullfile(sensitivity_dir, 'baseline', 'job_config.yaml'));
    baseline_vsl = baseline_config.value_of_death;
    baseline_r = baseline_config.r;
    baseline_y = baseline_config.y;

    % First get baseline results from raw directory
    baseline_dir = fullfile(sensitivity_dir, 'baseline', 'raw');

    % Get baseline losses
    [baseline_mortality, baseline_economic, baseline_learning, baseline_total] = ...
        get_losses_for_dir(baseline_dir, baseline_r, baseline_config.sim_periods);

    % Initialize summary table with baseline
    summary_table = table('Size', [1 6], 'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double'});
    summary_table.Properties.VariableNames = {...
        'Scenario', 'Description', 'MortalityLoss', 'EconomicLoss', 'LearningLoss', 'TotalLoss'};
    summary_table(1,:) = {'Baseline', 'New methodology', baseline_mortality, baseline_economic, baseline_learning, baseline_total};

    % Process each scenario
    row_idx = 2;
    for i = 1:length(sensitivity_scenarios)
        scenario = sensitivity_scenarios{i};
        scenario_dir = fullfile(sensitivity_dir, scenario, 'raw');
        
        % Load scenario config
        scenario_config = yaml.loadFile(fullfile(sensitivity_dir, scenario, 'job_config.yaml'));
        
        % Get scenario losses
        [mortality_loss, economic_loss, learning_loss, total_loss] = ...
            get_losses_for_dir(scenario_dir, scenario_config.r, scenario_config.sim_periods);
        
        % Add to summary table
        summary_table(row_idx,:) = {scenario, get_scenario_description(scenario), ...
            mortality_loss, economic_loss, learning_loss, total_loss};
        row_idx = row_idx + 1;
    end

    % Save summary table
    writetable(summary_table, fullfile(sensitivity_dir, 'comparison_loss_summary.csv'));
    write_to_latex(summary_table, fullfile(sensitivity_dir, "comparison_loss_summary.tex"));
end

function [mortality_loss, economic_loss, learning_loss, total_loss] = get_losses_for_dir(raw_dir, r, periods)
    % Load and process losses for a given directory
    %
    % Args:
    %   raw_dir (str): Directory containing raw results
    %   r (double): Discount rate
    %   periods (int): Number of simulation periods
    %
    % Returns:
    %   mortality_loss (double): Annualized mortality losses
    %   economic_loss (double): Annualized economic losses  
    %   learning_loss (double): Annualized learning losses
    %   total_loss (double): Annualized total losses

    % Calculate annualization factor
    annualization_factor = (1 - (1 + r).^-periods) ./ r;

    % Load and process mortality losses
    mortality_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_mortality_losses.csv'));
    mortality_loss = mean(sum(mortality_ts, 2)) ./ annualization_factor;
    
    % Load and process output losses
    output_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_output_losses.csv'));
    economic_loss = mean(sum(output_ts, 2)) ./ annualization_factor;
    
    % Load and process learning losses
    learning_ts = readmatrix(fullfile(raw_dir, 'baseline_ts_m_learning_losses.csv'));
    learning_loss = mean(sum(learning_ts, 2)) ./ annualization_factor;
    
    % Calculate total losses
    total_ts = mortality_ts + output_ts + learning_ts;
    total_loss = mean(sum(total_ts, 2)) ./ annualization_factor;
end

function description = get_scenario_description(scenario)
    % Returns a human-readable description of the scenario
    %
    % Args:
    %   scenario (str): Name of the scenario
    %
    % Returns:
    %   description (str): Human-readable description

    switch scenario
        case "vary_severity_dist"
            description = "\{\tilde\}Old severity distribution";
        case "vary_econ_loss"
            description = "\{\tilde\}Old economic loss model";
        case "both"
            description = "\{\tilde\}Old severity and economic loss models";
        otherwise
            description = "";
    end
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

    % Write data rows
    for i = 1:height(summary_data)
        fprintf(fileID, '%s & %.1f & %.1f & %.1f & %.1f \\\\\n', ...
            summary_data.Description{i}, ...
            summary_data.MortalityLoss(i), summary_data.EconomicLoss(i), ...
            summary_data.LearningLoss(i), summary_data.TotalLoss(i));
    end

    % Write LaTeX table footer
    fprintf(fileID, '\\bottomrule\n\\end{tabular}\n');
    fprintf(fileID, '\\caption{Annualized global pandemic losses under different model specifications}\n');
    fprintf(fileID, '\\label{tab:comparison_losses}\n');
    fprintf(fileID, '\\end{table}\n');

    % Close the file
    fclose(fileID);
end
