function out = calc_adv_capacity_costs(params, yr_start, prep_start_month, nom_cost, pv, capacity_kept)
	% takes in an nominal investment in a given yr and month, adds depreciation for all subsequent years, and pv's to today

	periods = params.sim_periods;

	time_arr = (1:periods)';
	PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors
		
    PV_factor_yr_start = (1/(1+params.r))^(yr_start-1) * (1/(1+params.r))^(1/12 * (prep_start_month+1)); % pv factor for month of expenditure within start year

	cap_costs_arr = zeros(periods, 1); % array of costs
	cap_costs_arr(yr_start) = (params.delta)^(1/12 * (12-prep_start_month-1)) * nom_cost; % for the remaining months in the build year, no rental and incurs depreciation
	
	cap_costs_arr(yr_start+1:end) = (1-params.alpha) * params.delta * nom_cost * capacity_kept; % subsequent years, incur depreciation minus rental income on fraction kept if not adv
	cap_costs_arr_PV = PV_factor_yr .* cap_costs_arr; % in million

	cap_costs_arr(yr_start) = cap_costs_arr(yr_start) + nom_cost; % add in the upfront cost to the series
	cap_costs_arr_PV(yr_start) = cap_costs_arr_PV(yr_start) + nom_cost * PV_factor_yr_start; % add in the upfront cost to the series

	if pv == 1 
		out = cap_costs_arr_PV;
	else
		out = cap_costs_arr;
	end

end