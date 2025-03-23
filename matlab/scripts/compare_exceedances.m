% Compare Madhav et al. exceedance and our respiratory risk exceedance function. 

outdir = fullfile("./output/jobs/airborne_base");
rawdir = fullfile(outdir, "raw");

sim_results = readtable(fullfile(rawdir, "baseline_pandemic_table.csv"));
job_config = yaml.loadFile(fullfile(outdir, "job_config.yaml"));

% Get severities from simulations
ex_ante_severity = sim_results.severity;
ex_post_severity = sim_results.ex_post_severity;
num_draws = job_config.sim_periods * job_config.num_simulations;

% Sort severities separately
ex_ante_severity_sorted = sort(ex_ante_severity);
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
exceedance = (height(ex_ante_severity_sorted):-1:1)' / num_draws;

% Create figure with appropriate size and style
fig = figure('Position', [100 100 800 600]);
hold on;

% Plot exceedance functions
ex_ante_color = [0 0.4470 0.7410];
ex_post_color = [0.8500 0.3250 0.0980];

plot(ex_ante_severity_sorted, exceedance, 'LineWidth', 2, 'Color', ex_ante_color, 'DisplayName', 'Without vaccination');
plot(ex_post_severity_sorted, exceedance, 'LineWidth', 2, 'Color', ex_post_color, 'DisplayName', 'With baseline vaccination');

% Plot Madhav data
madhav_color = [0.4940 0.1840 0.5560];
plot(madhav_severity_central, madhav_exceedance_central / 100', ...
    'LineWidth', 2, 'Color', madhav_color, 'DisplayName', 'Madhav et al. (2023)');

% Customize plot appearance
set(gca, 'XScale', 'log');
grid on;
box off;

% Add labels and title
xlabel('Severity (Deaths per 10,000)', 'FontSize', 12);
ylabel('Exceedance Probability', 'FontSize', 12);
title('Exceedance function comparison', 'FontSize', 16, 'FontWeight', 'normal');

% Add direct labels to lines
text(madhav_severity_central(2), madhav_exceedance_central(2)/100, ['Madhav et al.' '(2023)'], ...
    'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', madhav_color);
text(ex_ante_severity_sorted(1), exceedance(1), 'Without vaccination', ...
    'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', ex_ante_color);
text(ex_post_severity_sorted(20000), exceedance(20000), 'With baseline vaccination', ...
    'FontSize', 11, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'Color', ex_post_color);

% Remove legend since we're using direct labels
legend('off');

% Set axis limits based on all data including Madhav
xlim([min([ex_ante_severity_sorted; ex_post_severity_sorted; madhav_exceedances.severity_central]) ...
      max([ex_ante_severity_sorted; ex_post_severity_sorted; madhav_exceedances.severity_central])]);
    
print(fig, fullfile(outdir, "resp_exeedance_comparison.png"), '-dpng', '-r400');