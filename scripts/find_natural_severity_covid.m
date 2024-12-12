% Example usage script
function find_natural_severity_covid
    addpath(genpath("./pandemic_model"));
    addpath(genpath("./yaml"));
    
    % Load params and overwrite with COVID-19 specific
    params = clean_job_config(yaml.loadFile("./config/job_configs/job_template.yaml"));
    params.tau_A = 11; % Months before vaccine available.
    params.rd_state = 1; % Both mRNA and traditional succeeded during COVID-19.

    target_ex_post_severity = 9.17; % In Marani data
    init_severity_min = target_ex_post_severity;
    init_severity_max = 60;
    tolerance = 0.01;
    
    duration_grid = (5:10)';
    ex_ante_severities = zeros(size(duration_grid));

    for i = 1:length(duration_grid)
        duration = duration_grid(i);
        [ex_ante_severity, ~] = recurse_ex_ante_severity(target_ex_post_severity, ...
                                                         init_severity_min, ...
                                                         init_severity_max, ...
                                                         tolerance, ...
                                                         duration, ...
                                                         params);
        ex_ante_severities(i) = ex_ante_severity;

    end

    results = array2table(zeros(length(ex_ante_severities), 2), 'VariableNames', ["duration", "ex_ante_severities"]);
    results.duration = duration_grid;
    results.ex_ante_severities = ex_ante_severities;
    
    disp(results)
end


function [ex_ante_severity, results] = recurse_ex_ante_severity(target_ex_post_severity, severity_grid_min, severity_grid_max, tolerance, duration, params)
    % Get capacity from params
    cap_avail_m = params.x_avail * params.mRNA_share;
    cap_avail_o = params.x_avail * (1 - params.mRNA_share);
    econ_loss_model = load_econ_loss_model(params.econ_loss_model_config);

    % Set parameters that don't matter for mortality quantfication
    yr_start = 1; % Doesn't matter as won't do PV for deaths
    RD_benefit = 0;  % Just set success time using tau_A

    % Initial coarse grid
    num_points = 10;
    severity_grid = linspace(severity_grid_min, severity_grid_max, num_points);
    results = array2table(zeros(length(severity_grid), 2), 'VariableNames', ["ex_ante_severity", "ex_post_severity"]);

    % Perform grid search
    for i = 1:length(severity_grid)
        ex_ante_severity = severity_grid(i);

        [vax_fraction_cum_end, vax_benefits_PV, vax_benefits_nom, inp_marg_costs_m_PV, inp_marg_costs_o_PV, inp_marg_costs_m_nom, inp_marg_costs_o_nom, deaths_array] = ...
            run_pandemic(params, econ_loss_model, params.tau_A, RD_benefit, yr_start, duration, duration, params.rd_state, ex_ante_severity, cap_avail_m, cap_avail_o);

        results.ex_ante_severity(i) = ex_ante_severity;
        results.ex_post_severity(i) = sum(deaths_array) / (params.P0 / 10000);
    end
    
    % Sort results by difference from target
    results.difference = results.ex_post_severity - target_ex_post_severity;

    if any(abs(results.difference) < tolerance) % Found good enough ex ante severity
        [~, smallest_diff_idx] = min(abs(results.difference));
        ex_ante_severity = results.ex_ante_severity(smallest_diff_idx);
    elseif all(results.difference < 0) % All grid points underestimates
        severity_grid_min_new = severity_grid_max;
        severity_grid_max_new = severity_grid_max * 10; % Maybe make this a param later
        [ex_ante_severity, results] = recurse_ex_ante_severity(target_ex_post_severity, severity_grid_min_new, severity_grid_max_new, tolerance, duration, params);
    elseif all(results.difference > 0) % All grid points overestimates
        severity_grid_min_new = severity_grid_min / 10;
        severity_grid_max_new = severity_grid_min;
        [ex_ante_severity, results] = recurse_ex_ante_severity(target_ex_post_severity, severity_grid_min_new, severity_grid_max_new, tolerance, duration, params);
    else % Grid changes sign; refine
        results = sortrows(results, 'difference');
        sign_change_idx = find(results.difference >= 0, 1);
        severity_grid_min_new = results.ex_ante_severity(sign_change_idx - 1);
        severity_grid_max_new = results.ex_ante_severity(sign_change_idx);
        [ex_ante_severity, results] = recurse_ex_ante_severity(target_ex_post_severity, severity_grid_min_new, severity_grid_max_new, tolerance, duration, params);
    end

end