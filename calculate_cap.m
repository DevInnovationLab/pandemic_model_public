function out = calculate_cap(tau, params, ind_m, ind_o, x_m, x_o)
    % Calculate capacity for different states of the world
	if tau <= params.tau_A
		out = 0;
	elseif tau <= (params.tau_A + params.tau_m)
		out = (ind_m) * x_m * params.f_m + (ind_o) * x_o * params.f_o;
	elseif tau <= (params.tau_A + params.tau_o)
		out = (ind_m) * x_m * (params.f_m + params.g_m) + (ind_o) * x_o * params.f_o;
	else
		out = (ind_m) * x_m * (params.f_m + params.g_m) + (ind_o) * x_o * (params.f_o + params.g_o);
	end
end