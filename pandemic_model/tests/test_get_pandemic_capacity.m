function tests = test_get_pandemic_capacity
    % Test suite for get_pandemic_capacity function
    tests = functiontests(localfunctions);
end

function test_basic_scenario(testCase)
    % Test a basic scenario with simple input parameters
    months = (1:6)';
    tau_A = 0;
    params = struct(...
        'tau_m', 3, ...   % mRNA repmaturposing time
        'tau_o', 4, ...   % Traditional capacity repmaturposing
        'f_m', 0.5, ...   % mRNA capacity initial succeed
        'g_m', 0.3, ...   % mRNA capacity repmaturposed
        'f_o', 0.4, ...   % Traditional vaccine initial succeed
        'g_o', 0.2 ...    % Traditional vaccine repmaturposed
    );
    ind_m = 1;  % mRNA vaccine indicator
    ind_o = 1;  % Traditional vaccine indicator
    x_m_tau = 100;  % Initial mRNA vaccine production capacity
    x_o_tau = 80;   % Initial traditional vaccine production capacity
    
    % Call the function
    capacity = get_pandemic_capacity(months, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau);
    
    % Verify the structure of the output
    testCase.verifyClass(capacity, 'table');
    testCase.verifyEqual(size(capacity, 1), length(months));
    testCase.verifyEqual(capacity.Properties.VariableNames, {'month', 'trad', 'mrna', 'total'});
    
    % Check calculations during and after vaccine development
    % mRNA vaccine
    exp_mrna_before = x_m_tau * params.f_m;
    exp_mrna_after = x_m_tau * (params.f_m + params.g_m);
    
    % Traditional vaccine
    exp_trad_before = x_o_tau * params.f_o;
    exp_trad_after = x_o_tau * (params.f_o + params.g_o);

    % For months before vaccine development
    testCase.verifyEqual(capacity.mrna(1:3), exp_mrna_before .* ones(3, 1), 'AbsTol', 1e-10);
    testCase.verifyEqual(capacity.trad(1:4), exp_trad_before .* ones(4, 1), 'AbsTol', 1e-10);
    testCase.verifyEqual(capacity.mrna(4:end), exp_mrna_after .* ones(3, 1), 'AbsTol', 1e-10);
    testCase.verifyEqual(capacity.trad(5:end), exp_trad_after .* ones(2, 1), 'AbsTol', 1e-10);
end

function test_zero_indicators(testCase)
    % Test scenario with zero indicators for both vaccine types
    months = (1:6)';
    tau_A = 0;
    params = struct(...
        'tau_m', 3, ...
        'tau_o', 4, ...
        'f_m', 0.5, ...
        'g_m', 0.3, ...
        'f_o', 0.4, ...
        'g_o', 0.2 ...
    );
    ind_m = 0;  % mRNA vaccine indicator set to zero
    ind_o = 0;  % Traditional vaccine indicator set to zero
    x_m_tau = 100;
    x_o_tau = 80;
    
    % Call the function
    capacity = get_pandemic_capacity(months, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau);
    
    % Verify all capacity values are zero
    testCase.verifyEqual(capacity.mrna, zeros(size(months)), 'AbsTol', 1e-10);
    testCase.verifyEqual(capacity.trad, zeros(size(months)), 'AbsTol', 1e-10);
    testCase.verifyEqual(capacity.total, zeros(size(months)), 'AbsTol', 1e-10);
end

function test_different_tau_A(testCase)
    % Test with a non-zero tau_A (delayed start)
    months = (1:6)';
    tau_A = 2;  % Delayed start by 2 months
    params = struct(...
        'tau_m', 3, ...
        'tau_o', 4, ...
        'f_m', 0.5, ...
        'g_m', 0.3, ...
        'f_o', 0.4, ...
        'g_o', 0.2 ...
    );
    ind_m = 1;
    ind_o = 1;
    x_m_tau = 100;
    x_o_tau = 80;
    
    % Call the function
    capacity = get_pandemic_capacity(months, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau);
    exp_mrna_before = x_m_tau * params.f_m;
    exp_mrna_after = x_m_tau * (params.f_m + params.g_m);
    exp_trad_before = x_o_tau * params.f_o;
    exp_trad_after = x_o_tau * (params.f_o + params.g_o);
    
    % Verify delayed start
    testCase.verifyEqual(capacity.mrna(1:2), zeros(2,1), 'AbsTol', 1e-10);
    testCase.verifyEqual(capacity.trad(1:2), zeros(2,1), 'AbsTol', 1e-10);

    testCase.verifyEqual(capacity.mrna(3:5), exp_mrna_before .* ones(3, 1), 'AbsTol', 1e-10)
    testCase.verifyEqual(capacity.trad(3:6), exp_trad_before .* ones(4, 1), 'AbsTol', 1e-10)
    testCase.verifyEqual(capacity.mrna(6), exp_mrna_after, 'AbsTol', 1e-10)
end
