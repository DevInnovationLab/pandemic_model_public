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
y = h(x);

% Plot the function
plot(x, y, 'LineWidth', 2, 'Color', [0, 0.4470, 0.7410])
hold on

% Add points at key transitions
points_x = [0, 0.13, 0.5, 0.7];
points_y = [0, 0.395, 0.816, 1];
scatter(points_x, points_y, 75, 'filled', 'MarkerFaceColor', [0.8500, 0.3250, 0.0980])

% Add styling
grid on
box off
xlabel('Share population vaccinated', 'FontSize', 14)
ylabel('Damage mitigation', 'FontSize', 14)
title('Vaccination damage mitigation (h(x))', 'FontSize', 18, 'FontWeight', 'Normal')
set(gca, 'FontSize', 11)
xlim([0 1.05])
ylim([0 1.05])
ax = gca;
ax.XAxisLocation = 'bottom';
ax.YAxisLocation = 'left';

% Add labels for key points
text(0.02, 0.03, '(0, 0)', 'FontSize', 11)
text(0.15, 0.40, '(0.13, 0.395)', 'FontSize', 11)
text(0.53, 0.816, '(0.5, 0.816)', 'FontSize', 11)
text(0.7, 0.97, '(0.7, 1)', 'FontSize', 11)

% Save figure
print(fig, './output/h_function.png', '-dpng', '-r600');
close(fig)
