% Add paths
addpath(genpath("./pandemic_model"));
addpath(genpath("./yaml"));

outdir = fullfile("./output/job_template/raw");
sim_results = readtable(fullfile(outdir, "scenario_template_results.xlsx"));
job_config = yaml.loadFile(fullfile(outdir, "job_config.yaml"));
arrival_dist = load_arrival_dist(job_config.arrival_dist_config);

% Get severities from simulations
ex_ante_severity = sim_results.severity;
ex_post_severity = sim_results.ex_post_severity;
num_draws = job_config.sim_periods * job_config.num_simulations;


% Sort severities separately
ex_ante_severity_sorted = sort(ex_ante_severity);
ex_ante_eff_severity_sorted = sort(ex_ante_eff_severity); 
ex_post_severity_sorted = sort(ex_post_severity);

% Load Madhav data
madhav_exceedances = readtable("./data/clean/madhav_et_al_severity_exceedance.csv");

[madhav_severity_central, central_idx] = sort(madhav_exceedances.severity_central);
madhav_exceedance_central = madhav_exceedances.exceedance_central(central_idx);

[madhav_severity_upper, upper_idx] = sort(madhav_exceedances.severity_upper);
madhav_exceedance_upper = madhav_exceedances.exceedance_upper(upper_idx);

[madhav_severity_lower, lower_idx] = sort(madhav_exceedances.severity_lower);
madhav_exceedance_lower = madhav_exceedances.exceedance_lower(lower_idx);


% Calculate exceedance probabilities
exceedance = (height(ex_ante_severity_sorted):-1:1)' ./ num_draws;

% Create figure with appropriate size and style
fig = figure('Position', [100 100 800 600]);
hold on;

% Plot exceedance functions
plot(ex_ante_severity_sorted, exceedance, 'LineWidth', 2, 'Color', [0 0.4470 0.7410], 'DisplayName', 'Ex Ante Severity');
plot(ex_post_severity_sorted, exceedance, 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980], 'DisplayName', 'Ex Post Severity');

% Plot Madhav data
plot(madhav_severity_central, madhav_exceedance_central / 100', ...
    'LineWidth', 2, 'Color', [0.4940 0.1840 0.5560], 'DisplayName', 'Madhav et al. Central');
% Plot Madhav upper and lower curves
plot(madhav_severity_upper, madhav_exceedance_upper / 100', ...
    'LineWidth', 1.5, 'LineStyle', '--', 'Color', [0.4940 0.1840 0.5560], 'DisplayName', 'Madhav et al. Upper');
plot(madhav_severity_lower, madhav_exceedance_lower / 100', ...
    'LineWidth', 1.5, 'LineStyle', '--', 'Color', [0.4940 0.1840 0.5560], 'DisplayName', 'Madhav et al. Lower');


% Customize plot appearance
set(gca, 'XScale', 'log');
grid on;
box off;

% Add labels and title
xlabel('Severity (Deaths per 10,000)', 'FontSize', 12);
ylabel('Exceedance Probability', 'FontSize', 12);
title('Pandemic Severity Exceedance Functions', 'FontSize', 14, 'FontWeight', 'bold');

% Add legend
legend('Location', 'southwest', 'FontSize', 11);

% Set axis limits based on all data including Madhav
xlim([min([ex_ante_severity_sorted; ex_ante_eff_severity_sorted; ex_post_severity_sorted; madhav_exceedances.severity_central]) ...
      max([ex_ante_severity_sorted; ex_ante_eff_severity_sorted; ex_post_severity_sorted; madhav_exceedances.severity_central])]);
    
saveas(fig, fullfile("./output/exceedance_figures/exeedance_comparison.jpg"));