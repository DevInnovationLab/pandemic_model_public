function out = calc_adv_capacity_costs(params, yr, nom_cost, pv)
	% takes in an nominal investment in a given yr, adds depreciation for all subsequent years, and pv's to today

	periods = params.sim_periods;

	time_arr = (1:periods)';
	PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors

	cap_costs_arr = zeros(periods, 1); % array of costs
	cap_costs_arr(yr) = nom_cost;
	cap_costs_arr(yr+1:end) = (1-params.alpha) * params.delta * cap_costs_arr(yr); % subsequent years, incur depreciation minus rental income
	cap_costs_arr_PV = PV_factor_yr .* cap_costs_arr; % in million

	if pv==1 
		out = cap_costs_arr_PV;
	else
		out = cap_costs_arr;
	end

end