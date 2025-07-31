% Load config and get scenarios
config = yaml.loadFile(fullfile(results_dir, "job_config.yaml"));
scenarios = string(fieldnames(config.scenarios));
rawdata_dir = fullfile(results_dir, "raw");

% Define cost variables
cost_vars = {'adv_cap', 'prototype_RD', 'inp_cap', 'inp_marg', 'inp_RD', 'surveil'};

% Get baseline costs for each variable and benefits
baseline_costs = cell(length(cost_vars), 1);
for i = 1:length(cost_vars)
    var = cost_vars{i};
    baseline_costs{i} = readmatrix(fullfile(rawdata_dir, strcat("baseline_ts_", var, "_p.csv")));
end
baseline_benefits = readmatrix(fullfile(rawdata_dir, "baseline_ts_benefits.csv"));

% Get final cumulative values for baseline
baseline_total_costs = cellfun(@(x) sum(x, 2), baseline_costs, 'UniformOutput', false);
baseline_total_benefits = sum(baseline_benefits, 2);

% Compare each non-baseline scenario
delta_scenarios = scenarios(~strcmp(scenarios, 'baseline'));
for i = 1:length(delta_scenarios)
    scenario = delta_scenarios(i);
    fprintf('\nScenario: %s\n', scenario);
    fprintf('----------------------------------------\n');
    
    % Load scenario costs for each variable
    scenario_costs = cell(length(cost_vars), 1);
    for j = 1:length(cost_vars)
        var = cost_vars{j};
        scenario_costs{j} = readmatrix(fullfile(rawdata_dir, strcat(scenario, "_ts_", var, "_p.csv")));
    end
    scenario_benefits = readmatrix(fullfile(rawdata_dir, strcat(scenario, "_ts_benefits.csv")));
    
    % Get final cumulative values for scenario
    scenario_total_costs = cellfun(@(x) sum(x, 2), scenario_costs, 'UniformOutput', false);
    scenario_total_benefits = scenario_benefits(:,end);
    
    % Compare each cost variable and save indices
    cost_indices = cell(length(cost_vars), 1);
    for j = 1:length(cost_vars)
        var = cost_vars{j};
        higher_costs = find(baseline_total_costs{j} > scenario_total_costs{j});
        cost_indices{j} = higher_costs;
        
        fprintf('\nCost variable: %s\n', var);
        fprintf('Number of simulations with higher baseline costs: %d\n', length(higher_costs));
 
    end
    
    % Compare benefits and save indices
    higher_benefits = find(baseline_total_benefits > scenario_total_benefits);
    fprintf('\nBenefits:\n');
    fprintf('Number of simulations with higher baseline benefits: %d\n', length(higher_benefits));
    fprintf('\n========================================\n');
end


