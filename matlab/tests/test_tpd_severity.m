% Test script for TPDSeverityDist get_severity functionality

% Load the TPD severity distribution from config
config_path = './output/arrival_distributions/truncpareto_all_risk.yaml';
severity_dist = load_severity_dist(config_path);

% Test 1: Basic functionality with single value
test_val = 0.5; % Middle of valid range
severity = severity_dist.get_severity(test_val);
assert(isnumeric(severity) && isscalar(severity), 'Test 1 failed: Output should be numeric scalar');
assert(severity >= severity_dist.min_severity && severity <= severity_dist.max_severity, ...
    'Test 1 failed: Severity outside valid range');

% Test 2: Vector input
test_vec = linspace(0, 1, 100);
severities = severity_dist.get_severity(test_vec);
assert(isnumeric(severities) && length(severities) == length(test_vec), ...
    'Test 2 failed: Output should be numeric vector of same length as input');
assert(all(severities >= severity_dist.min_severity & severities <= severity_dist.max_severity), ...
    'Test 2 failed: Some severities outside valid range');

% Test 3: Edge cases
edge_cases = [0, 1, severity_dist.arrival_rate];
edge_severities = severity_dist.get_severity(edge_cases);
assert(all(~isnan(edge_severities)), 'Test 3 failed: Edge cases produced NaN values');
assert(all(isfinite(edge_severities)), 'Test 3 failed: Edge cases produced infinite values');

% Test 4: Matrix input
test_matrix = rand(10, 10);
matrix_severities = severity_dist.get_severity(test_matrix);
assert(isequal(size(matrix_severities), size(test_matrix)), ...
    'Test 4 failed: Output matrix should have same dimensions as input');

% Test 5: Verify minimum severity threshold behavior
below_threshold = rand(1, 100) * (1 - severity_dist.arrival_rate);
below_severities = severity_dist.get_severity(below_threshold);
assert(all(abs(below_severities - severity_dist.min_severity) < 1e-10), ...
    'Test 5 failed: Values below threshold should equal min_severity');

% Test 6: Verify maximum severity threshold behavior
above_threshold = ones(1, 100);
above_severities = severity_dist.get_severity(above_threshold);
assert(all(abs(above_severities - severity_dist.max_severity) < 1e-10), ...
    'Test 6 failed: Values at probability 1 should equal max_severity');

disp('All tests passed successfully');
