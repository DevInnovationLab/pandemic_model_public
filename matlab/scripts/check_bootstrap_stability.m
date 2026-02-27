function check_bootstrap_stability(sim_results_path, varargin)
    % CHECK_BOOTSTRAP_STABILITY
    % Analyzes bootstrap stability by examining bias, skewness, and percentile stability
    %
    % Args:
    %   sim_results_path: Path to simulation results directory
    %   varargin: Optional name-value pairs:
    %     'n_bootstrap': Number of bootstrap samples per iteration (default: 1000)
    %     'n_iterations': Number of bootstrap iterations for stability check (default: 100)
    %     'variables': Cell array of variable names to check (default: {'tot_benefits_pv_full'})
    %     'check_complementarity': Whether to check complementarity stability (default: true)
    
    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'n_bootstrap', 200, @isnumeric);
    addParameter(p, 'n_iterations', 20, @isnumeric);
    addParameter(p, 'variables', {'net_value_pv_full'}, @iscell);
    addParameter(p, 'check_complementarity', true, @islogical);
    parse(p, varargin{:});
    
    n_bootstrap = p.Results.n_bootstrap;
    n_iterations = p.Results.n_iterations;
    variables = p.Results.variables;
    check_complementarity = p.Results.check_complementarity;
    
    processed_dir = fullfile(sim_results_path, "processed");
    figures_dir = fullfile(sim_results_path, "figures", "bootstrap_stability");
    create_folders_recursively(figures_dir);
    
    % Load config to get scenario info
    config = yaml.loadFile(fullfile(sim_results_path, "job_config.yaml"));
    scenario_names = fieldnames(config.scenarios);
    scenario_names = scenario_names(~strcmp(scenario_names, 'baseline'));
    
    % Pre-allocate results tables
    n_total_rows = length(scenario_names) * length(variables);
    
    bias_results = table('Size', [n_total_rows, 5], ...
        'VariableTypes', {'cell', 'cell', 'double', 'double', 'double'}, ...
        'VariableNames', {'Scenario', 'Variable', 'SampleMean', 'MedianBootstrapMean', 'RelativeBias'});
    
    skew_results = table('Size', [n_total_rows, 3], ...
        'VariableTypes', {'cell', 'cell', 'double'}, ...
        'VariableNames', {'Scenario', 'Variable', 'BootstrapMeanSkew'});
    
    percentile_results = table('Size', [n_total_rows, 18], ...
        'VariableTypes', {'cell', 'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'Scenario', 'Variable', 'P2_5_Mean', 'P2_5_Std', 'P5_Mean', 'P5_Std', 'P95_Mean', 'P95_Std', 'P97_5_Mean', 'P97_5_Std', ...
                          'P2_5_RelDist', 'P2_5_RelDist_Std', 'P5_RelDist', 'P5_RelDist_Std', 'P95_RelDist', 'P95_RelDist_Std', 'P97_5_RelDist', 'P97_5_RelDist_Std'});
    
    % Store raw data for complementarity calculations
    raw_data = struct();
    row_idx = 0;
    
    % Analyze each scenario
    for i = 1:length(scenario_names)
        scenario_name = scenario_names{i};
        fprintf('Analyzing scenario: %s\n', scenario_name);
        
        % Load data
        tic;
        rel_sums_file = fullfile(processed_dir, sprintf('%s_relative_sums.mat', scenario_name));
        
        % Check if file exists
        if ~isfile(rel_sums_file)
            warning('Relative sums file not found for scenario %s. Skipping.', scenario_name);
            continue;
        end
        
        data = load(rel_sums_file);
        all_relative_sums = data.all_relative_sums;
        fprintf('  Loaded data in %.2f seconds\n', toc);
        
        % Store raw data for complementarity calculations
        if ismember('net_value_pv_full', all_relative_sums.Properties.VariableNames)
            raw_data.(scenario_name).benefits = all_relative_sums.net_value_pv_full;
        end
        
        % Analyze each variable
        for v = 1:length(variables)
            var_name = variables{v};
            
            if ~ismember(var_name, all_relative_sums.Properties.VariableNames)
                warning('Variable %s not found in scenario %s. Skipping.', var_name, scenario_name);
                continue;
            end
            
            row_idx = row_idx + 1;
            
            sample_data = all_relative_sums.(var_name);
            sample_mean = mean(sample_data);
            
            % 1. Bootstrap bias analysis
            tic;
            bootstrap_means = bootstrp(n_bootstrap, @mean, sample_data);
            fprintf('  Bootstrap bias analysis for %s: %.2f seconds\n', var_name, toc);
            
            median_bootstrap_mean = median(bootstrap_means);
            relative_bias = (median_bootstrap_mean - sample_mean) / abs(sample_mean);
            
            bias_results(row_idx, :) = {{scenario_name}, {var_name}, sample_mean, median_bootstrap_mean, relative_bias};
            
            % 2. Bootstrap mean skewness
            bootstrap_skew = skewness(bootstrap_means);
            
            skew_results(row_idx, :) = {{scenario_name}, {var_name}, bootstrap_skew};
            
            % 3. Percentile stability across multiple bootstrap iterations
            tic;
            p2_5_values = zeros(n_iterations, 1);
            p5_values = zeros(n_iterations, 1);
            p95_values = zeros(n_iterations, 1);
            p97_5_values = zeros(n_iterations, 1);
            
            p2_5_rel_dist = zeros(n_iterations, 1);
            p5_rel_dist = zeros(n_iterations, 1);
            p95_rel_dist = zeros(n_iterations, 1);
            p97_5_rel_dist = zeros(n_iterations, 1);
            
            for iter = 1:n_iterations
                boot_samples = bootstrp(n_bootstrap, @mean, sample_data);
                boot_mean = mean(boot_samples);
                
                p2_5_values(iter) = prctile(boot_samples, 2.5);
                p5_values(iter) = prctile(boot_samples, 5);
                p95_values(iter) = prctile(boot_samples, 95);
                p97_5_values(iter) = prctile(boot_samples, 97.5);
                
                % Calculate relative distance from percentile to bootstrap mean
                p2_5_rel_dist(iter) = abs(p2_5_values(iter) - boot_mean) / abs(boot_mean);
                p5_rel_dist(iter) = abs(p5_values(iter) - boot_mean) / abs(boot_mean);
                p95_rel_dist(iter) = abs(p95_values(iter) - boot_mean) / abs(boot_mean);
                p97_5_rel_dist(iter) = abs(p97_5_values(iter) - boot_mean) / abs(boot_mean);
            end
            fprintf('  Percentile stability analysis for %s: %.2f seconds\n', var_name, toc);
            
            percentile_results(row_idx, :) = {{scenario_name}, {var_name}, ...
                mean(p2_5_values), std(p2_5_values), ...
                mean(p5_values), std(p5_values), ...
                mean(p95_values), std(p95_values), ...
                mean(p97_5_values), std(p97_5_values), ...
                mean(p2_5_rel_dist), std(p2_5_rel_dist), ...
                mean(p5_rel_dist), std(p5_rel_dist), ...
                mean(p95_rel_dist), std(p95_rel_dist), ...
                mean(p97_5_rel_dist), std(p97_5_rel_dist)};
            
            % Plot percentile stability
            tic;
            figure('Position', [100, 100, 1200, 900]);
            
            % Top subplot spanning full width
            subplot(3, 2, [1 2]);
            histogram(bootstrap_means, 30, 'Normalization', 'pdf');
            hold on;
            xline(sample_mean, 'r--', 'LineWidth', 2);
            xline(median_bootstrap_mean, 'b--', 'LineWidth', 2);
            xlabel('Bootstrap Mean');
            ylabel('Density');
            title('Bootstrap Distribution');
            
            % Get x-axis limits from the bootstrap mean plot
            x_limits = xlim;
            
            % Bottom four subplots
            subplot(3, 2, 3);
            histogram(p2_5_values, 30);
            xlim(x_limits);
            xlabel('2.5th Percentile');
            ylabel('Frequency');
            title('2.5th Percentile Stability');
            
            subplot(3, 2, 4);
            histogram(p5_values, 30);
            xlim(x_limits);
            xlabel('5th Percentile');
            ylabel('Frequency');
            title('5th Percentile Stability');
            
            subplot(3, 2, 5);
            histogram(p95_values, 30);
            xlim(x_limits);
            xlabel('95th Percentile');
            ylabel('Frequency');
            title('95th Percentile Stability');
            
            subplot(3, 2, 6);
            histogram(p97_5_values, 30);
            xlim(x_limits);
            xlabel('97.5th Percentile');
            ylabel('Frequency');
            title('97.5th Percentile Stability');
            
            % Format titles
            formatted_scenario = format_scenario_name(scenario_name);
            formatted_variable = format_variable_name(var_name);
            sgtitle(sprintf('%s - %s', formatted_scenario, formatted_variable));
            
            print(gcf, fullfile(figures_dir, sprintf('%s_%s_stability', scenario_name, var_name)), '-dpng', '-r600');
            close(gcf);
            fprintf('  Plotting for %s: %.2f seconds\n', var_name, toc);
        end
    end
    
    % Trim tables to actual size (in case some scenarios were skipped)
    bias_results = bias_results(1:row_idx, :);
    skew_results = skew_results(1:row_idx, :);
    percentile_results = percentile_results(1:row_idx, :);
    
    % Save results
    writetable(bias_results, fullfile(processed_dir, 'bootstrap_bias_analysis.csv'));
    writetable(skew_results, fullfile(processed_dir, 'bootstrap_skew_analysis.csv'));
    writetable(percentile_results, fullfile(processed_dir, 'bootstrap_percentile_stability.csv'));
    
    % Display summary
    fprintf('\n=== Bootstrap Bias Summary ===\n');
    disp(bias_results);
    
    fprintf('\n=== Bootstrap Skewness Summary ===\n');
    disp(skew_results);
    
    fprintf('\n=== Bootstrap Percentile Stability Summary ===\n');
    disp(percentile_results);
    
    % Check complementarity stability if requested
    if check_complementarity
        fprintf('\n=== Checking Complementarity Stability ===\n');
        [comp_bias_results, comp_skew_results, comp_percentile_results] = ...
            check_complementarity_stability(raw_data, scenario_names, n_bootstrap, n_iterations, figures_dir);
        
        % Save complementarity results
        writetable(comp_bias_results, fullfile(processed_dir, 'bootstrap_complementarity_bias_analysis.csv'));
        writetable(comp_skew_results, fullfile(processed_dir, 'bootstrap_complementarity_skew_analysis.csv'));
        writetable(comp_percentile_results, fullfile(processed_dir, 'bootstrap_complementarity_percentile_stability.csv'));
        
        fprintf('\n=== Complementarity Bootstrap Bias Summary ===\n');
        disp(comp_bias_results);
        
        fprintf('\n=== Complementarity Bootstrap Skewness Summary ===\n');
        disp(comp_skew_results);
        
        fprintf('\n=== Complementarity Bootstrap Percentile Stability Summary ===\n');
        disp(comp_percentile_results);
    end
    
    fprintf('\nBootstrap stability analysis complete!\n');
    fprintf('Results saved to: %s\n', processed_dir);
    fprintf('Figures saved to: %s\n', figures_dir);
end

function [comp_bias_results, comp_skew_results, comp_percentile_results] = ...
    check_complementarity_stability(raw_data, scenario_names, n_bootstrap, n_iterations, figures_dir)
    % Check stability of complementarity estimates
    
    % Parse scenario names to identify investments
    [accents, investment_indicators] = parse_scenario_name(scenario_names);
    investments = investment_indicators.Properties.VariableNames;
    
    % Filter to surplus scenarios only
    surplus_scenarios = scenario_names(strcmp(accents, "surplus"));
    
    % Count number of unique complementarity pairs
    % Each pair should only be counted once (e.g., A+B is the same as B+A)
    n_pairs = 0;
    for i = 1:length(investments)
        for j = (i+1):length(investments)
            % Check if there's a scenario with both investments
            has_both = false;
            for k = 1:length(surplus_scenarios)
                scenario = surplus_scenarios{k};
                if contains(scenario, investments{i}) && contains(scenario, investments{j})
                    has_both = true;
                    break;
                end
            end
            if has_both
                n_pairs = n_pairs + 1;
            end
        end
    end
    
    % Pre-allocate results tables (2 variables per pair: benefits and costs)
    comp_bias_results = table('Size', [n_pairs * 2, 6], ...
        'VariableTypes', {'cell', 'cell', 'cell', 'double', 'double', 'double'}, ...
        'VariableNames', {'Investment', 'WithInvestment', 'Variable', 'SampleMean', 'MedianBootstrapMean', 'RelativeBias'});
    
    comp_skew_results = table('Size', [n_pairs * 2, 4], ...
        'VariableTypes', {'cell', 'cell', 'cell', 'double'}, ...
        'VariableNames', {'Investment', 'WithInvestment', 'Variable', 'BootstrapMeanSkew'});
    
    comp_percentile_results = table('Size', [n_pairs * 2, 19], ...
        'VariableTypes', {'cell', 'cell', 'cell', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'Investment', 'WithInvestment', 'Variable', 'P2_5_Mean', 'P2_5_Std', 'P5_Mean', 'P5_Std', 'P95_Mean', 'P95_Std', 'P97_5_Mean', 'P97_5_Std', ...
                          'P2_5_RelDist', 'P2_5_RelDist_Std', 'P5_RelDist', 'P5_RelDist_Std', 'P95_RelDist', 'P95_RelDist_Std', 'P97_5_RelDist', 'P97_5_RelDist_Std'});
    
    row_idx = 0;
    
    % Iterate through unique pairs of investments
    for i = 1:length(investments)
        for j = (i+1):length(investments)
            investment1 = investments{i};
            investment2 = investments{j};
            
            % Find the scenario with both investments
            with_scenario = [];
            for k = 1:length(surplus_scenarios)
                scenario = surplus_scenarios{k};
                if contains(scenario, investment1) && contains(scenario, investment2)
                    % Check that it's exactly these two investments
                    is_active = zeros(1, length(investments));
                    for m = 1:length(investments)
                        is_active(m) = contains(scenario, investments{m});
                    end
                    if sum(is_active) == 2
                        with_scenario = scenario;
                        break;
                    end
                end
            end
            
            if isempty(with_scenario)
                continue;
            end
            
            fprintf('  Analyzing complementarity for %s with %s\n', investment1, investment2);
            
            % Get data for the "with" scenario
            with_benefits = raw_data.(with_scenario).net_value_pv_full ;
            with_costs = raw_data.(with_scenario).costs;
            
            % Find investment1's alone scenario
            alone1_scenario = [];
            for k = 1:length(surplus_scenarios)
                scenario = surplus_scenarios{k};
                if contains(scenario, investment1)
                    is_active = zeros(1, length(investments));
                    for m = 1:length(investments)
                        is_active(m) = contains(scenario, investments{m});
                    end
                    if sum(is_active) == 1
                        alone1_scenario = scenario;
                        break;
                    end
                end
            end
            
            if isempty(alone1_scenario)
                warning('No alone scenario found for %s', investment1);
                continue;
            end
            
            alone1_benefits = raw_data.(alone1_scenario).benefits;
            alone1_costs = raw_data.(alone1_scenario).costs;
            
            % Find investment2's alone scenario
            alone2_scenario = [];
            for k = 1:length(surplus_scenarios)
                scenario = surplus_scenarios{k};
                if contains(scenario, investment2)
                    is_active = zeros(1, length(investments));
                    for m = 1:length(investments)
                        is_active(m) = contains(scenario, investments{m});
                    end
                    if sum(is_active) == 1
                        alone2_scenario = scenario;
                        break;
                    end
                end
            end
            
            if isempty(alone2_scenario)
                warning('No alone scenario found for %s', investment2);
                continue;
            end
            
            alone2_benefits = raw_data.(alone2_scenario).benefits;
            alone2_costs = raw_data.(alone2_scenario).costs;
            
            % Analyze benefit complementarity
            row_idx = row_idx + 1;
            analyze_complementarity_variable(with_benefits, alone1_benefits, alone2_benefits, ...
                investment1, investment2, 'Benefits', ...
                n_bootstrap, n_iterations, figures_dir, ...
                comp_bias_results, comp_skew_results, comp_percentile_results, row_idx);
            
            % Analyze cost complementarity
            row_idx = row_idx + 1;
            analyze_complementarity_variable(with_costs, alone1_costs, alone2_costs, ...
                investment1, investment2, 'Costs', ...
                n_bootstrap, n_iterations, figures_dir, ...
                comp_bias_results, comp_skew_results, comp_percentile_results, row_idx);
        end
    end
    
    % Trim tables to actual size
    comp_bias_results = comp_bias_results(1:row_idx, :);
    comp_skew_results = comp_skew_results(1:row_idx, :);
    comp_percentile_results = comp_percentile_results(1:row_idx, :);
end

function analyze_complementarity_variable(with_data, alone_data, other_alone_data, ...
    investment, other_investment, var_name, ...
    n_bootstrap, n_iterations, figures_dir, ...
    bias_results, skew_results, percentile_results, row_idx)
    % Analyze bootstrap stability for a single complementarity variable
    
    % Compute sample complementarity
    sample_comp = mean(with_data) - mean(alone_data) - mean(other_alone_data);
    
    % 1. Bootstrap bias analysis
    tic;
    bootstrap_comps = bootstrp(n_bootstrap, ...
        @(w,a,o) mean(w) - mean(a) - mean(o), ...
        with_data, alone_data, other_alone_data);
    fprintf('      Bootstrap bias analysis for %s complementarity: %.2f seconds\n', var_name, toc);
    
    median_bootstrap_comp = median(bootstrap_comps);
    relative_bias = (median_bootstrap_comp - sample_comp) / abs(sample_comp);
    
    bias_results(row_idx, :) = {{investment}, {other_investment}, {var_name}, ...
        sample_comp, median_bootstrap_comp, relative_bias};
    
    % 2. Bootstrap mean skewness
    bootstrap_skew = skewness(bootstrap_comps);
    
    skew_results(row_idx, :) = {{investment}, {other_investment}, {var_name}, bootstrap_skew};
    
    % 3. Percentile stability across multiple bootstrap iterations
    tic;
    p2_5_values = zeros(n_iterations, 1);
    p5_values = zeros(n_iterations, 1);
    p95_values = zeros(n_iterations, 1);
    p97_5_values = zeros(n_iterations, 1);
    
    p2_5_rel_dist = zeros(n_iterations, 1);
    p5_rel_dist = zeros(n_iterations, 1);
    p95_rel_dist = zeros(n_iterations, 1);
    p97_5_rel_dist = zeros(n_iterations, 1);
    
    for iter = 1:n_iterations
        boot_samples = bootstrp(n_bootstrap, ...
            @(w,a,o) mean(w) - mean(a) - mean(o), ...
            with_data, alone_data, other_alone_data);
        boot_mean = mean(boot_samples);
        
        p2_5_values(iter) = prctile(boot_samples, 2.5);
        p5_values(iter) = prctile(boot_samples, 5);
        p95_values(iter) = prctile(boot_samples, 95);
        p97_5_values(iter) = prctile(boot_samples, 97.5);
        
        % Calculate relative distance from percentile to bootstrap mean
        p2_5_rel_dist(iter) = abs(p2_5_values(iter) - boot_mean) / abs(boot_mean);
        p5_rel_dist(iter) = abs(p5_values(iter) - boot_mean) / abs(boot_mean);
        p95_rel_dist(iter) = abs(p95_values(iter) - boot_mean) / abs(boot_mean);
        p97_5_rel_dist(iter) = abs(p97_5_values(iter) - boot_mean) / abs(boot_mean);
    end
    fprintf('      Percentile stability analysis for %s complementarity: %.2f seconds\n', var_name, toc);
    
    percentile_results(row_idx, :) = {{investment}, {other_investment}, {var_name}, ...
        mean(p2_5_values), std(p2_5_values), ...
        mean(p5_values), std(p5_values), ...
        mean(p95_values), std(p95_values), ...
        mean(p97_5_values), std(p97_5_values), ...
        mean(p2_5_rel_dist), std(p2_5_rel_dist), ...
        mean(p5_rel_dist), std(p5_rel_dist), ...
        mean(p95_rel_dist), std(p95_rel_dist), ...
        mean(p97_5_rel_dist), std(p97_5_rel_dist)};
    
    % Plot percentile stability
    tic;
    figure('Position', [100, 100, 1200, 900]);
    % Top subplot spanning full width
    subplot(3, 2, [1 2]);
    histogram(bootstrap_comps, 30, 'Normalization', 'pdf');
    hold on;
    xline(sample_comp, 'r--', 'LineWidth', 2);
    xline(median_bootstrap_comp, 'b--', 'LineWidth', 2);
    xlabel('Bootstrap Complementarity');
    ylabel('Density');
    title('Bootstrap Distribution');
    
    % Get x-axis limits from the bootstrap complementarity plot
    x_limits = xlim;
    
    % Bottom four subplots
    subplot(3, 2, 3);
    histogram(p2_5_values, 30);
    xlim(x_limits);
    xlabel('2.5th Percentile');
    ylabel('Frequency');
    title('2.5th Percentile Stability');
    
    subplot(3, 2, 4);
    histogram(p5_values, 30);
    xlim(x_limits);
    xlabel('5th Percentile');
    ylabel('Frequency');
    title('5th Percentile Stability');
    
    subplot(3, 2, 5);
    histogram(p95_values, 30);
    xlim(x_limits);
    xlabel('95th Percentile');
    ylabel('Frequency');
    title('95th Percentile Stability');
    
    subplot(3, 2, 6);
    histogram(p97_5_values, 30);
    xlim(x_limits);
    xlabel('97.5th Percentile');
    ylabel('Frequency');
    title('97.5th Percentile Stability');
    % Format titles
    sgtitle(sprintf('%s with %s - %s Complementarity', ...
        format_investment_name(investment), format_investment_name(other_investment), var_name));
    
    print(gcf, fullfile(figures_dir, sprintf('comp_%s_with_%s_%s_stability', ...
        investment, other_investment, var_name)), '-dpng', '-r600');
    close(gcf);
    fprintf('      Plotting for %s complementarity: %.2f seconds\n', var_name, toc);
end

function [accents, investment_indicators] = parse_scenario_name(scenario_names)
    % Parse scenario names to extract accent and investment indicators
    accents = cell(size(scenario_names));
    for i = 1:length(scenario_names)
        match = regexp(scenario_names{i}, '(bcr|surplus)$', 'match', 'once');
        if ~isempty(match)
            accents{i} = match;
        else
            accents{i} = '';
        end
    end
    
    investments = {'advance_capacity', 'early_warning', 'neglected_pathogen', 'universal_flu'};
    
    investment_indicators = table('Size', [length(scenario_names) 4], ...
        'VariableTypes', {'logical', 'logical', 'logical', 'logical'}, ...
        'VariableNames', investments);
    
    for i = 1:length(investments)
        investment_indicators.(investments{i}) = contains(scenario_names, investments{i});
    end
end

function formatted = format_investment_name(investment)
    % Format investment name for display
    clean_map = dictionary(["advance_capacity", "early_warning", "neglected_pathogen", "universal_flu"], ...
        ["Advance capacity", "Early warning", "Neglected pathogen R&D", "Universal flu vaccine R&D"]);
    
    if isKey(clean_map, investment)
        formatted = clean_map(investment);
    else
        formatted = strrep(investment, '_', ' ');
    end
end

function formatted = format_scenario_name(scenario_name)
    % Format scenario name for display
    formatted = strrep(scenario_name, '_', ' ');
    formatted = strrep(formatted, 'advance capacity', 'Advance capacity');
    formatted = strrep(formatted, 'early warning', 'Early warning');
    formatted = strrep(formatted, 'neglected pathogen', 'Neglected pathogen');
    formatted = strrep(formatted, 'universal flu', 'Universal flu');
    formatted = strrep(formatted, 'bcr', 'BCR');
    formatted = strrep(formatted, 'surplus', 'Surplus');
end

function formatted = format_variable_name(var_name)
    % Format variable name for display
    if contains(var_name, 'benefits')
        formatted = 'Benefits';
    elseif contains(var_name, 'costs')
        formatted = 'Costs';
    else
        formatted = strrep(var_name, '_', ' ');
    end
end
