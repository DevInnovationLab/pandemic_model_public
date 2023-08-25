function cap_costs_arr_PV = calc_adv_capacity_costs(params, z_m, z_o)

	periods = params.sim_periods;

	time_arr = (1:periods)';
	PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors

	cap_costs_arr = zeros(periods, 1); % array of costs
	cap_costs_arr(1) = (params.k_m * z_m + params.k_o * z_o) / 10^6; % costs to install advance capacity in year 1, in million
	cap_costs_arr(2:end) = (1-params.alpha) * params.delta * cap_costs_arr(1); % subsequent years, incur depreciation minus rental income
	cap_costs_arr_PV = PV_factor_yr .* cap_costs_arr; % in million

end