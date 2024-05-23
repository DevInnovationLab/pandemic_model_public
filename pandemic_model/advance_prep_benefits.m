function [vax_benefits, pv_tln, h_sum, vax_fraction_sum] = advance_prep_benefits(params)

	pop = params.P0;

	alpha = params.arrival.alpha;
	sigma = params.arrival.sigma;
	xi = params.arrival.xi;
	GDPPC = params.Y0;
	
	mu_prime = params.arrival.mu_prime;
    mu_prime_prime = params.arrival.mu_prime_prime;
    VSL = params.value_of_death;
    i_star = params.i_star;

	% Data for arrival of registered pandemics
	arrival = params.arrival;
    w = arrival.w;
	ones = arrival.ones;
	twos = arrival.twos;
	threes = arrival.threes;
	fours = arrival.fours;
	fives = arrival.fives;

	EconLoss = @(i,pop,GDPPC) pop.*(GDPPC./100).*exp(0.7393)*i.^0.4561;
    
    % Approach 1: cap loss at the upper threshold and use the integral to
    % get the right amount of mass

%     OLfactor = integral(@(i) ...
%         EconLoss(min(i,mu_prime_prime),pop,GDPPC) .*f (i,alpha,mu_prime,sigma,xi,w,ones,twos,threes,fours,fives), i_star, extinction);
% 
% 	MLfactor = integral(@(i) ...
%         (VSL*pop/1000) * min(i,mu_prime_prime) .* f(i,alpha,mu_prime,sigma,xi,w,ones,twos,threes,fours,fives), i_star, extinction);
    
	
    % Approach 2: adding an unit of mass at mu_prime_prime to account for the jump in
    % distribution

    OLfactor = integral(@(i) ...
        EconLoss(i, pop, GDPPC) .* f(i,alpha,mu_prime,sigma,xi,w,ones,twos,threes,fours,fives), i_star, mu_prime_prime) ...
        + EconLoss(mu_prime_prime, pop, GDPPC) * (1-f_cum(mu_prime_prime, alpha, mu_prime, sigma, xi, w, ones, twos, threes, fours, fives));

	MLfactor = integral(@(i) ...
        (VSL*pop/1000) * i .* f(i,alpha,mu_prime,sigma,xi,w,ones,twos,threes,fours,fives),i_star,mu_prime_prime) ...
        + (VSL*pop/1000) * mu_prime_prime * (1-f_cum(mu_prime_prime, alpha, mu_prime, sigma, xi, w, ones, twos, threes, fours, fives));

	Lratio = 10/13.8;
    LLfactor = Lratio * OLfactor;
    
	sum_new = OLfactor + MLfactor + LLfactor;
	pv_tln = 1/(1+params.r - f_cum(params.i_star, alpha, mu_prime, sigma, xi, w, ones, twos, threes, fours, fives) * (1+params.y)) * sum_new;
	
	state = 0; % use mean capacity
    [h_sum, vax_fraction_sum] = h_integral(params, state);

	vax_benefits = params.gamma * pv_tln * h_sum / 12; % h_sum is in months, so need to divide by 12
	
end