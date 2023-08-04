function x = production_capacity(tau, params, state)

	x_tot = params.x_target/12; % divide by 12 bc capacity is in annual courses and we are calculating for a month
	x_m = 1/3 * x_tot;
	x_o = 2/3 * x_tot;

	%%% both successful
	ind_m = 1;
	ind_o = 1;
	x_b = calculate_cap(tau, params, ind_m, ind_o, x_m, x_o);

	%%% only mRNA successful
	ind_m = 1;
	ind_o = 0;
	x_m_only = calculate_cap(tau, params, ind_m, ind_o, x_m, x_o);

	%%% only traditional successful
	ind_m = 0;
	ind_o = 1;
	x_o_only = calculate_cap(tau, params, ind_m, ind_o, x_m, x_o);

    %%% output based on what the state of the world is
	
    if state == 0 % output avg
        x = params.p_b * x_b + params.p_m * x_m_only + params.p_o * x_o_only;
    elseif state == 1 % both successful
        x = x_b;
    elseif state == 2 % only mRNA successful
        x = x_m_only;
    elseif state == 3 % only traditional successful
        x = x_o_only;
    else % nothing is successful
        assert(state == 4);
        x = 0;
    end

end