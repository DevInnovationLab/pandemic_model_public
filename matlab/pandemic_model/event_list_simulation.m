function sim_loss_annual = event_list_simulation(simulation_table, econ_loss_model, params)
    %% Step 1: Extract event-level arrays (fully vectorized)
    sim_nums = simulation_table.sim_num;
    num_sims = max(sim_nums); % Denote this S
    num_events = height(simulation_table); % Denote this E
    max_years = params.sim_periods; % Denote this Y

    year_start = simulation_table.yr_start;
    year_dur = simulation_table.actual_dur;
    month_start = (year_start - 1) * 12 + 1; % E x 1
    month_dur = ceil(year_dur * 12); % E x 1
    max_dur = max(month_dur); % Denote this M

    annual_intensity = simulation_table.intensity; % E x 1
    is_false = simulation_table.is_false; % E x 1
    rd_state = simulation_table.rd_state; % E x 1
    adv_RD = simulation_table.has_RD_benefit;
    prep_start_month = simulation_table.prep_start_month;
    false_pos_detected = isnan(prep_start_month) & is_false;
    month_vaccine_ready = tau_a + prep_start_month;

    % Array denoting which matrix elements correspond to active pandemics.
    active_idx = (month_dur >= (1:max_dur)) .* ~is_false; % E x M

    %% Step 2.5: Compute annual capacity available
    % Advance capacity
    [x_m, x_o] = get_target_capacity(params); % get target capacity (in millions)
    build_years = params.adv_cap_build_period;
    build_rate_m = params.z_m / build_years;
    build_rate_o = params.z_o / build_years;

    adv_cap_m = [build_rate_m * (1:build_years), repmat(params.z_m, 1, sim_periods - build_years)]; % 1 x Y
    adv_cap_o = [build_rate_o * (1:build_years), repmat(params.z_o, 1, sim_periods - build_years)]; % 1 x Y

    tailoring_fraction = params.tailoring_fraction;
    adv_cap_m_annual_capital_cost = capital_costs(build_rate_m, params, tailoring_fraction, 1, 1);
    adv_cap_o_annual_capital_cost = capital_costs(build_rate_o, params, tailoring_fraction, 0, 1);
    adv_cap_annual_cap_cost = [repmat(adv_cap_m_annual_capital_cost + adv_cap_o_annual_capital_cost, 1, build_years), zeros(1, non_build_years)];
    adv_cap_annual_value = cumsum(adv_cap_annual_cap_cost);

    % Surge capacity
    base_cap_m = params.x_avail * params.mRNA_share;
    base_cap_o = params.x_avail * (1 - params.mRNA_share);
    [max_cap_m, max_cap_o] = get_target_capacity(params);
    frac_retained = params.capacity_kept;
    [base_cap_m, adv_cap_m, surge_cap_m, surge_cap_m_cost] = ...
        get_event_capacity(year_start, year_dur, max_years, base_cap_m, frac_retained, base_cap_m, adv_cap_m, max_cap_m, params, 1);
    [base_cap_o, adv_cap_o, surge_cap_o, surge_cap_o_cost] = ...
        get_event_capacity(year_start, year_dur, max_years, base_cap_o, frac_retained, max_cap_o, base_cap_o, params, 0);

    all_cap_m = base_cap_m + adv_cap_m + surge_cap_m;
    all_cap_o = base_cap_o + adv_cap_o + surge_cap_o;

    %% Step 2.7 Enhanced surveillance costs
    years_arr = 1:max_years;
    pv_factors_annual = (1+params.r).^(-years_arr);

    if params.enhanced_surveillance
        surveil_spend_bn_init = repmat(params.surveil_annual_installation_spend, params.surveil_installation_years, 1);
        surveil_spend_bn_maintenance = repmat(params.surveil_maintenance_spend, params.sim_periods - params.surveil_installation_years, 1);
        surveil_costs_nom = [surveil_spend_bn_init; surveil_spend_bn_maintenance];
    end

    if params.adv_RD
        adv_RD_costs_nom = zeros(1, max_years);
        adv_RD_spend_rate = params.adv_RD_spend / params.adv_RD_benefit_start;
        adv_RD_costs_nom(1:params.adv_RD_benefit_start) = adv_RD_spend_rate;
    end

    %% Advance capacity maintenance costs
    rentable_cap_m = adv_cap_m + surge_cap_m;
    rentable_cap_o = adv_cap_o + surge_cap_o;
    rental_income_fractions = get_rental_fractions(params, rentable_cap_m, rentable_cap_o);

    % Set rental income fraction to zero during pandemic outbreaks using event arrays
    outbreak_mat = zeros(num_sims, max_years);
    outbreak_mat(sub2ind([num_sims, max_years], sim_num, year_start)) = 1;
    outbreak_mat(sub2ind([num_sims, max_years], sim_num, year_start + year_dur - 1)) = -1;
    outbreak_mat = cumsum(outbreak_mat, 2) > 0;
    rental_income_fractions(outbreak_mat) = 0;

    % Fix the rental income timing later.
    adv_cap_maintenance_costs_over_time = get_capacity_maintenance_cost(adv_cap_stock_value_over_time, params);
    adv_cap_maintenance_costs_over_time_rent_adjusted = adv_cap_maintenance_costs_over_time .* (1-rental_income_fractions);
    total_adv_cap_costs_over_time = adv_cap_capital_costs_over_time + adv_cap_maintenance_costs_over_time_rent_adjusted;
    surge_cap_maintenance_costs_over_time = get_capacity_maintenance_cost(surge_cap_stock_value_over_time, params);
    surge_cap_maintenance_costs_over_time_rent_adjusted = surge_cap_maintenance_costs_over_time .* (1-rental_income_fractions);
    total_surge_cap_costs_over_time = surge_cap_capital_costs_over_time + surge_cap_maintenance_costs_over_time_rent_adjusted;


    %% Tailoring costs
    year_start_idx = sub2ind([1, max_years], year_start);
    sim_year_event_idx = sub2ind([num_sims, max_years], sim_num, year_start);

    tailoring_costs_nom = zeros(num_sims, max_years);
    tailoring_costs_nom(sim_year_event_idx) = (...
        tailoring_fraction .* ...
        ~false_pos_detected .* ...
        (adv_cap_o(year_start_idx) * params.k_m + adv_cap_o(year_start_idx) * params.k_o) ...
    );

    % Set response R&D costs
    event_inp_RD_nom = adv_RD .* params.inp_RD_with_adv_RD + ~adv_RD .* params.inp_RD_no_adv_RD;
    inp_RD_nom_mat = zeros(num_sims, max_years);
    inp_RD_nom_mat(sim_year_event_idx) = event_inp_RD_nom .* ~false_pos_detected;
    % Going to have a problem because some year_start will be blank.

    %% Step 2: Compute monthly intensities and losses (vectorized)
    monthly_intensity = (annual_intensity ./ 12) .* active_idx; % E x M
    monthly_deaths_unmitigated = (params.P0 / 10000) .* monthly_intensity; % E x M
    monthly_econ_loss = econ_loss_model.predict(annual_intensity) ./ 12; % Should be E x 1
    monthly_econ_loss = monthly_econ_loss .* active_idx; % E x M

    %% Step 3: Intervention Effects
    months_matrix = repmat(1:max_dur, num_events, 1); % E x M

    [ind_m, ind_o] = get_capacity_indicators(rd_state); % E x 1
    cap_avail_m = all_cap_m(sim_year_event_idx) / 12;
    cap_avail_o = all_cap_o(sim_year_event_idx) / 12;
    [cap_m, cap_o] = get_pandemic_capacity(months_matrix, tau_a, params, ind_m, ind_o, cap_avail_m, cap_avail_o);
    % E x M. Check this function has correct output.

    vax_fraction_cum = cumsum((cap_m + cap_o) / params.P0, 2);
    vax_fraction_cum(vax_fraction_cum > 1) = 1;
    h_arr = params.gamma .* vax_fraction_cum; % Protection factor

    monthly_deaths_mitigated = monthly_deaths_unmitigated .* (1 - h_arr);

    %% Step 4: Economic Losses (PV and Growth)
    % These are definitely wrong
    growth_factors_monthly = (1 + params.y).^((month_start + months_matrix - 1)/12);
    PV_factors_monthly = (1/(1 + params.r)).^((month_start + months_matrix - 1)/12);

    mortality_losses_PV = params.value_of_death .* monthly_deaths_mitigated .* growth_factors_monthly .* PV_factors_monthly;
    output_losses_PV = (params.Y0 .* params.P0) .* monthly_econ_loss .* growth_factors_monthly .* PV_factors_monthly;
    learning_losses_PV = (10 / 13.8) .* output_losses_PV;

    total_losses_PV = mortality_losses_PV + output_losses_PV + learning_losses_PV;

    %% Step 5: Aggregate Back to Simulation Timeline (Fully vectorized)
    sim_loss_monthly = accumarray(...
        [repelem(sim_nums, month_dur)', ...
         cell2mat(arrayfun(@(s,d)s:s+d-1, month_start, month_dur,'UniformOutput',false))'], ...
        total_losses_PV(total_losses_PV > 0), ...
        [num_sims, params.sim_periods * 12]);

    %% Step 6: Annual Aggregation
    sim_loss_annual = reshape(sum(reshape(sim_loss_monthly, num_sims, 12, []), 2), num_sims, []);

    % Make surveillance array at the end
end