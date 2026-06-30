function [surge_cap, surge_cap_cost] = ...
    get_event_capacity(sim_num, year_start, is_false, false_pos_ignored, duration, max_years, delta_cap_by_year, ...
        surge_retained, base_cap, adv_cap, max_cap, params, is_mRNA, num_sims)
    % Compute surge capacity and its capital cost for each simulation and year.
    %
    % Constructs a (num_sims x max_years) surge capacity matrix by adding capacity
    % when each event starts and partially releasing it when the event ends.
    % Enforces a ceiling at max_cap and returns the incremental capital costs.
    %
    % Args:
    %   sim_num           [E x 1] Simulation index (1-based) for each event.
    %   year_start        [E x 1] Year in which each event begins.
    %   is_false          [E x 1] Logical: true if the event is a false-positive alarm.
    %   false_pos_ignored [E x 1] Logical: true if this false positive was not acted upon.
    %   duration          [E x 1] Event duration in years.
    %   max_years         Scalar; number of years in the simulation.
    %   delta_cap_by_year [Y x 1] Surge increment available per capacity unit per year.
    %   surge_retained    Fraction of surge capacity retained after event ends (0-1).
    %   base_cap          Scalar or [Y x 1] baseline platform capacity.
    %   adv_cap           [1 x Y] Advance capacity profile over years.
    %   max_cap           Scalar; deployable ceiling on total capacity for this platform.
    %   params            Struct with fields: epsilon, beta, k_m, k_o, frac_invest_on_false.
    %   is_mRNA           1 for mRNA platform, 0 for traditional.
    %   num_sims          Total number of simulations.
    %
    % Returns:
    %   surge_cap       [num_sims x max_years] Cumulative surge capacity each year.
    %   surge_cap_cost  [num_sims x max_years] Capital cost incurred at event start.
    arguments
        sim_num (:, 1)
        year_start (:, 1)
        is_false (:, 1)
        false_pos_ignored (:, 1)
        duration (:, 1)
        max_years (1, 1)
        delta_cap_by_year (:, 1)
        surge_retained (1, 1)
        base_cap (:, 1)
        adv_cap (1, :)
        max_cap (1, 1)
        params
        is_mRNA
        num_sims (1, 1)
    end
    year_end = year_start + duration; % Year where capacity should be reduced
    event_start_idx = sub2ind([num_sims, max_years], sim_num(~false_pos_ignored), year_start(~false_pos_ignored));
    
    % Only reduce capacity if the end year is within simulation period
    valid_end = year_end < max_years;
    event_end_idx = sub2ind([num_sims, max_years], sim_num(~false_pos_ignored & valid_end), year_end(~false_pos_ignored & valid_end));

    % Create capacity change matrix
    % This could be more memory efficient if you just had event list with groups
    surge_cap = zeros(num_sims, max_years);
    surge_cap(event_start_idx) = delta_cap_by_year(year_start(~false_pos_ignored)) .* (1 - is_false(~false_pos_ignored) .* (1 - params.frac_invest_on_false));
    surge_cap(event_end_idx) = surge_cap(event_end_idx) - ...
        (1 - surge_retained) .* ...
        delta_cap_by_year(year_start(~false_pos_ignored & valid_end)) .* ...
        (1 - is_false(~false_pos_ignored & valid_end) .* (1 - params.frac_invest_on_false)); % In case pandemic end and start in same year.
    
    % Accumulate changes over time
    surge_cap = cumsum(surge_cap, 2);
    all_cap = surge_cap + base_cap + adv_cap;
    exceed_idx = all_cap > max_cap;
    surge_cap(exceed_idx) = surge_cap(exceed_idx) - (all_cap(exceed_idx) - max_cap); % Enforce ceiling

    % Calculate surge capacity capital costs
    % Get the surge capacity at the start of each event
    event_surge_cap = surge_cap(event_start_idx);
    
    % Get the existing surge capacity right before each event
    pre_event_surge_cap = zeros(size(event_surge_cap));
    valid_idx = ~false_pos_ignored & year_start > 1;
    pre_event_idx = sub2ind([num_sims, max_years], sim_num(valid_idx), year_start(valid_idx) - 1);
    valid_in_considered = (year_start(~false_pos_ignored)) > 1;
    pre_event_surge_cap(valid_in_considered) = surge_cap(pre_event_idx);
    
    % Calculate the incremental surge capacity needed
    event_surge_cap_diff = event_surge_cap - pre_event_surge_cap;
    event_surge_cap_diff(event_surge_cap_diff < 0) = 0; % When max cap binds and causes reduction, we don't add as negative cost.
    
    % Calculate capital costs for the incremental capacity
    event_surge_cap_cost = capital_costs(event_surge_cap_diff, params, 0, is_mRNA, 0);

    % Place costs in the output matrix at event start times
    surge_cap_cost = zeros(num_sims, max_years);
    surge_cap_cost(event_start_idx) = event_surge_cap_cost;
end