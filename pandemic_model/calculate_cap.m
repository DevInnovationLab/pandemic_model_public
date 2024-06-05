function out = calculate_cap(tau, tau_A, params, ind_m, ind_o, x_m_tau, x_o_tau)
	% all capacity is in millions

    % Calculate capacity, first index is for mRNA, second for traditional
	out = zeros(2, 1);
	if tau <= tau_A
		% no modification
	elseif tau <= (tau_A + params.tau_m)
		out(1) = (ind_m) * x_m_tau * params.f_m;
		out(2) = (ind_o) * x_o_tau * params.f_o;
	elseif tau <= (tau_A + params.tau_o)
		out(1) = (ind_m) * x_m_tau * (params.f_m + params.g_m);
		out(2) = (ind_o) * x_o_tau * params.f_o;
	else
		out(1) = (ind_m) * x_m_tau * (params.f_m + params.g_m);
		out(2) = (ind_o) * x_o_tau * (params.f_o + params.g_o);
	end

end