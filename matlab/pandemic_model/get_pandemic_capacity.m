 function [cap_m_arr, cap_o_arr] = get_pandemic_capacity(months_arr, tau_a, params, ind_m, ind_o, x_m_tau, x_o_tau)
	% mRNA capacity
	cap_m_arr = isbetween(months_arr, tau_a, tau_a + params.tau_m, "openleft") .* (ind_m .* x_m_tau .* params.f_m) + ... % At-risk successful
		(months_arr > tau_a + params.tau_m) .* ind_m .* x_m_tau .* (params.f_m + params.g_m); % At-risk repurposed
	
	% Traditional capacity
	cap_o_arr = isbetween(months_arr, tau_a, tau_a + params.tau_o, "openleft") .* (ind_o .* x_o_tau .* params.f_o) + ...
		(months_arr > tau_a + params.tau_o) .* ind_o .* x_o_tau .* (params.f_o + params.g_o);

end