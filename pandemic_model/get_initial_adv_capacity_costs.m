function [z_m0_arr, z_o0_arr, cap_costs_arr_PV0, cap_costs_arr_nom0] = get_initial_adv_capacity_costs(params)
    
    z_m = params.z_m
    z_o = params.z_o

    z_m_per_yr = z_m / params.adv_cap_build_period;
    z_o_per_yr = z_o / params.adv_cap_build_period;

    cap_costs_arr_PV0  = zeros(params.sim_periods, params.adv_cap_build_period); % keep track of cost series for each build year (cumulative), each col is for a t
    cap_costs_arr_nom0 = zeros(params.sim_periods, params.adv_cap_build_period); % keep track of cost series for each build year (cumulative), each col is for a t
    
    cap_cost_cum_PV = zeros(params.sim_periods, 1); % cost series that we enter each year t with
    cap_cost_cum_nom = zeros(params.sim_periods, 1); % cost series that we enter each year t with
    for t=1:params.adv_cap_build_period
        nom_cost_adv_t = capital_costs(z_m_per_yr, params, 1, 1) + capital_costs(z_o_per_yr, params, 0, 1); % costs to install advance capacity in year t, in million
        
        pv = 1;
        cap_cost_t = calc_adv_capacity_costs(params, t, 0, nom_cost_adv_t, pv, 1); % in million, time series for full sim period
        cap_costs_arr_PV0(:, t) = cap_cost_t + cap_cost_cum_PV;
        cap_cost_cum_PV = cap_costs_arr_PV0(:, t); % cost series for start of next year

        pv = 0;
        cap_cost_t = calc_adv_capacity_costs(params, t, 0, nom_cost_adv_t, pv, 1); % in million, time series for full sim period
        cap_costs_arr_nom0(:, t) = cap_cost_t + cap_cost_cum_nom;
        cap_cost_cum_nom = cap_costs_arr_nom0(:, t); % cost series for start of next year
    end

    time_arr = 1:params.adv_cap_build_period;
    z_m0_arr = time_arr * z_m_per_yr; % amt of adv capacity available in given year (by year-end)
    z_o0_arr = time_arr * z_o_per_yr; % amt of adv capacity available in given year (by year-end)

end