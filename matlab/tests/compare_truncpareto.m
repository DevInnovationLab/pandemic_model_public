
severity_dist_config = "./output/arrival_distributions/all_risk.yaml";
severity_dist = load_severity_dist(severity_dist_config);
severity_dist.pd = truncate(severity_dist.pd, 0.01, 1e4);
py_results = readtable("./output/arrival_distributions/truncpareto_sims.csv");

quantiles = py_results.rank;
m_severities = severity_dist.pd.icdf(quantiles);
p_severities = py_results.severity;
% Create figure and plot both CDFs - linear scale
figure();
plot(m_severities, quantiles, 'b-', 'LineWidth', 1.5, 'DisplayName', 'MATLAB');
hold on;
plot(p_severities, quantiles, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Python');

% Customize plot appearance
grid on;
xlabel('Severity (Deaths / 10,000)');
ylabel('Cumulative Probability');
set(gcf, 'Position', get(gcf, 'Position') .* [1 1 1 1.2]); % Make figure 20% taller
title('Comparison of Truncated Pareto CDFs: MATLAB vs Python Implementation', 'Units', 'normalized', 'Position', [0.5, 1.02, 0]);
legend('show');

% Save the linear scale figure as vector PDF
exportgraphics(gcf, './output/truncpareto_cdf_comparison_linear.pdf', ...
    'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');

% Create figure and plot both CDFs - log scale
figure();
plot(m_severities, quantiles, 'b-', 'LineWidth', 1.5, 'DisplayName', 'MATLAB');
hold on;
plot(p_severities, quantiles, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Python');

% Customize plot appearance
grid on;
set(gca, 'XScale', 'log');
xlabel('Severity (Deaths / 10,000)');
ylabel('Cumulative Probability');
set(gcf, 'Position', get(gcf, 'Position') .* [1 1 1 1.2]); % Make figure 20% taller
title('Comparison of Truncated Pareto CDFs: MATLAB vs Python Implementation', 'Units', 'normalized', 'Position', [0.5, 1.02, 0]);
legend('show');

% Save the log scale figure as vector PDF
exportgraphics(gcf, './output/truncpareto_cdf_comparison_log.pdf', ...
    'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
