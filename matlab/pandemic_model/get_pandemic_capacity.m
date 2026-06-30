 function [cap_m_arr, cap_o_arr] = get_pandemic_capacity(months_arr, month_trad_vaccine_ready, month_mrna_vaccine_ready, params, ind_m, ind_o, x_m_tau, x_o_tau)
	% Compute monthly vaccine doses available per event during a pandemic.
	%
	% Returns two (E x M) arrays of monthly vaccine output for mRNA and traditional
	% platforms. Capacity activates when the relevant vaccine is ready and ramps using
	% a fill-then-repurpose schedule over tau months (params.f_*, params.g_*).
	%
	% Args:
	%   months_arr               [E x M] Matrix of month indices for each event.
	%   month_trad_vaccine_ready [E x 1] Month when traditional vaccine becomes available.
	%   month_mrna_vaccine_ready [E x 1] Month when mRNA vaccine becomes available.
	%   params                   Struct with fields: tau_m, tau_o, f_m, f_o, g_m, g_o.
	%   ind_m                    [E x 1] Indicator: mRNA platform active for this event.
	%   ind_o                    [E x 1] Indicator: traditional platform active for this event.
	%   x_m_tau                  [E x 1] mRNA capacity at event start (monthly doses).
	%   x_o_tau                  [E x 1] Traditional capacity at event start.
	%
	% Returns:
	%   cap_m_arr  [E x M] Monthly mRNA vaccine output.
	%   cap_o_arr  [E x M] Monthly traditional vaccine output.
	% mRNA capacity
	cap_m_arr = (months_arr >= month_mrna_vaccine_ready) .* (months_arr < month_mrna_vaccine_ready + params.tau_m) .* (ind_m .* x_m_tau .* params.f_m) + ... % At-risk successful
		(months_arr >= month_mrna_vaccine_ready + params.tau_m) .* ind_m .* x_m_tau .* (params.f_m + params.g_m); % At-risk repurposed
	
	% Traditional capacity
	cap_o_arr = (months_arr >= month_trad_vaccine_ready) .* (months_arr < month_trad_vaccine_ready + params.tau_o) .* (ind_o .* x_o_tau .* params.f_o) + ...
		(months_arr >= month_trad_vaccine_ready + params.tau_o) .* ind_o .* x_o_tau .* (params.f_o + params.g_o);

end