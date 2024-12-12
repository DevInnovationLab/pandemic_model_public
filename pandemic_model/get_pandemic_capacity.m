 function capacity = get_pandemic_capacity(months, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau)
	capacity = array2table(zeros(size(months, 1), 3), "VariableNames", ["month" "trad" "mrna"]);
	capacity.month = months;

	capacity.mrna = isbetween(months, tau_A + eps * 2, tau_A + params.tau_m) .* ((ind_m) * x_m_tau * (params.f_m)) + ... % At-risk successful
		(months > tau_A + params.tau_m) .* (ind_m) * x_m_tau * (params.f_m + params.g_m); % At-risk repurposed
	
	capacity.trad = isbetween(months, tau_A + eps * 2, tau_A + params.tau_o) .* ((ind_o) * x_o_tau * params.f_o) + ...
		(months > tau_A + params.tau_o) .* (ind_o) * x_o_tau * (params.f_o + params.g_o);

	capacity.total = capacity.mrna + capacity.trad;
end