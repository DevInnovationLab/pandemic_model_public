function [ex_post_severity, results] = find_natural_severity_covid(params, econ_loss_model, tau_A, RD_benefit, yr_start, pandemic_natural_dur, actual_dur, rd_state, cap_avail_m, cap_avail_o, target_deaths)
    % Initialize search parameters
    min_severity = 0.1;   % Minimum severity to test
    max_severity = 50;    % Maximum severity to test
    tolerance = 0.1;      % Tolerance for acceptable deaths
    
    % Initialize results tracking
    results = struct('severity', [], 'deaths', [], 'difference', []);
    
    % Initial coarse grid
    num_points = 10;
    severity_grid = linspace(min_severity, max_severity, num_points);
    
    % Perform initial grid search
    for i = 1:length(severity_grid)
        ex_ante_severity = severity_grid(i);
        monthly_intensity = ex_ante_severity / (pandemic_natural_dur * 12);
        actual_dur_months = actual_dur * 12;
        [h_arr, vax_fraction_cum] = h_integral(params, actual_dur_months, cap_m_arr, cap_o_arr); % Vaccination damage mitigation

        % Calculate deaths
        monthly_mortality = (params.P0 / 10000) .* monthly_intensity;
        ex_post_severity = monthly_mortality .* actual_dur_months ;
        
        % Store results
        results(i).ex_ante_severity = ex_ante_severity;
        results(i).ex_post_severity =
        results(i).difference = abs(deaths_per_10k - target_deaths);
    end
    
    % Sort results by difference from target
    [~, idx] = sort([results.difference]);
    results = results(idx);
    
    % Narrow down search range
    best_results = results(1:3);
    min_severity = max(min_severity, min([best_results.severity]) - 2);
    max_severity = min(max_severity, max([best_results.severity]) + 2);
    
    % Refined search with more points in the promising range
    num_points = 20;
    severity_grid = linspace(min_severity, max_severity, num_points);
    refined_results = struct('severity', [], 'deaths', [], 'difference', []);
    
    for i = 1:length(severity_grid)
        severity = severity_grid(i);
        
        % Run pandemic simulation
        [~, vax_benefits_PV, vax_benefits_nom, inp_marg_costs_m_PV, inp_marg_costs_o_PV, inp_marg_costs_m_nom, inp_marg_costs_o_nom] = ...
            run_pandemic(params, econ_loss_model, tau_A, RD_benefit, yr_start, pandemic_natural_dur, actual_dur, rd_state, severity, cap_avail_m, cap_avail_o);
        
        % Calculate deaths per 10,000
        ML = (params.value_of_death .* params.P0 / 10000) .* (severity / (pandemic_natural_dur * 12)) ./ 10^6;
        deaths_per_10k = ML * 10^6 / params.P0 * 10000;
        
        % Store results
        refined_results(i).severity = severity;
        refined_results(i).deaths = deaths_per_10k;
        refined_results(i).difference = abs(deaths_per_10k - target_deaths);
    end
    
    % Combine and sort all results
    results = [results, refined_results];
    [~, idx] = sort([results.difference]);
    results = results(idx);
    
    % Select the best result
    ex_post_severity = results(1).severity;
    
    % Optional: Plot results for visualization
    figure;
    plot([results.severity], [results.deaths], 'bo-');
    hold on;
    plot(get(gca, 'XLim'), [target_deaths, target_deaths], 'r--');
    xlabel('Pandemic Severity');
    ylabel('Deaths per 10,000');
    title('Pandemic Severity vs Deaths');
    grid on;
end

% Example usage script
function main_search_script()
    % Define your parameters here
    params = struct(...
        'value_of_death', 10000000, ... % Example value
        'P0', 330000000, ...            % Population size
        'y', 0.02, ...                  % Growth rate
        'r', 0.05, ...                  % Discount rate
        'gamma', 0.5, ...               % Vaccination effectiveness
        'c_m', 10, ...                  % mRNA vaccine cost
        'c_o', 5, ...                   % Traditional vaccine cost
        'RD_speedup_months', 3, ...     % R&D speedup
        'P0', 330000000 ...             % Population
    );
    
    % Create a mock economic loss model (you'll replace this with your actual model)
    econ_loss_model = struct('predict', @(severity) severity * 1000);
    
    % Other parameters
    tau_A = 12;           % Initial R&D time
    RD_benefit = 1;       % R&D benefit flag
    yr_start = 2020;      % Starting year
    pandemic_natural_dur = 2; % Natural pandemic duration in years
    actual_dur = 1.5;     % Actual duration
    rd_state = 1;         % R&D state
    cap_avail_m = 100;    % Monthly mRNA capacity
    cap_avail_o = 50;     % Monthly traditional capacity
    target_deaths = 3.2;  % Target deaths per 10,000
    
    % Run the grid search
    [ex_post_severity, results] = find_optimal_pandemic_severity(...
        params, econ_loss_model, tau_A, RD_benefit, yr_start, pandemic_natural_dur, ...
        actual_dur, rd_state, cap_avail_m, cap_avail_o, target_deaths);
    
    % Display results
    fprintf('Optimal Severity: %.2f\n', ex_post_severity);
    fprintf('Deaths at Optimal Severity: %.2f per 10,000\n', results(1).deaths);
    
    % Optional: Print all results for reference
    for i = 1:length(results)
        fprintf('Severity: %.2f, Deaths: %.2f per 10,000, Difference: %.2f\n', ...
            results(i).severity, results(i).deaths, results(i).difference);
    end
end