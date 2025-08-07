% Example usage script
function find_natural_covid_deaths(config_path)
    
    % Load params and overwrite with COVID-19 specific
    params = yaml.loadFile(config_path);
    params.tau_a = 11; % Months before vaccine available.
    params.rd_state = 1; % Both mRNA and traditional succeeded during COVID-19.
    years = 5; % COVID-19 duration according to our records.

    % Load vaccination rates over time.
    monthly_cum_vax = readtable("./data/clean/covid19_cum_vax_over_time.csv");
    cum_vax_rate = monthly_cum_vax.cum_vax_rate;
    monthly_cum_vax = [zeros(params.tau_a, 1); cum_vax_rate]; % Vaccinations are zero before vaccine available.

    target_ex_post_severity = 9.17; % From Li et al. 2025
    fy_mortality_reduction = 0.63; % First year mortality reduction from vaccines. 
    gamma_init = 0.2;
    ex_ante_severity_init = 10;
    
    % Set up optimization options
    options = optimoptions('fsolve', 'Display', 'iter', 'FunctionTolerance', 1e-6);
    
    % Define function handle for fsolve
    fit_func = @(x) fit_ex_ante_severity(x(1), x(2), ...
                                         target_ex_post_severity, years, ...
                                         fy_mortality_reduction, monthly_cum_vax, params);
    
    % Initial guess for [ex_ante_severity, gamma]
    x0 = [ex_ante_severity_init, gamma_init];
    
    % Solve system of equations
    [x_sol, fval, exitflag] = fsolve(fit_func, x0, options);
    
    % Extract solutions
    ex_ante_severity = x_sol(1);
    gamma = x_sol(2);
    
    % Display results
    fprintf('Solved ex-ante severity: %.4f\n', ex_ante_severity);
    fprintf('Solved gamma: %.4f\n', gamma);
    fprintf('Function values at solution: [%.2e, %.2e]\n', fval(1), fval(2));
    
    % Consider writing output to file
    results.ex_ante_severity = ex_ante_severity;
    results.gamma = gamma;
    
    yaml.dumpFile("./data/clean/inverted_covid_severity.yaml", results);
end


function F = fit_ex_ante_severity(ex_ante_severity, ...
                                  gamma, ...
                                  target_ex_post_severity, ...
                                  years, ...
                                  fy_mortality_reduction, ...
                                  monthly_cum_vax, ...
                                  params)
    % Get vaccinations over time
    months = years * 12;
    exog_vax_length = size(monthly_cum_vax, 1);
    if exog_vax_length >= months
        vax_fractions_cum = exog_vax_length(1:months);
    else
        vax_fractions_cum =  ...
            [monthly_cum_vax; monthly_cum_vax(end) .* ones(months - exog_vax_length, 1)];
    end
    
    % Get ex post severity and share deaths mitigated
    h_arr = h(vax_fractions_cum);

    monthly_intensity = (ex_ante_severity ./ months);
    u_deaths = (params.P0 / 10000) .* monthly_intensity .* ones(size(h_arr));
    m_deaths = u_deaths .* (1 - h_arr) .* gamma;
    ex_post_severity = sum(m_deaths ./ (params.P0 / 10000), 1);
    
    vaccine_start_month = params.tau_a;
    year_available_month = vaccine_start_month + 12 - 1;
    fy_idx = vaccine_start_month:year_available_month;
    share_deaths_mitigated = sum(u_deaths(fy_idx) - m_deaths(fy_idx)) / sum(u_deaths(fy_idx));

    % Check closeness to targets.
    severity_diff = ex_post_severity - target_ex_post_severity;
    m_reduction_diff = share_deaths_mitigated - fy_mortality_reduction;

    F = [severity_diff; m_reduction_diff];
    
end