% Create a plot visualizing the piecewise linear h function for vaccination damage mitigation
%
% The h function maps vaccination fractions to damage mitigation factors according to:
% h(0)     = 0
% h(0.13)  = 0.395 
% h(0.5)   = 0.816
% h(>=0.7) = 1

% Create figure
spec = get_paper_figure_spec("double_col_standard");
fig = figure('Units', 'inches', 'Position', [1 1 spec.width_in spec.height_in], 'Visible', 'off');

% Generate x values
x = 0:0.001:1;

% Calculate h(x) values
y = h_function(x);

% Plot the function
plot(x, y, 'LineWidth', spec.stroke.primary, 'Color', [0, 0.4470, 0.7410])
hold on

% Add points at key transitions matching the definition in h_function.m
points_x = [0, 0.11, 0.40, 0.70]; % 0, lp, ld, lt from h_function.m
points_y = h_function(points_x);
scatter(points_x, points_y, 75, 'filled', 'MarkerFaceColor', [0.8500, 0.3250, 0.0980])

% Add styling
xlabel('Share population vaccinated', 'FontSize', spec.typography.axis_label, 'FontName', spec.font_name)
ylabel('Damage mitigation', 'FontSize', spec.typography.axis_label, 'FontName', spec.font_name)
xlim([0 1])
ylim([0 1.05])
ax = gca;
apply_paper_axis_style(ax, spec);
ax.XAxisLocation = 'bottom';
ax.YAxisLocation = 'left';

% Set ticks every 0.2 for both axes
ax.XTick = 0:0.2:1;
ax.YTick = 0:0.2:1;

% Add labels for transition points
text(0.02, 0.05, '(0, 0)', 'FontSize', spec.typography.tick, ...
    'FontName', spec.font_name, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'left')
text(0.12, h_function(0.11) - 0.03, sprintf('(%.2f, %.2f)', 0.11, h_function(0.11)), ...
    'FontSize', spec.typography.tick, 'FontName', spec.font_name, 'HorizontalAlignment', 'left')
text(0.41, h_function(0.40) - 0.03, sprintf('(%.2f, %.2f)', 0.40, h_function(0.40)), ...
    'FontSize', spec.typography.tick, 'FontName', spec.font_name, 'HorizontalAlignment', 'left')
text(0.71, 0.98, '(0.70, 1)', 'FontSize', spec.typography.tick, 'FontName', spec.font_name, ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left')

% Save figure as a vector PDF
export_figure(fig, './output/h_function.pdf');
close(fig)
