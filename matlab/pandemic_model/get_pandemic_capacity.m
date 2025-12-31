 function [cap_m_arr, cap_o_arr] = get_pandemic_capacity(months_arr, month_trad_vaccine_ready, month_mrna_vaccine_ready, params, ind_m, ind_o, x_m_tau, x_o_tau)
	% mRNA capacity
	cap_m_arr = (months_arr > month_mrna_vaccine_ready) & (months_arr <= month_mrna_vaccine_ready + params.tau_m) .* (ind_m .* x_m_tau .* params.f_m) + ... % At-risk successful
		(months_arr > month_mrna_vaccine_ready + params.tau_m) .* ind_m .* x_m_tau .* (params.f_m + params.g_m); % At-risk repurposed
	
	% Traditional capacity
	cap_o_arr = (months_arr > month_trad_vaccine_ready) & (months_arr <= month_trad_vaccine_ready + params.tau_o) .* (ind_o .* x_o_tau .* params.f_o) + ...
		(months_arr > month_trad_vaccine_ready + params.tau_o) .* ind_o .* x_o_tau .* (params.f_o + params.g_o);

end