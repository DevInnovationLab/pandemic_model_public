function sim_loss_annual = event_list_simulation(simulation_table, econ_loss_model, params)
    %% INITIALIZATION: Extract event-level data and set up arrays
    % Extract events from simulation table
    event_sim_table = simulation_table(~isnan(simulation_table.year_start), :); % Remove simulations with no events

    % Basic simulation parameters
    sim_nums = event_sim_table.sim_num;
    num_sims = max(sim_nums);
    num_events = height(event_sim_table);
    max_years = params.sim_periods;

    % Event timing information
    year_start = event_sim_table.yr_start;
    year_dur = event_sim_table.actual_dur;
    month_start = (year_start - 1) * 12 + 1;
    month_dur = ceil(year_dur * 12);
    max_dur = max(month_dur);

    % Event characteristics
    annual_intensity = event_sim_table.intensity;
    is_false = event_sim_table.is_false;
    rd_state = event_sim_table.rd_state;
    adv_RD = event_sim_table.has_RD_benefit;
    prep_start_month = event_sim_table.prep_start_month;
    false_pos_detected = isnan(prep_start_month) & is_false;
    month_vaccine_ready = tau_a + ~is_false .* prep_start_month;

    % Array denoting which matrix elements correspond to active pandemics
    active_idx = (month_dur >= (1:max_dur)) .* ~is_false; % E x M

    % Discount and growth factors
    years_arr = 1:max_years;
    pv_factors_annual = (1+params.r).^(-years_arr);
    months_matrix = repmat(1:max_dur, num_events, 1); % E x M
    growth_factors_monthly = (1 + params.y).^((month_start + months_matrix - 1)/12);
    pv_factors_monthly = (1/(1 + params.r)).^((month_start + months_matrix - 1)/12);
    
    % Event indices for aggregation
    event_start_idx = sub2ind([num_sims, max_years], sim_nums, year_start);

    %% CAPACITY CALCULATIONS
    % Get target capacity
    [x_m, x_o] = get_target_capacity(params);
    build_years = params.adv_cap_build_period;
    non_build_years = max_years - build_years;
    build_rate_m = params.z_m / build_years;
    build_rate_o = params.z_o / build_years;

    % Calculate advance and surge capacity
    base_cap_m = params.x_avail * params.mRNA_share;
    base_cap_o = params.x_avail * (1 - params.mRNA_share);
    [max_cap_m, max_cap_o] = get_target_capacity(params);
    frac_retained = params.capacity_kept;
    
    % Advance capacity over time
    adv_cap_m = [build_rate_m * (1:build_years), repmat(params.z_m, 1, non_build_years)]; % 1 x Y
    adv_cap_o = [build_rate_o * (1:build_years), repmat(params.z_o, 1, non_build_years)]; % 1 x Y

    % Get surge capacity
    [base_cap_m, adv_cap_m, surge_cap_m, surge_cap_m_cost] = ...
        get_event_capacity(year_start, year_dur, false_pos_detected, max_years, base_cap_m, frac_retained, base_cap_m, adv_cap_m, max_cap_m, params, 1);
    [base_cap_o, adv_cap_o, surge_cap_o, surge_cap_o_cost] = ...
        get_event_capacity(year_start, year_dur, false_pos_detected, max_years, base_cap_o, frac_retained, base_cap_o, adv_cap_o, max_cap_o, params, 0);

    % Total capacity
    all_cap_m = base_cap_m + adv_cap_m + surge_cap_m;
    all_cap_o = base_cap_o + adv_cap_o + surge_cap_o;

    % Calculate capacity costs and values
    tailoring_fraction = params.tailoring_fraction;
    adv_cap_m_annual_capital_cost = capital_costs(build_rate_m, params, tailoring_fraction, 1, 1);
    adv_cap_o_annual_capital_cost = capital_costs(build_rate_o, params, tailoring_fraction, 0, 1);
    adv_cap_annual_cap_cost = [repmat(adv_cap_m_annual_capital_cost + adv_cap_o_annual_capital_cost, 1, build_years), zeros(1, non_build_years)];
    adv_cap_annual_value = cumsum(adv_cap_annual_cap_cost);

    surge_cap_m_annual_value = surge_cap_m .* params.k_m;
    surge_cap_o_annual_value = surge_cap_o .* params.k_o;
    surge_cap_annual_cap_cost = surge_cap_m_cost + surge_cap_o_cost;
    surge_cap_annual_value = surge_cap_m_annual_value + surge_cap_o_annual_value;

    % Calculate rental income
    rentable_cap_m = adv_cap_m + surge_cap_m;
    rentable_cap_o = adv_cap_o + surge_cap_o;
    rental_income_fractions = get_rental_fractions(params, rentable_cap_m, rentable_cap_o);

    % Zero out rental income during outbreaks
    true_outbreak_mat = zeros(num_sims, max_years);
    true_outbreak_mat(sub2ind([num_sims, max_years], sim_nums(~is_false), year_start(~is_false))) = 1;
    true_outbreak_mat(sub2ind([num_sims, max_years], sim_nums(~is_false), year_start(~is_false) + year_dur(~is_false) - 1)) = -1;
    true_outbreak_mat = cumsum(true_outbreak_mat, 2) > 0;
    rental_income_fractions(true_outbreak_mat) = 0;

    %% PANDEMIC IMPACT CALCULATIONS
    % Calculate monthly intensities and unmitigated impacts
    monthly_intensity = (annual_intensity ./ 12) .* active_idx; % E x M
    monthly_deaths_unmitigated = (params.P0 / 10000) .* monthly_intensity; % E x M
    monthly_econ_loss = econ_loss_model.predict(annual_intensity) ./ 12; % Should be E x 1
    monthly_econ_loss = monthly_econ_loss .* active_idx; % E x M

    % Calculate intervention effects
    [ind_m, ind_o] = get_capacity_indicators(rd_state); % E x 1
    cap_avail_m = all_cap_m(event_start_idx) / 12;
    cap_avail_o = all_cap_o(event_start_idx) / 12;
    [cap_m, cap_o] = get_pandemic_capacity(months_matrix, month_vaccine_ready, params, ind_m, ind_o, cap_avail_m, cap_avail_o); % E x M.

    % Calculate protection from vaccination
    vax_fraction_cum = cumsum((cap_m + cap_o) / params.P0, 2);
    still_vaccinating_idx = vax_fraction_cum <= 1;
    vax_fraction_cum(vax_fraction_cum > 1) = 1;
    h_arr = params.gamma .* vax_fraction_cum; % Protection factor

    % Calculate mitigated deaths
    monthly_deaths_mitigated = monthly_deaths_unmitigated .* (1 - h_arr);

    %% COST AND LOSS CALCULATIONS
    % 1. Capacity costs
    adv_cap_maintenance_costs = get_capacity_maintenance_cost(adv_cap_annual_value, params);
    adv_cap_maintenance_costs_rent_adjusted = adv_cap_maintenance_costs .* (1 - rental_income_fractions);
    adv_cap_total_costs_nom = adv_cap_annual_cap_cost + adv_cap_maintenance_costs_rent_adjusted;
    adv_cap_total_costs_pv = adv_cap_total_costs_nom .* pv_factors_annual;

    surge_cap_maintenance_costs = get_capacity_maintenance_cost(surge_cap_annual_value, params);
    surge_cap_maintenance_costs_rent_adjusted = surge_cap_maintenance_costs .* (1 - rental_income_fractions);
    surge_cap_total_costs_nom = surge_cap_annual_cap_cost + surge_cap_maintenance_costs_rent_adjusted;
    surge_cap_total_costs_pv = surge_cap_total_costs_nom .* pv_factors_annual;

    % 2. Surveillance costs
    surveil_costs_nom = zeros(1, max_years);
    if params.enhanced_surveillance
        surveil_spend_bn_init = repmat(params.surveil_annual_installation_spend, params.surveil_installation_years, 1);
        surveil_spend_bn_maintenance = repmat(params.surveil_maintenance_spend, max_years - params.surveil_installation_years, 1);
        surveil_costs_nom = [surveil_spend_bn_init; surveil_spend_bn_maintenance]';
    end
    surveil_costs_pv = surveil_costs_nom .* pv_factors_annual;

    % 3. R&D costs
    adv_rd_costs_nom = zeros(1, max_years);
    if params.adv_RD
        adv_rd_spend_rate = params.adv_RD_spend / params.adv_RD_benefit_start;
        adv_rd_costs_nom(1:params.adv_RD_benefit_start) = adv_rd_spend_rate;
    end
    adv_rd_costs_pv = adv_rd_costs_nom .* pv_factors_annual;

    % 4. In-pandemic costs
    % Vaccination costs
    marginal_costs_nom = (params.c_m .* cap_m + params.c_o .* cap_o) .* still_vaccinating_idx .* ~is_false;
    marginal_costs_pv = marginal_costs_nom .* pv_factors_monthly;
    sim_marginal_costs_nom = event_list_to_sim_year(marginal_costs_nom, month_start, month_dur, sim_nums, num_sims, max_years);
    sim_marginal_costs_pv = event_list_to_sim_year(marginal_costs_pv, month_start, month_dur, sim_nums, num_sims, max_years);

    % Tailoring costs
    tailoring_costs_nom = zeros(num_sims, max_years);
    tailoring_costs_nom(event_start_idx) = (...
        tailoring_fraction .* ...
        ~false_pos_detected .* ...
        (adv_cap_o(event_start_idx) * params.k_m + adv_cap_o(event_start_idx) * params.k_o) ...
    );
    tailoring_costs_pv = tailoring_costs_nom .* pv_factors_annual(:,1);

    % In-pandemic R&D costs
    event_inp_rd_nom = adv_RD .* params.inp_RD_with_adv_RD + ~adv_RD .* params.inp_RD_no_adv_RD;
    inp_rd_costs_nom = zeros(num_sims, max_years);
    inp_rd_costs_nom(event_start_idx) = event_inp_rd_nom .* ~false_pos_detected;
    inp_rd_costs_pv = inp_rd_costs_nom .* pv_factors_annual;

    % 5. Impact costs
    % Deaths
    sim_deaths_unmitigated = event_list_to_sim_year(monthly_deaths_unmitigated, month_start, month_dur, sim_nums, num_sims, max_years);
    sim_deaths_mitigated = event_list_to_sim_year(monthly_deaths_mitigated, month_start, month_dur, sim_nums, num_sims, max_years);

    % Economic losses
    mortality_losses_nom = params.value_of_death .* monthly_deaths_mitigated .* growth_factors_monthly;
    output_losses_nom = (params.Y0 .* params.P0) .* monthly_econ_loss .* growth_factors_monthly;
    learning_losses_nom = (10 / 13.8) .* output_losses_nom;

    mortality_losses_pv = mortality_losses_nom .* pv_factors_monthly;
    output_losses_pv = output_losses_nom .* pv_factors_monthly;
    learning_losses_pv = learning_losses_nom .* pv_factors_monthly;

    sim_mortality_losses_nom = event_list_to_sim_year(mortality_losses_nom, month_start, month_dur, sim_nums, num_sims, max_years);
    sim_output_losses_nom = event_list_to_sim_year(output_losses_nom, month_start, month_dur, sim_nums, num_sims, max_years);
    sim_learning_losses_nom = event_list_to_sim_year(learning_losses_nom, month_start, month_dur, sim_nums, num_sims, max_years);

    sim_mortality_losses_pv = event_list_to_sim_year(mortality_losses_pv, month_start, month_dur, sim_nums, num_sims, max_years);
    sim_output_losses_pv = event_list_to_sim_year(output_losses_pv, month_start, month_dur, sim_nums, num_sims, max_years);
    sim_learning_losses_pv = event_list_to_sim_year(learning_losses_pv, month_start, month_dur, sim_nums, num_sims, max_years);

    %% STORE RESULTS
    % Costs - nominal
    sim_loss_annual.costs_adv_cap_nom = repmat(adv_cap_total_costs_nom, num_sims, 1);
    sim_loss_annual.costs_surge_cap_nom = surge_cap_total_costs_nom;
    sim_loss_annual.costs_surveil_nom = repmat(surveil_costs_nom, num_sims, 1);
    sim_loss_annual.costs_adv_rd_nom = repmat(adv_rd_costs_nom, num_sims, 1);
    sim_loss_annual.costs_inp_tailoring_nom = tailoring_costs_nom;
    sim_loss_annual.costs_inp_rd_nom = inp_rd_costs_nom;
    sim_loss_annual.costs_inp_marg_nom = sim_marginal_costs_nom;

    % Costs - present value
    sim_loss_annual.costs_adv_cap_pv = repmat(adv_cap_total_costs_pv, num_sims, 1);
    sim_loss_annual.costs_surge_cap_pv = surge_cap_total_costs_pv;
    sim_loss_annual.costs_surveil_pv = repmat(surveil_costs_pv, num_sims, 1);
    sim_loss_annual.costs_adv_rd_pv = repmat(adv_rd_costs_pv, num_sims, 1);
    sim_loss_annual.costs_inp_tailoring_pv = tailoring_costs_pv;
    sim_loss_annual.costs_inp_rd_pv = inp_rd_costs_pv;
    sim_loss_annual.costs_inp_marg_pv = sim_marginal_costs_pv;

    % Impact costs - nominal
    sim_loss_annual.deaths_unmitigated = sim_deaths_unmitigated;
    sim_loss_annual.deaths_mitigated = sim_deaths_mitigated;
    sim_loss_annual.mortality_losses_nom = sim_mortality_losses_nom;
    sim_loss_annual.output_losses_nom = sim_output_losses_nom;
    sim_loss_annual.learning_losses_nom = sim_learning_losses_nom;

    % Impact costs - present value
    sim_loss_annual.mortality_losses_pv = sim_mortality_losses_pv;
    sim_loss_annual.output_losses_pv = sim_output_losses_pv;
    sim_loss_annual.learning_losses_pv = sim_learning_losses_pv;
end


function [sim_idx, year_idx] = get_event_list_to_sim_year_idx(sim_nums, month_start, month_dur)
    % Create indices for converting event x month matrix to simulation x year matrix
    %
    % Args:
    %   values_matrix: Matrix of values with dimensions (events x months)
    %   event_months: Starting month for each event (1-based)
    %   sim_nums: Array of simulation numbers for each event
    %   month_dur: Duration in months for each event
    %
    % Returns:
    %   sim_idx: Array of simulation indices for accumarray
    %   year_idx: Array of year indices for accumarray
    %   values_flat: Flattened values from the input matrix
    
    % Get simulation indices by repeating each sim number by its duration
    sim_idx = repelem(sim_nums, month_dur)';
    
    % Get month indices by expanding each event's start month
    month_idx = cell2mat(arrayfun(@(s,d) s:(s+d-1), ...
                         month_start, month_dur, ...
                         'UniformOutput',false))';
                         
    % Convert to year indices
    year_idx = floor((month_idx-1)./12) + 1;

end


function sim_year_matrix = event_list_to_sim_year(values_matrix, month_start, month_dur, sim_nums, num_sims, max_years)
    % Convert event x month matrix to simulation x year matrix
    %
    % Args:
    %   values_matrix: Matrix of values with dimensions (events x months)
    %   event_months: Starting month for each event (1-based)
    %   sim_nums: Array of simulation numbers for each event
    %   month_dur: Duration in months for each event
    %   num_sims: Number of simulations
    %   max_years: Maximum number of years
    %
    % Returns:
    %   sim_year_matrix: Matrix of values with dimensions (num_sims x max_years)
    
    [sim_idx, year_idx] = get_event_list_to_sim_year_idx(sim_nums, month_start, month_dur);
    sim_year_matrix = accumarray([sim_idx, year_idx], values_matrix, [num_sims, max_years], @sum, 0);
end



