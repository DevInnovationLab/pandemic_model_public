function vax_costs = advance_prep_costs(params)

	x_tot = params.x_target;

	x_m = (1/3) * x_tot; % total capacity mRNA
	x_o = (2/3) * x_tot; % total capacity traditional

	z_tot = params.x_target - (1-params.theta) * params.x_avail; % total advance capacity
	z_m = (1/3) * z_tot; % advance capacity mRNA
	z_o = (2/3) * z_tot; % advance capacity traditional
    
    arrival = params.arrival;
    alpha = arrival.alpha;
    mu = arrival.mu_prime;
%     mu_prime_prime = arrival.mu_prime_prime;
    sigma = arrival.sigma;
    xi = arrival.xi;
    
    w = arrival.w;
    ones = arrival.ones;
    twos = arrival.twos;
    threes = arrival.threes;
    fours = arrival.fours;
    fives = arrival.fives;
    
    Phi_star = f_cum(params.i_star, alpha, mu, sigma, xi, w, ones, twos, threes, fours, fives);

	costs_m = (1-params.alpha) * params.k_m * z_m + (1-params.alpha) * params.delta * params.k_m * z_m / (params.r + 1 - Phi_star) ...
		+ (1-Phi_star) / (params.r+1-Phi_star) * (capital_costs(x_m - z_m, params, 1) + params.c_m * x_m / (x_tot ) * 0.7 * params.P0);

	costs_o = (1-params.alpha) * params.k_o * z_o + (1-params.alpha) * params.delta * params.k_o * z_o / (params.r + 1 - Phi_star) ...
		+ (1-Phi_star) / (params.r+1-Phi_star) * (capital_costs(x_o - z_o, params, 0) + params.c_o * x_o / (x_tot ) * 0.7 * params.P0);

	vax_costs = costs_o + costs_m;

end