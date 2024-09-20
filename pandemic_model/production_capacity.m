function [x_tot, x_arr] = production_capacity(tau, tau_A, params, rd_state, x_m_tau, x_o_tau)

    %%% production capacity by technology platform based on what the rd_state of the world is
	
    if rd_state == 0 % output avg
        x_arr = [NaN NaN];
        x_tot = (params.p_b * x_b + params.p_m * x_m_only + params.p_o * x_o_only) / 10^6;
    elseif rd_state == 1 % both successful
        ind_m = 1;
		ind_o = 1;
		x_arr = calculate_cap(tau, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau);
		x_tot = sum(x_arr);
    elseif rd_state == 2 % only mRNA successful
        ind_m = 1;
		ind_o = 0;
		x_arr = calculate_cap(tau, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau);
		x_tot = sum(x_arr);
    elseif rd_state == 3 % only traditional successful
        ind_m = 0;
		ind_o = 1;
		x_arr = calculate_cap(tau, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau);
		x_tot = sum(x_arr);
    else % nothing is successful
        assert(rd_state == 4);
        x_arr = [0 0];
        x_tot = 0;
    end

    % x_arr and x_tot are in millions

end