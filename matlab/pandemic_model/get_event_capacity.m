function [surge_cap, surge_cap_cost] = ...
    get_event_capacity(sim_num, year_start, false_pos_detected, duration, max_years, delta_cap, ...
        surge_retained, base_cap, adv_cap, max_cap, params, is_mRNA, num_sims)
    % Inputs:
    %   sim_num     : [E×1] simulation index (1-based)
    %   month_start : [E×1] start month of pandemic
    %   month_dur   : [E×1] pandemic duration in months
    %   baseCap     : scalar or [Y×1] initial capacity
    %   delta_cap    : scalar added at onset
    %   maxCap      : ceiling on total capacity
    %   T           : number of months in simulation
    %
    % Output:
    %   cap         : [S × Y] capacity matrix for each simulation
    arguments
        sim_num (:, 1)
        year_start (:, 1)
        false_pos_detected (:, 1)
        duration (:, 1)
        max_years (1, 1)
        delta_cap (:, 1)
        surge_retained (1, 1)
        base_cap (:, 1)
        adv_cap (1, :)
        max_cap (1, 1)
        params
        is_mRNA
        num_sims (1, 1)
    end
    year_end = year_start + duration; % Month where capacity should be reduced
    event_start_idx = sub2ind([num_sims, max_years], sim_num(~false_pos_detected), year_start(~false_pos_detected));
    
    % Only reduce capacity if the end year is within simulation period
    valid_end = year_end <= max_years;
    event_end_idx = sub2ind([num_sims, max_years], sim_num(~false_pos_detected & valid_end), year_end(~false_pos_detected & valid_end));

    % Create capacity change matrix
    % This could be more memory efficient if you just had event list with groups
    surge_cap = zeros(num_sims, max_years);
    surge_cap(event_start_idx) = delta_cap;
    surge_cap(event_end_idx) = -(1 - surge_retained) * delta_cap;
    
    % Accumulate changes over time
    surge_cap = cumsum(surge_cap, 2);
    all_cap = surge_cap + base_cap + adv_cap;
    exceed_idx = all_cap > max_cap;
    surge_cap(exceed_idx) = surge_cap(exceed_idx) - (all_cap(exceed_idx) - max_cap); % Enforce ceiling
    surge_cap(surge_cap < 0) = 0;

    % Calculate surge capacity capital costs
    % Get the surge capacity at the start of each event
    event_surge_cap = surge_cap(event_start_idx);
    
    % Get the existing surge capacity right before each event
    pre_event_surge_cap = zeros(size(event_surge_cap));
    valid_idx = year_start > 1 & ~false_pos_detected;
    pre_event_idx = sub2ind([num_sims, max_years], sim_num(valid_idx), year_start(valid_idx) - 1); 
    pre_event_surge_cap(valid_idx) = surge_cap(pre_event_idx);
    
    % Calculate the incremental surge capacity needed
    event_surge_cap_diff = event_surge_cap - pre_event_surge_cap;
    event_surge_cap_diff(event_surge_cap_diff < 0) = 0;
    
    % Calculate capital costs for the incremental capacity
    event_surge_cap_cost = capital_costs(event_surge_cap_diff, params, is_mRNA, 0);

    % Place costs in the output matrix at event start times
    surge_cap_cost = zeros(num_sims, max_years);
    surge_cap_cost(event_start_idx) = event_surge_cap_cost;
end