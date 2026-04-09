% Create a plot visualizing the piecewise linear h function for vaccination damage mitigation
%
% The h function maps vaccination fractions to damage mitigation factors according to:
% h(0)     = 0
% h(0.13)  = 0.395 
% h(0.5)   = 0.816
% h(>=0.7) = 1

% Create figure
fig = figure('Position', [100 100 800 600], 'Visible', 'off');

% Generate x values
x = 0:0.001:1;

% Calculate h(x) values
y = vax_mitigation_factor(x);

% Plot the function
plot(x, y, 'LineWidth', 2, 'Color', [0, 0.4470, 0.7410])
hold on

% Add points at key transitions matching the definition in vax_mitigation_factor.m
points_x = [0, 0.11, 0.40, 0.70]; % 0, lp, ld, lt from vax_mitigation_factor.m
points_y = vax_mitigation_factor(points_x);
scatter(points_x, points_y, 75, 'filled', 'MarkerFaceColor', [0.8500, 0.3250, 0.0980])

% Add styling
grid on
box off
xlabel('Share population vaccinated', 'FontSize', 14, 'FontName', 'Arial')
ylabel('Damage mitigation', 'FontSize', 14, 'FontName', 'Arial')
set(gca, 'FontSize', 11, 'FontName', 'Arial')
xlim([0 1])
ylim([0 1.05])
ax = gca;
ax.XAxisLocation = 'bottom';
ax.YAxisLocation = 'left';

% Add labels for transition points
text(0.01, 0.07, '(0, 0)', 'FontSize', 11, 'FontName', 'Arial', 'VerticalAlignment', 'bottom')
text(0.13, vax_mitigation_factor(0.11) + 0.055, sprintf('(%.2f, %.2f)', 0.11, vax_mitigation_factor(0.11)), ...
    'FontSize', 11, 'FontName', 'Arial', 'HorizontalAlignment', 'center')
text(0.42, vax_mitigation_factor(0.40) + 0.06, sprintf('(%.2f, %.2f)', 0.40, vax_mitigation_factor(0.40)), ...
    'FontSize', 11, 'FontName', 'Arial', 'HorizontalAlignment', 'left')
text(0.73, 1.03, '(0.70, 1)', 'FontSize', 11, 'FontName', 'Arial', ...
    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left')

% Save figure as a vector PDF
exportgraphics(fig, './output/h_function.pdf', ...
    "ContentType", "vector", "Resolution", 600, "BackgroundColor", "none");
close(fig)
