function event_list_simulation(simulation_table, econ_loss_model, params)
    %% INITIALIZATION: Extract event-level data and set up arrays
    % Extract events from simulation table
    event_sim_table = simulation_table(~isnan(simulation_table.yr_start), :); % Remove simulations with no events

    % Basic simulation parameters
    sim_num = event_sim_table.sim_num;
    num_sims = params.num_simulations;
    num_events = height(event_sim_table);
    max_years = params.sim_periods;

    % Event timing information
    year_start = event_sim_table.yr_start;
    year_dur = event_sim_table.actual_dur;
    month_start = (year_start - 1) * 12 + 1;
    month_dur = ceil(year_dur * 12);
    max_month_dur = max(month_dur);

    % Event characteristics
    annual_intensity = event_sim_table.intensity;
    is_false = event_sim_table.is_false;
    rd_state = event_sim_table.rd_state;
    adv_RD = event_sim_table.has_RD_benefit;
    prep_start_month = event_sim_table.prep_start_month;
    false_pos_detected = isnan(prep_start_month) & is_false;
    ufv_protection = event_sim_table.ufv_protection;
    month_vaccine_ready = event_sim_table.month_vaccine_ready;

    % Array denoting which matrix elements correspond to active pandemics
    active_idx = (month_dur >= (1:max_month_dur)) .* ~is_false; % E x M

    % Discount and growth factors
    pv_factors_annual = (1+params.r).^(-(1:max_years));
    months_matrix = repmat(1:max_month_dur, num_events, 1); % E x M
    growth_factors_monthly = (1 + params.y).^((month_start + months_matrix - 1)/12);
    pv_factors_monthly = (1/(1 + params.r)).^((month_start + months_matrix - 1)/12);
    
    % Event indices for aggregation
    event_start_idx = sub2ind([num_sims, max_years], sim_num, year_start);
    [sim_idx, year_idx] = get_event_list_to_sim_year_idx(sim_num, month_start, month_dur);

    %% CAPACITY CALCULATIONS
    % Get target capacity
    build_years = params.adv_cap_build_period;
    non_build_years = max_years - build_years;
    build_rate_m = params.z_m / build_years;
    build_rate_o = params.z_o / build_years;

    % Calculate advance and surge capacity
    base_cap_m = params.x_avail .* (1 - params.theta) .* params.mRNA_share;
    base_cap_o = params.x_avail .* (1 - params.theta) .* (1 - params.mRNA_share);
    [max_cap_m, max_cap_o] = get_target_capacity(params);
    frac_retained = params.capacity_kept;
    
    % Advance capacity over time
    adv_cap_m = [build_rate_m * (1:build_years), repmat(params.z_m, 1, non_build_years)]; % 1 x Y
    adv_cap_o = [build_rate_o * (1:build_years), repmat(params.z_o, 1, non_build_years)]; % 1 x Y

    % Get surge capacity
    [surge_cap_m, surge_cap_m_cost] = ...
        get_event_capacity(sim_num, year_start, false_pos_detected, year_dur, max_years, base_cap_m, frac_retained, base_cap_m, adv_cap_m, max_cap_m, params, 1, num_sims);
    [surge_cap_o, surge_cap_o_cost] = ...
        get_event_capacity(sim_num, year_start, false_pos_detected, year_dur, max_years, base_cap_o, frac_retained, base_cap_o, adv_cap_o, max_cap_o, params, 0, num_sims);

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
    rentable_cap = (adv_cap_m + surge_cap_m) + (adv_cap_o + surge_cap_o);
    rental_income_fractions = get_rental_fractions(rentable_cap, params.theta .* (base_cap_m + base_cap_o));

    % Zero out rental income during outbreaks
    true_outbreak_mat = zeros(num_sims, max_years);
    true_outbreak_mat(sub2ind([num_sims, max_years], sim_num(~is_false), year_start(~is_false))) = 1;
    true_outbreak_mat(sub2ind([num_sims, max_years], sim_num(~is_false), year_start(~is_false) + year_dur(~is_false) - 1)) = -1;
    true_outbreak_mat = cumsum(true_outbreak_mat, 2) > 0;
    rental_income_fractions(true_outbreak_mat) = 0;

    %% PANDEMIC IMPACT CALCULATIONS
    % Calculate monthly intensities and unmitigated impacts
    monthly_intensity = (annual_intensity ./ 12) .* active_idx; % E x M
    monthly_deaths_unmitigated = (params.P0 / 10000) .* monthly_intensity; % E x M
    unmitigated_output_losses = (econ_loss_model.predict(annual_intensity) ./12) .* active_idx;

    % Calculate intervention effects
    [ind_m, ind_o] = get_capacity_indicators(rd_state); % E x 1
    cap_avail_m = all_cap_m(event_start_idx) / 12;
    cap_avail_o = all_cap_o(event_start_idx) / 12;
    [cap_m, cap_o] = get_pandemic_capacity(months_matrix, month_vaccine_ready, params, ind_m, ind_o, cap_avail_m, cap_avail_o); % E x M
    cap_tot = cap_m + cap_o;

    % Calculate protection from vaccination
    vax_fraction_cum = cumsum(cap_tot / params.P0, 2);

    if params.conservative == 1 % Use beginning of period vaccinations (rather than end of period)
        vax_fraction_cum = [zeros(num_events, 1), vax_fraction_cum(:, 1:end-1)];
    end

    % Add protection from universal flu vaccine when relevant
    vax_fraction_cum = vax_fraction_cum + params.initial_share_ufv .* ufv_protection;

    first_vax_idx = vax_fraction_cum <= 1;
    vax_fraction_cum(vax_fraction_cum > 1) = 1;
    h_arr = params.gamma .* h(vax_fraction_cum); % Protection factor

    % Vaccinate at rate of capacity until all vaccinated, then annual
    % vaccination to maintain immunity.
    share_cap_m = cap_m ./ (cap_tot + eps);
    max_booster_rate = min(cap_tot, params.P0 / 12);

    monthly_courses_m = (...
        first_vax_idx .* cap_m + ...
        ~first_vax_idx .* max_booster_rate .* share_cap_m ...
    ) .* active_idx;
    monthly_courses_o = (...
        first_vax_idx .* cap_o + ...
        ~first_vax_idx .* max_booster_rate .* (1 - share_cap_m) ...
    ) .* active_idx;

    % Calculate mitigated losses and vaccine benefits
    monthly_deaths_mitigated = monthly_deaths_unmitigated .* (1 - h_arr);
    mortality_losses_nom = monthly_deaths_mitigated .* params.value_of_death .* growth_factors_monthly;

    output_losses_nom = unmitigated_output_losses .* (params.Y0 .* params.P0) .* (1 - h_arr) .* growth_factors_monthly; % Should be E x 1
    learning_losses_nom = output_losses_nom .* (10 / 13.8);
    total_losses_nom = mortality_losses_nom + output_losses_nom + learning_losses_nom;

    vax_benefits_nom =  (total_losses_nom ./ (1 - h_arr)) - total_losses_nom;
    vax_benefits_pv = vax_benefits_nom .* pv_factors_monthly;

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
    % Viral family specific R&D costs
    adv_rd_costs_nom = zeros(1, max_years);
    if params.adv_RD
        adv_rd_spend_rate = params.adv_RD_spend / params.adv_RD_benefit_start;
        adv_rd_costs_nom(1:params.adv_RD_benefit_start) = adv_rd_spend_rate;
    end
    adv_rd_costs_pv = adv_rd_costs_nom .* pv_factors_annual;

    % Advance universal flu vaccine R&D costs
    ufv_rd_costs_nom = zeros(1, max_years);
    if params.ufv_invest
        ufv_rd_spend_rate = params.ufv_spend / params.adv_RD_benefit_start;
        ufv_rd_costs_nom(1:params.adv_RD_benefit_start) = ufv_rd_spend_rate;
    end
    ufv_rd_costs_pv = ufv_rd_costs_nom .* pv_factors_annual;

    % 4. In-pandemic costs
    % Vaccination costs
    marginal_costs_nom = params.c_m .* monthly_courses_m + monthly_courses_o .* params.c_o;
    marginal_costs_pv = marginal_costs_nom .* pv_factors_monthly;
    sim_marginal_costs_nom = event_list_to_sim_year(marginal_costs_nom, sim_idx, year_idx, num_sims, max_years, active_idx);
    sim_marginal_costs_pv = event_list_to_sim_year(marginal_costs_pv, sim_idx, year_idx, num_sims, max_years, active_idx);

    % Tailoring costs
    tailoring_costs_nom = zeros(num_sims, max_years);
    tailoring_costs_nom(event_start_idx) = (...
        tailoring_fraction .* ...
        ~false_pos_detected .* ...
        (adv_cap_m(year_start) .* params.k_m + adv_cap_o(year_start) .* params.k_o)' ...
    );
    tailoring_costs_pv = tailoring_costs_nom .* pv_factors_annual;

    % In-pandemic R&D costs
    event_inp_rd_nom = adv_RD .* params.inp_RD_with_adv_RD + ~adv_RD .* params.inp_RD_no_adv_RD;
    inp_rd_costs_nom = zeros(num_sims, max_years);
    inp_rd_costs_nom(event_start_idx) = event_inp_rd_nom .* ~false_pos_detected .* ~ufv_protection;
    inp_rd_costs_pv = inp_rd_costs_nom .* pv_factors_annual;

    % 5. Impact costs
    % Deaths
    sim_deaths_unmitigated = event_list_to_sim_year(monthly_deaths_unmitigated, sim_idx, year_idx, num_sims, max_years, active_idx);
    sim_deaths_mitigated = event_list_to_sim_year(monthly_deaths_mitigated, sim_idx, year_idx, num_sims, max_years, active_idx);

    mortality_losses_pv = mortality_losses_nom .* pv_factors_monthly;
    output_losses_pv = output_losses_nom .* pv_factors_monthly;
    learning_losses_pv = learning_losses_nom .* pv_factors_monthly;

    % sim_mortality_losses_nom = event_list_to_sim_year(mortality_losses_nom, sim_idx, year_idx, num_sims, max_years);
    % sim_output_losses_nom = event_list_to_sim_year(output_losses_nom, sim_idx, year_idx, num_sims, max_years);
    % sim_learning_losses_nom = event_list_to_sim_year(learning_losses_nom, sim_idx, year_idx, num_sims, max_years);

    sim_mortality_losses_pv = event_list_to_sim_year(mortality_losses_pv, sim_idx, year_idx, num_sims, max_years, active_idx);
    sim_output_losses_pv = event_list_to_sim_year(output_losses_pv, sim_idx, year_idx, num_sims, max_years, active_idx);
    sim_learning_losses_pv = event_list_to_sim_year(learning_losses_pv, sim_idx, year_idx, num_sims, max_years, active_idx);

    % Vaccine benefits
    sim_benefits_vaccine_nom = event_list_to_sim_year(vax_benefits_nom, sim_idx, year_idx, num_sims, max_years, active_idx);
    sim_benefits_vaccine_pv = event_list_to_sim_year(vax_benefits_pv, sim_idx, year_idx, num_sims, max_years, active_idx);
    
    %% STORE RESULTS
    % Save results if requested
    % Set up pandemic-wise results table
    sim_table_cols = simulation_table.Properties.VariableNames;
    sim_table_types = varfun(@class, simulation_table, 'OutputFormat', 'cell');

    result_cols = {'cap_avail_m', 'cap_avail_o', 'u_deaths', 'm_deaths', 'vax_benefits', ...
                    'm_mortality_losses', 'm_output_losses', 'm_learning_losses', 'ex_post_severity', ...
                    'vax_fraction_end', 'inp_marg_costs_PV', 'inp_tailoring_costs_PV', 'inp_RD_costs_PV', ...
                   'inp_cap_costs_PV'};
    result_var_types = repmat({'double'}, [1, numel(result_cols)]);
    
    sim_results_cols = [sim_table_cols, result_cols];
    sim_results_var_types = [sim_table_types, result_var_types];
    
    % Create results table with all simulations
    sim_results = table('Size', [height(simulation_table), numel(sim_results_cols)], ...
                       'VariableTypes', sim_results_var_types, ...
                       'VariableNames', sim_results_cols);
    
    % Copy all scenario parameters 
    sim_results(:, sim_table_cols) = simulation_table;

    % Initialize results columns with zeros
    sim_results{:, result_cols} = 0;

    % Get indices of simulations with events
    event_sim_idx = ~isnan(simulation_table.yr_start);

    % Fill in results only for simulations that had events
    sim_results.cap_avail_m(event_sim_idx) = max(cap_m, [], 2);
    sim_results.cap_avail_o(event_sim_idx) = max(cap_o, [], 2);
    sim_results.u_deaths(event_sim_idx) = sum(monthly_deaths_unmitigated, 2);
    sim_results.m_deaths(event_sim_idx) = sum(monthly_deaths_mitigated, 2);
    sim_results.vax_benefits(event_sim_idx) = sum(vax_benefits_pv, 2);
    sim_results.m_mortality_losses(event_sim_idx) = sum(mortality_losses_pv, 2);
    sim_results.m_output_losses(event_sim_idx) = sum(output_losses_pv, 2);
    sim_results.m_learning_losses(event_sim_idx) = sum(learning_losses_pv, 2);
    sim_results.ex_post_severity(event_sim_idx) = sum(monthly_deaths_mitigated, 2) ./ (params.P0 / 10000);
    sim_results.vax_fraction_end(event_sim_idx) = vax_fraction_cum(:,end);
    sim_results.inp_marg_costs_PV(event_sim_idx) = sum(marginal_costs_pv, 2);
    sim_results.inp_tailoring_costs_PV(event_sim_idx) = tailoring_costs_pv(event_start_idx);
    sim_results.inp_RD_costs_PV(event_sim_idx) = inp_rd_costs_pv(event_start_idx);
    sim_results.inp_cap_costs_PV(event_sim_idx) = surge_cap_total_costs_pv(event_start_idx);

    if params.save_output
        save_to_file(params.scenario_name, params.rawoutpath, sim_results, ...
            adv_cap_total_costs_nom, adv_cap_total_costs_pv, ...
            repmat(adv_rd_costs_nom, num_sims, 1), repmat(adv_rd_costs_pv, num_sims, 1), ...
            repmat(ufv_rd_costs_nom, num_sims, 1), repmat(ufv_rd_costs_pv, num_sims, 1), ...
            repmat(surveil_costs_nom, num_sims, 1), repmat(surveil_costs_pv, num_sims, 1), ...
            surge_cap_total_costs_nom, surge_cap_total_costs_pv, ...
            sim_marginal_costs_nom, sim_marginal_costs_pv, ...
            tailoring_costs_nom, tailoring_costs_pv, ...
            inp_rd_costs_nom, inp_rd_costs_pv, ...
            sim_deaths_unmitigated, sim_deaths_mitigated, ...
            sim_mortality_losses_pv, sim_output_losses_pv, ...
            sim_learning_losses_pv, sim_benefits_vaccine_pv, ...
            sim_benefits_vaccine_nom);
    end
end


function [sim_idx, year_idx] = get_event_list_to_sim_year_idx(sim_num, month_start, month_dur)
    % Create indices for converting event x month matrix to simulation x year matrix
    %
    % Args:
    %   values_matrix: Matrix of values with dimensions (events x months)
    %   event_months: Starting month for each event (1-based)
    %   sim_num: Array of simulation numbers for each event
    %   month_dur: Duration in months for each event
    %
    % Returns:
    %   sim_idx: Array of simulation indices for accumarray
    %   year_idx: Array of year indices for accumarray
    %   values_flat: Flattened values from the input matrix
    
    % Get simulation indices by repeating each sim number by its duration
    sim_idx = repelem(sim_num, month_dur);
    
    % Get month indices by expanding each event's start month
    month_idx = cell2mat(arrayfun(@(s,d) (s:(s+d-1))', ...
                         month_start, month_dur, ...
                         'UniformOutput',false));
                         
    % Convert to year indices
    year_idx = floor((month_idx-1)./12) + 1;

end


function sim_year_matrix = event_list_to_sim_year(values_matrix, sim_idx, year_idx, num_sims, max_years, active_idx)
    % Convert event x month matrix to simulation x year matrix
    %
    % Args:
    %   values_matrix: Matrix of values with dimensions (events x months)
    %   event_months: Starting month for each event (1-based)
    %   sim_num: Array of simulation numbers for each event
    %   month_dur: Duration in months for each event
    %   num_sims: Number of simulations
    %   max_years: Maximum number of years
    %
    % Returns:
    %   sim_year_matrix: Matrix of values with dimensions (num_sims x max_years)
    values_max_t = values_matrix';
    values = values_max_t((active_idx == 1)');

    sim_year_matrix = accumarray([sim_idx, year_idx], ...
                                 values, ...
                                 [num_sims, max_years], ...
                                 @sum, ...
                                 0);
end
