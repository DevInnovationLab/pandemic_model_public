function [base_cap, adv_cap, surge_cap, surge_cap_cost] = ...
    get_event_capacity(sim_num, year_start, duration, max_years, deltaCap, ...
        surge_retained, base_cap, adv_cap, max_cap, params, is_mRNA)
    % Inputs:
    %   sim_num     : [E×1] simulation index (1-based)
    %   month_start : [E×1] start month of pandemic
    %   month_dur   : [E×1] pandemic duration in months
    %   baseCap     : scalar or [Y×1] initial capacity
    %   deltaCap    : scalar added at onset
    %   maxCap      : ceiling on total capacity
    %   T           : number of months in simulation
    %
    % Output:
    %   cap         : [S × Y] capacity matrix for each simulation
    arguments
        sim_num (:, 1)
        year_start (:, 1)
        duration (:, 1)
        max_years (1, 1)
        deltaCap (:, 1)
        surge_retained (1, 1)
        base_cap (:, 1)
        adv_cap (1, :)
        max_cap (1, 1)
        params
        is_mRNA
    end
    num_sims = max(sim_num);

    % Month where capacity should be reduced
    year_end = min(year_start + duration, max_years);

    % Create capacity change matrix directly
    % This could be more memory efficient if you just had event list with groups
    surge_cap = zeros(num_sims, max_years);
    surge_cap(sub2ind([num_sims, max_years], sim_num, year_start)) = deltaCap;
    surge_cap(sub2ind([num_sims, max_years], sim_num, year_end)) = -(1 - surge_retained) * deltaCap;
    
    % Accumulate changes over time
    surge_cap = cumsum(surge_cap, 2);
    all_cap = surge_cap + base_cap + adv_cap;
    exceed_idx = all_cap > max_cap;
    surge_cap(exceed_idx) = surge_cap(exceed_idx) - (all_cap(exceed_idx) - max_cap); % Enforce ceiling
    surge_cap(surge_cap < 0) = 0;

    % Calculate surge capacity capital costs
    % Need to check this
    event_surge_cap = surge_cap(sub2ind([num_sims, max_years], sim_num, year_start));
    event_surge_cap_diff = diff([0; event_surge_cap]);
    event_surge_cap_diff(event_surge_cap_diff < 0) = 0; 
    event_surge_cap_cost = capital_costs(event_surge_cap_diff, params, params.tailoring_fraction, is_mRNA, 0);

    surge_cap_cost = zeros(num_sims, max_years);
    surge_cap_cost(sub2ind([num_sims, max_years], sim_num, year_start)) = event_surge_cap_cost;
end