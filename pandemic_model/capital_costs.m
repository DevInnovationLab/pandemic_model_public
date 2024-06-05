function k = capital_costs(q, params, tailoring_fraction, is_mRNA, is_adv)

	q = q * 10^6; % q is fed in millions, turn into outright units for the calcs below to ensure nothing is messed up
	
	if q <= params.beta || is_adv == 1
		if is_mRNA == 1
			k = params.k_m * (1-tailoring_fraction) * q;
		else
			k = params.k_o * (1-tailoring_fraction) * q;
		end
	else
		if is_mRNA == 1
			k = params.k_m * (1-tailoring_fraction) * q * (1/(1+params.epsilon)) * (params.epsilon * params.beta / q + (q/params.beta)^params.epsilon);
		else
			k = params.k_o * (1-tailoring_fraction) * q * (1/(1+params.epsilon)) * (params.epsilon * params.beta / q + (q/params.beta)^params.epsilon);
		end
	end
	
	k = k / 10^6; % in million
	
end