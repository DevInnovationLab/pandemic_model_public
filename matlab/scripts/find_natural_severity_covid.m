% Example usage script
function find_natural_severity_covid
    addpath(genpath("./pandemic_model"));
    addpath(genpath("./yaml"));
    
    % Load params and overwrite with COVID-19 specific
    params = clean_job_config(yaml.loadFile("./config/job_configs/job_template.yaml"));
    params.tau_A = 11; % Months before vaccine available.
    params.rd_state = 1; % Both mRNA and traditional succeeded during COVID-19.
    duration = 5; % COVID-19 duration according to our records.
    monthly_cum_vax = readtable("./data/clean/covid19_cum_vax_over_time.csv");
    cum_vax_rate = monthly_cum_vax.cum_vax_rate;
    params.monthly_cum_vax = [zeros(params.tau_A, 1); cum_vax_rate]; % Vaccinations are zero before vaccine available.

    target_ex_post_severity = 9.17; % In Marani data
    fy_mortality_reduction = 0.63; % First year mortality reduction
    gamma_init = 0.2;
    ex_ante_severity_init = 10;
    
    % Set up optimization options
    options = optimoptions('fsolve', 'Display', 'iter', 'FunctionTolerance', 1e-6);
    
    % Define function handle for fsolve
    fit_func = @(x) fit_ex_ante_severity(x(1), x(2), target_ex_post_severity, ...
                                         duration, fy_mortality_reduction, params);
    
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
                                  duration, ...
                                  fy_mortality_reduction, ...
                                  params)
    % Get capacity from params
    cap_avail_m = params.x_avail * params.mRNA_share;
    cap_avail_o = params.x_avail * (1 - params.mRNA_share);
    econ_loss_model = load_econ_loss_model(params.econ_loss_model_config);

    % Set parameters that don't matter for mortality quantfication
    yr_start = 1; % Doesn't matter as won't do PV for deaths
    RD_benefit = 0;  % Set success time using tau_A
    run_params = params;
    run_params.gamma = gamma; % Should probably load gamma within the function.

    % Run pandemic
    [vax_fraction_cum_end, vax_benefits_PV, vax_benefits_nom, inp_marg_costs_m_PV, inp_marg_costs_o_PV, inp_marg_costs_m_nom, inp_marg_costs_o_nom, m_deaths_array, raw_deaths_array] = ...
        run_pandemic(run_params, econ_loss_model, params.tau_A, RD_benefit, yr_start, duration, duration, params.rd_state, ex_ante_severity, cap_avail_m, cap_avail_o);
    
    vaccine_start_month = run_params.tau_A + 1;
    year_available_month = vaccine_start_month + 12;
    fy_idx = vaccine_start_month:year_available_month;
    m_deaths_array = max(m_deaths_array, 0);
    share_deaths_mitigated = sum(raw_deaths_array(fy_idx) - m_deaths_array(fy_idx)) / sum(raw_deaths_array(fy_idx));
    ex_post_severity = sum(m_deaths_array) / (run_params.P0 / 10000);

    % Check closeness to targets.
    severity_diff = ex_post_severity - target_ex_post_severity;
    m_reduction_diff = share_deaths_mitigated - fy_mortality_reduction;

    F = [severity_diff; m_reduction_diff];
    
end