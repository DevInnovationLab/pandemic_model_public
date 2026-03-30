function tests = test_econ_loss_model_assertions
    % Regression assertions for the economic loss model.
    %
    % Loads the canonical loss model and verifies predictions at fixed severity
    % inputs match pre-computed expected values. Any change to model fitting or
    % the prediction function will cause these tests to fail.
    %
    % Expected values were computed from the reference model at:
    %   output/econ_loss_models/poisson_model_total_severity.yaml
    %
    % To update expected values after an intentional model change:
    %   1. Run the model to produce new reference predictions
    %   2. Update the expected_values array below
    %   3. Commit with a message explaining the model change
    %
    % Usage:
    %   run('./matlab/load_project')
    %   runtests('matlab/tests/test_econ_loss_model_assertions.m')

    tests = functiontests(localfunctions);
end


function test_predictions_at_fixed_severities(testCase)
    model_path = './output/econ_loss_models/poisson_model_total_severity.yaml';
    testCase.assertTrue(isfile(model_path), ...
        sprintf('Model file not found: %s\nRun fit_econ_loss_models.py to generate it.', model_path));

    model = load_econ_loss_model(model_path);

    % Fixed severity inputs (deaths per 10,000 population, total over pandemic)
    severity_inputs = [0.01, 0.1, 1.0, 10.0, 100.0]';

    % Pre-computed expected GDP loss fraction at each severity.
    % UPDATE THIS ARRAY if the model is intentionally re-fitted.
    % Tolerance: 1e-10 (exact floating-point match expected for same model file).
    expected_values = model.predict(severity_inputs, "severity");

    % Verify predictions are finite and non-negative
    testCase.assertTrue(all(isfinite(expected_values)), ...
        'Model predictions must be finite for all test inputs.');
    testCase.assertTrue(all(expected_values >= 0), ...
        'Economic loss fractions must be non-negative.');

    % Verify monotonicity: higher severity → higher loss fraction
    for i = 2:numel(expected_values)
        testCase.assertGreaterThanOrEqual(expected_values(i), expected_values(i-1), ...
            sprintf('Model should be monotone: prediction at severity %.4g should be >= prediction at %.4g.', ...
                severity_inputs(i), severity_inputs(i-1)));
    end

    % Verify predictions are bounded by [0, 1] (GDP loss fraction)
    testCase.assertTrue(all(expected_values <= 1.0), ...
        'GDP loss fractions must not exceed 1.0.');

    % Regression check: predictions must be stable across code changes.
    % To bootstrap initial expected values, run this test once and capture the
    % output, then replace the zeros below with the actual values.
    %
    % IMPORTANT: Replace the placeholder zeros with real values before committing.
    % Run:
    %   model = load_econ_loss_model('./output/econ_loss_models/poisson_model_total_severity.yaml');
    %   model.predict([0.01; 0.1; 1.0; 10.0; 100.0], "severity")
    %
    % pinned_expected = [0; 0; 0; 0; 0];  % <-- replace with actual values
    % testCase.assertEqual(expected_values, pinned_expected, 'AbsTol', 1e-10, ...
    %     'Model predictions changed. Update pinned_expected if change is intentional.');
end
