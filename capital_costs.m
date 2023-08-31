function k = capital_costs(q, params, is_mRNA)

	if q <= params.beta
		if is_mRNA
			k = params.k_m * (1-params.fill_finish_pct) * q;
		else
			k = params.k_o * (1-params.fill_finish_pct) * q;
		end
	else
		if is_mRNA
			k = params.k_m * (1-params.fill_finish_pct) * q * (1/(1+params.epsilon)) * (params.epsilon * params.beta / q + (q/params.beta)^params.epsilon);
		else
			k = params.k_o * (1-params.fill_finish_pct) * q * (1/(1+params.epsilon)) * (params.epsilon * params.beta / q + (q/params.beta)^params.epsilon);
		end
	end

	k = k / 10^6; % in million
	
end