% Create model instance
model = load_econ_loss_model('./output/econ_loss_models/poisson_model_total_severity.yaml');

% Generate test data points
x = logspace(-6, 4, 1000)'; % Severity in SMUs (deaths per 10,000)
y_pred = model.predict(x, "severity");

% Plot results
figure;
plot(x, y_pred * 100, 'LineWidth', 2); % Convert to percentage
set(gca, 'XScale', 'log');
grid on;

xlabel('Severity (deaths per 10,000 people, total over pandemic)');
ylabel('GDP loss (%)');
title('Economic loss model predictions');

% Load and plot raw data points for comparison
raw_data = readtable('./data/raw/Economic damages source review.xlsx', 'Sheet', 'Updated numbers', 'VariableNamingRule', 'Preserve');
hold on;
scatter(raw_data.("Mortality (SMU)"), raw_data.("Fraction output loss over total horizon") * 100, 80, 'filled', 'MarkerFaceAlpha', 0.7);

% Annotate points with disease names
for i = 1:height(raw_data)
    if ~isnan(raw_data.("Mortality (SMU)")(i))
        text(raw_data.("Mortality (SMU)")(i)*1.2, ...
             raw_data.("Fraction output loss over total horizon")(i)*100*0.98, ...
             raw_data.Disease{i}, ...
             'FontSize', 10);
    end
end

legend('Model Prediction', 'Historical Data', 'Location', 'northwest');

% Save the figure as vector PDF
exportgraphics(gcf, './output/tests/econ_loss_model_predictions.pdf', ...
    'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
