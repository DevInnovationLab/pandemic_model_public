 function [cap_m_arr, cap_o_arr] = get_pandemic_capacity(months, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau)
	% mRNA capacity
	cap_m_arr = isbetween(months, tau_A + eps * 2, tau_A + params.tau_m) .* ((ind_m) * x_m_tau * (params.f_m)) + ... % At-risk successful
		(months > tau_A + params.tau_m) .* (ind_m) * x_m_tau * (params.f_m + params.g_m); % At-risk repurposed
	
	% Traditional capacity
	cap_o_arr = isbetween(months, tau_A + eps * 2, tau_A + params.tau_o) .* ((ind_o) * x_o_tau * params.f_o) + ...
		(months > tau_A + params.tau_o) .* (ind_o) * x_o_tau * (params.f_o + params.g_o);

end