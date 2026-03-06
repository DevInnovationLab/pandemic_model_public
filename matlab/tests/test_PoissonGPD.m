% Tests for PoissonGPD class (CDF and ICDF of Poisson-GPD maximum distribution).
% Uses scalar parameters; CDF/ICDF round-trips and boundary checks.

function tests = test_PoissonGPD
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Single set of parameters for most tests.
    testCase.TestData.lambda = 0.5;
    testCase.TestData.xi = 0.1;
    testCase.TestData.sigma = 2;
    testCase.TestData.mu = 1;
    testCase.TestData.max_value = 20;
    testCase.TestData.dist = PoissonGPD(...
        testCase.TestData.lambda, ...
        testCase.TestData.xi, ...
        testCase.TestData.sigma, ...
        testCase.TestData.mu, ...
        testCase.TestData.max_value);
end

function test_cdf_at_threshold(testCase)
    % CDF at threshold μ must equal P(N=0) = exp(-λ).
    d = testCase.TestData.dist;
    mu = testCase.TestData.mu;
    lambda = testCase.TestData.lambda;
    p0 = exp(-lambda);
    cdf_mu = d.cdf(mu);
    verifyEqual(testCase, cdf_mu, p0, 'RelTol', 1e-10);
end

function test_cdf_below_threshold(testCase)
    % CDF for x < μ should also be exp(-λ) (no excess above threshold).
    d = testCase.TestData.dist;
    lambda = testCase.TestData.lambda;
    p0 = exp(-lambda);
    x_below = [0, testCase.TestData.mu - 0.1];
    verifyEqual(testCase, d.cdf(x_below), repmat(p0, size(x_below)), 'RelTol', 1e-10);
end

function test_cdf_at_and_above_max_value(testCase)
    % CDF above max_value must be 1; at max_value it is exp(-λ*(1-G(max_value))) < 1.
    d = testCase.TestData.dist;
    maxv = testCase.TestData.max_value;
    verifyEqual(testCase, d.cdf(maxv + 100), 1, 'RelTol', 1e-10);
    verifyTrue(testCase, d.cdf(maxv) <= 1 && d.cdf(maxv) >= exp(-testCase.TestData.lambda), ...
        'CDF at max_value should be in [exp(-λ), 1]');
end

function test_cdf_non_decreasing(testCase)
    % CDF must be non-decreasing in x.
    d = testCase.TestData.dist;
    mu = testCase.TestData.mu;
    maxv = testCase.TestData.max_value;
    x = linspace(mu - 0.5, maxv + 5, 200);
    F = d.cdf(x);
    verifyTrue(testCase, all(diff(F) >= -1e-10), 'CDF should be non-decreasing');
end

function test_icdf_at_low_probability(testCase)
    % ICDF(p) = μ for p <= exp(-λ).
    d = testCase.TestData.dist;
    mu = testCase.TestData.mu;
    lambda = testCase.TestData.lambda;
    p0 = exp(-lambda);
    verifyEqual(testCase, d.icdf(0), mu, 'RelTol', 1e-10);
    verifyEqual(testCase, d.icdf(p0), mu, 'RelTol', 1e-10);
    verifyEqual(testCase, d.icdf(p0 * 0.5), mu, 'RelTol', 1e-10);
end

function test_icdf_at_high_probability(testCase)
    % ICDF(p) = max_value for p >= cdf(max_value).
    d = testCase.TestData.dist;
    maxv = testCase.TestData.max_value;
    p_max = d.cdf(maxv);
    verifyEqual(testCase, d.icdf(p_max), maxv, 'RelTol', 1e-10);
    verifyEqual(testCase, d.icdf(1), maxv, 'RelTol', 1e-10);
end

function test_icdf_never_exceeds_max_value(testCase)
    % ICDF must always be <= max_value (truncation).
    d = testCase.TestData.dist;
    maxv = testCase.TestData.max_value;
    p = linspace(0, 1, 500);
    q = d.icdf(p);
    verifyTrue(testCase, all(q <= maxv + 1e-10), 'ICDF must not exceed max_value');
end

function test_cdf_icdf_round_trip_x(testCase)
    % ICDF(CDF(x)) ≈ x for x in [μ, max_value].
    d = testCase.TestData.dist;
    mu = testCase.TestData.mu;
    maxv = testCase.TestData.max_value;
    x = linspace(mu, maxv, 50);
    F = d.cdf(x);
    x_back = d.icdf(F);
    verifyEqual(testCase, x_back, x, 'RelTol', 1e-8);
end

function test_cdf_icdf_round_trip_p(testCase)
    % CDF(ICDF(p)) ≈ p for p in [exp(-λ), cdf(max_value)].
    d = testCase.TestData.dist;
    lambda = testCase.TestData.lambda;
    p0 = exp(-lambda);
    p_max = d.cdf(testCase.TestData.max_value);
    p = linspace(p0, p_max, 50);
    x = d.icdf(p);
    p_back = d.cdf(x);
    verifyEqual(testCase, p_back, p, 'RelTol', 1e-8);
end

function test_survival_function(testCase)
    % sf(x) = 1 - cdf(x).
    d = testCase.TestData.dist;
    x = linspace(testCase.TestData.mu, testCase.TestData.max_value, 20);
    verifyEqual(testCase, d.sf(x), 1 - d.cdf(x), 'RelTol', 1e-10);
end

function test_vector_inputs(testCase)
    % Vector x and p produce same-sized outputs.
    d = testCase.TestData.dist;
    x = [1, 5, 10, 20];
    p = [0.5, 0.7, 0.9];
    verifyEqual(testCase, size(d.cdf(x)), size(x));
    verifyEqual(testCase, size(d.icdf(p)), size(p));
    verifyTrue(testCase, all(isfinite(d.cdf(x))) && all(isfinite(d.icdf(p))));
end

function test_no_nan_or_inf(testCase)
    % CDF and ICDF should be finite in the valid range.
    d = testCase.TestData.dist;
    x = linspace(testCase.TestData.mu, testCase.TestData.max_value, 100);
    p = linspace(exp(-testCase.TestData.lambda), 1, 100);
    verifyFalse(testCase, any(isnan(d.cdf(x))));
    verifyFalse(testCase, any(isnan(d.icdf(p))));
    verifyFalse(testCase, any(isinf(d.cdf(x))));
    verifyFalse(testCase, any(isinf(d.icdf(p))));
end
