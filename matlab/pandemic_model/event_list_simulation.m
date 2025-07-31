function event_list_simulation(simulation_table, econ_loss_model, params)
    %% INITIALIZATION: Extract event-level data and set up arrays
    % Extract events from simulation table
    event_sim_idx = ~isnan(simulation_table.yr_start);
    event_sim_table = simulation_table(event_sim_idx, :); % Remove simulations with no events
    event_sim_table = sortrows(event_sim_table, ["sim_num", "yr_start"]); % Make sure sorted

    % Basic simulation parameters
    sim_num = event_sim_table.sim_num;
    year_start = event_sim_table.yr_start;
    year_dur = event_sim_table.actual_dur;
    is_false = event_sim_table.is_false;
    prototype_available = event_sim_table.has_prototype;
    prep_start_month = event_sim_table.prep_start_month;
    false_pos_detected = isnan(prep_start_month) & is_false;
    ufv_protection = event_sim_table.ufv_protection; 

    num_sims = params.num_simulations;
    max_years = params.sim_periods;
    num_events = height(event_sim_table);

    % Event indices for aggregation
    event_start_idx = sub2ind([num_sims, max_years], sim_num, year_start);
    % [sim_idx, year_idx] = get_event_list_to_sim_year_idx(sim_num, month_start, month_dur);

    pv_factors_annual = (1+params.r).^(-(1:max_years)); % Annual discount factor

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

    %% COST CALCULATIONS
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
    prototype_rd_costs_nom = zeros(1, max_years);
    if params.prototype_RD
        prototype_rd_spend_rate = params.prototype_RD_spend / params.prototype_RD_benefit_start;
        prototype_rd_costs_nom(1:params.prototype_RD_benefit_start) = prototype_rd_spend_rate;
    end
    prototype_rd_costs_pv = prototype_rd_costs_nom .* pv_factors_annual;

    % Advance universal flu vaccine R&D costs
    ufv_rd_costs_nom = zeros(1, max_years);
    if params.ufv_invest
        ufv_rd_spend_rate = params.ufv_spend / params.prototype_RD_benefit_start;
        ufv_rd_costs_nom(1:params.prototype_RD_benefit_start) = ufv_rd_spend_rate;
    end
    ufv_rd_costs_pv = ufv_rd_costs_nom .* pv_factors_annual;

    % Tailoring costs
    tailoring_costs_nom = zeros(num_sims, max_years);
    tailoring_costs_nom(event_start_idx) = (...
        tailoring_fraction .* ...
        ~false_pos_detected .* ...
        (adv_cap_m(year_start) .* params.k_m + adv_cap_o(year_start) .* params.k_o)' ...
    );
    tailoring_costs_pv = tailoring_costs_nom .* pv_factors_annual;

    % In-pandemic R&D costs
    event_inp_rd_nom = prototype_available .* params.inp_RD_has_prototype + ~prototype_available .* params.inp_RD_no_prototype;
    inp_rd_costs_nom = zeros(num_sims, max_years);
    inp_rd_costs_nom(event_start_idx) = event_inp_rd_nom .* ~false_pos_detected .* ~ufv_protection;
    inp_rd_costs_pv = inp_rd_costs_nom .* pv_factors_annual;

    %% Pandemic simlations
    % Groups simulations by length to minimize redundant computation
    [sim_groups, group_ids] = findgroups(event_sim_table.actual_dur);
    results = cell(numel(group_ids), 1);

    % Parallelize pandemic simulations
    parfor g = 1:numel(group_ids)
        group_idx = (sim_groups == g);
        group_data = event_sim_table(group_idx, :);

        group_sim_nums = unique(group_data.sim_num);
        group_all_cap_m = all_cap_m(group_sim_nums, :);
        group_all_cap_o = all_cap_o(group_sim_nums, :);

        group_results = process_group(group_data, group_all_cap_m, group_all_cap_o, ...
                                      econ_loss_model, params);

        results{g} = group_results;
    end
    % Aggregate simulation results from group results, store in arrays, and put in sim_results table

    % Initialize arrays for simulation-level results (indexed by sim_num, year)
    sim_deaths_unmitigated = zeros(num_sims, max_years);
    sim_deaths_mitigated = zeros(num_sims, max_years);
    sim_mortality_losses_pv = zeros(num_sims, max_years);
    sim_output_losses_pv = zeros(num_sims, max_years);
    sim_learning_losses_pv = zeros(num_sims, max_years);
    sim_benefits_vaccine_pv = zeros(num_sims, max_years);
    sim_benefits_vaccine_nom = zeros(num_sims, max_years);
    sim_marginal_costs_nom = zeros(num_sims, max_years);
    sim_marginal_costs_pv = zeros(num_sims, max_years);

    % Initialize arrays for event-level results (indexed by event)
    vax_fraction_end = zeros(num_events, 1);
    u_deaths = zeros(num_events, 1);
    m_deaths = zeros(num_events, 1);
    cap_avail_m = zeros(num_events, 1);
    cap_avail_o = zeros(num_events, 1);
    vax_benefits = zeros(num_events, 1);
    m_mortality_losses = zeros(num_events, 1);
    m_output_losses = zeros(num_events, 1);
    m_learning_losses = zeros(num_events, 1);
    ex_post_severity = zeros(num_events, 1);
    inp_marg_costs_PV = zeros(num_events, 1);

    % Loop through each group and extract relevant simulation and event results
    for g = 1:numel(group_ids)
        group_results = results{g};
        group_idx = (sim_groups == g);
        group_sim_nums = unique(group_results.true_sim_nums);

        % Store simulation-level results (indexed by simulation and year)
        sim_deaths_unmitigated(group_sim_nums, :) = group_results.sim_deaths_unmitigated;
        sim_deaths_mitigated(group_sim_nums, :) = group_results.sim_deaths_mitigated;
        sim_mortality_losses_pv(group_sim_nums, :) = group_results.sim_mortality_losses_pv;
        sim_output_losses_pv(group_sim_nums, :) = group_results.sim_output_losses_pv;
        sim_learning_losses_pv(group_sim_nums, :) = group_results.sim_learning_losses_pv;
        sim_benefits_vaccine_pv(group_sim_nums, :) = group_results.sim_benefits_vaccine_pv;
        sim_benefits_vaccine_nom(group_sim_nums, :) = group_results.sim_benefits_vaccine_nom;
        sim_marginal_costs_nom(group_sim_nums, :) = group_results.sim_marginal_costs_nom;
        sim_marginal_costs_pv(group_sim_nums, :) = group_results.sim_marginal_costs_pv;

        % Store event-level results (indexed by event)
        vax_fraction_end(group_idx) = group_results.vax_fraction_end;
        u_deaths(group_idx) = group_results.u_deaths;
        m_deaths(group_idx) = group_results.m_deaths;
        cap_avail_m(group_idx) = group_results.cap_avail_m;
        cap_avail_o(group_idx) = group_results.cap_avail_o;
        vax_benefits(group_idx) = group_results.vax_benefits;
        m_mortality_losses(group_idx) = group_results.m_mortality_losses;
        m_output_losses(group_idx) = group_results.m_output_losses;
        m_learning_losses(group_idx) = group_results.m_learning_losses;
        ex_post_severity(group_idx) = group_results.ex_post_severity;
        inp_marg_costs_PV(group_idx) = group_results.inp_marg_costs_PV;
    end

    % Set up sim_results table with all simulation and event-level results
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

    % Fill in results only for simulations that had events
    sim_results.cap_avail_m(event_sim_idx) = cap_avail_m;
    sim_results.cap_avail_o(event_sim_idx) = cap_avail_o;
    sim_results.u_deaths(event_sim_idx) = u_deaths;
    sim_results.m_deaths(event_sim_idx) = m_deaths;
    sim_results.vax_benefits(event_sim_idx) = vax_benefits;
    sim_results.m_mortality_losses(event_sim_idx) = m_mortality_losses;
    sim_results.m_output_losses(event_sim_idx) = m_output_losses;
    sim_results.m_learning_losses(event_sim_idx) = m_learning_losses;
    sim_results.ex_post_severity(event_sim_idx) = ex_post_severity;
    sim_results.vax_fraction_end(event_sim_idx) = vax_fraction_end;
    sim_results.inp_marg_costs_PV(event_sim_idx) = inp_marg_costs_PV;
    sim_results.inp_tailoring_costs_PV(event_sim_idx) = tailoring_costs_pv(event_start_idx);
    sim_results.inp_RD_costs_PV(event_sim_idx) = inp_rd_costs_pv(event_start_idx);
    sim_results.inp_cap_costs_PV(event_sim_idx) = surge_cap_total_costs_pv(event_start_idx);

    % Save results if requested
    if params.save_output
        save_to_file(params.scenario_name, params.rawoutpath, sim_results, ...
            adv_cap_total_costs_nom, adv_cap_total_costs_pv, ...
            repmat(prototype_rd_costs_nom, num_sims, 1), repmat(prototype_rd_costs_pv, num_sims, 1), ...
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


function results = process_group(group_data, group_all_cap_m, group_all_cap_o, econ_loss_model, params)
%PROCESS_GROUP Perform all calculations for a group of events with the same duration.
%
%   group_results = process_group(group_data, econ_loss_model, params)
%
%   Inputs:
%       group_data        Struct with all relevant fields for this group (each field is a vector)
%       econ_loss_model   Economic loss model object
%       params            Struct of simulation parameters
%
%   Outputs:
%       group_results     Struct of results for this group (fields are arrays, one row per event)
%
%   This function is designed for clarity and modularity. It performs all
%   calculations for a group of events (rows) with the same duration in months.

    % Unpack group_data for clarity
    true_sim_num  = group_data.sim_num;
    eff_sim_num = findgroups(true_sim_num);
    year_start = group_data.yr_start;
    year_dur = group_data.actual_dur;
    annual_intensity = group_data.intensity;
    is_false = group_data.is_false;
    rd_state = group_data.rd_state;
    ufv_protection = group_data.ufv_protection;
    month_vaccine_ready = group_data.month_vaccine_ready;

    max_years = params.sim_periods;
    num_events = height(group_data);
    num_sims = numel(unique(true_sim_num));
    month_start = (year_start - 1) * 12 + 1;
    month_dur = ceil(year_dur * 12);
    max_month_dur = max(month_dur);

    % 1. Indices and masks
    %% Not sure that we need this 
    accum_idx = (month_dur >= (1:max_month_dur));
    active_idx = accum_idx & ~is_false;

    % Event indices for aggregation
    event_start_idx = sub2ind([num_sims, max_years], eff_sim_num, year_start);
    [sim_idx, year_idx] = get_event_list_to_sim_year_idx(eff_sim_num, month_start, month_dur);
    
    % Discount and growth factors
    months_matrix = repmat(1:max_month_dur, num_events, 1); % E x M
    growth_factors_monthly = (1 + params.y).^((month_start + months_matrix - 1)/12);
    pv_factors_monthly = (1/(1 + params.r)).^((month_start + months_matrix - 1)/12);
    
    % Calculate intervention effects
    [ind_m, ind_o] = get_capacity_indicators(rd_state); % E x 1
    cap_avail_m = group_all_cap_m(event_start_idx) / 12;
    cap_avail_o = group_all_cap_o(event_start_idx) / 12;
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
    ) .* active_idx; % No vaccination with false positive
    monthly_courses_o = (...
        first_vax_idx .* cap_o + ...
        ~first_vax_idx .* max_booster_rate .* (1 - share_cap_m) ...
    ) .* active_idx;

    % Pandemic losses
    monthly_intensity = (annual_intensity ./ 12) .* active_idx; % E x M
    monthly_deaths_unmitigated = (params.P0 / 10000) .* monthly_intensity; % E x M
    unmitigated_output_losses = (econ_loss_model.predict(annual_intensity) ./12) .* active_idx;
    monthly_deaths_mitigated = monthly_deaths_unmitigated .* (1 - h_arr);

    mortality_losses_nom = monthly_deaths_mitigated .* params.value_of_death .* growth_factors_monthly;
    output_losses_nom = unmitigated_output_losses .* (params.Y0 .* params.P0) .* (1 - h_arr) .* growth_factors_monthly; % Should be E x 1
    learning_losses_nom = output_losses_nom .* (10 / 13.8);
    total_losses_nom = mortality_losses_nom + output_losses_nom + learning_losses_nom;
    vax_benefits_nom =  (total_losses_nom ./ (1 - h_arr)) - total_losses_nom;

    mortality_losses_pv = mortality_losses_nom .* pv_factors_monthly;
    output_losses_pv = output_losses_nom .* pv_factors_monthly;
    learning_losses_pv = learning_losses_nom .* pv_factors_monthly;
    vax_benefits_pv = vax_benefits_nom .* pv_factors_monthly;

    % Vaccination costs
    marginal_costs_nom = params.c_m .* monthly_courses_m + monthly_courses_o .* params.c_o;
    marginal_costs_pv = marginal_costs_nom .* pv_factors_monthly;
    sim_marginal_costs_nom = event_list_to_sim_year(marginal_costs_nom, sim_idx, year_idx, num_sims, max_years, accum_idx);
    sim_marginal_costs_pv = event_list_to_sim_year(marginal_costs_pv, sim_idx, year_idx, num_sims, max_years, accum_idx);

    % Deaths
    sim_deaths_unmitigated = event_list_to_sim_year(monthly_deaths_unmitigated, sim_idx, year_idx, num_sims, max_years, accum_idx);
    sim_deaths_mitigated = event_list_to_sim_year(monthly_deaths_mitigated, sim_idx, year_idx, num_sims, max_years, accum_idx);

    % Losses and benefits
    % sim_mortality_losses_nom = event_list_to_sim_year(mortality_losses_nom, eff_sim_idx, year_idx, num_sims, max_years);
    % sim_output_losses_nom = event_list_to_sim_year(output_losses_nom, eff_sim_idx, year_idx, num_sims, max_years);
    % sim_learning_losses_nom = event_list_to_sim_year(learning_losses_nom, eff_sim_idx, year_idx, num_sims, max_years);
    sim_mortality_losses_pv = event_list_to_sim_year(mortality_losses_pv, sim_idx, year_idx, num_sims, max_years, accum_idx);
    sim_output_losses_pv = event_list_to_sim_year(output_losses_pv, sim_idx, year_idx, num_sims, max_years, accum_idx);
    sim_learning_losses_pv = event_list_to_sim_year(learning_losses_pv, sim_idx, year_idx, num_sims, max_years, accum_idx);

    sim_benefits_vaccine_nom = event_list_to_sim_year(vax_benefits_nom, sim_idx, year_idx, num_sims, max_years, accum_idx);
    sim_benefits_vaccine_pv = event_list_to_sim_year(vax_benefits_pv, sim_idx, year_idx, num_sims, max_years, accum_idx);

    % Store all relevant results in a struct for output
    results = struct();

    % First this indexed by simulation / year
    results.true_sim_nums = true_sim_num;
    results.sim_marginal_costs_nom = sim_marginal_costs_nom;
    results.sim_marginal_costs_pv = sim_marginal_costs_pv;
    results.sim_deaths_unmitigated = sim_deaths_unmitigated;
    results.sim_deaths_mitigated = sim_deaths_mitigated; 
    results.sim_mortality_losses_pv = sim_mortality_losses_pv;
    results.sim_output_losses_pv = sim_output_losses_pv;
    results.sim_learning_losses_pv = sim_learning_losses_pv;
    results.sim_benefits_vaccine_nom = sim_benefits_vaccine_nom;
    results.sim_benefits_vaccine_pv = sim_benefits_vaccine_pv;

    % Then those indexed by event (for sim_results table)
    results.vax_fraction_end = vax_fraction_cum(:, end);
    results.u_deaths = sum(monthly_deaths_unmitigated, 2);
    results.m_deaths = sum(monthly_deaths_mitigated, 2);
    results.cap_avail_m = max(cap_m, [], 2);
    results.cap_avail_o = max(cap_o, [], 2);
    results.vax_benefits = sum(vax_benefits_pv, 2);
    results.m_mortality_losses = sum(mortality_losses_pv, 2);
    results.m_output_losses = sum(output_losses_pv, 2);
    results.m_learning_losses = sum(learning_losses_pv, 2);
    results.ex_post_severity = sum(monthly_deaths_mitigated, 2) ./ (params.P0 / 10000);
    results.inp_marg_costs_PV = sum(marginal_costs_pv, 2);
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


function sim_year_matrix = event_list_to_sim_year(values_matrix, sim_idx, year_idx, num_sims, max_years, accum_idx)
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
    values = values_max_t((accum_idx == 1)');

    sim_year_matrix = accumarray([sim_idx, year_idx], ...
                                 values, ...
                                 [num_sims, max_years], ...
                                 @sum, ...
                                 0);
end
