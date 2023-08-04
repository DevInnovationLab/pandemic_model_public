function params = params_default()
	%%% returns the default set of parameters
	
    params.y = 0.016;        % gdp growth rate
    params.r = 0.04;         % social discount rate (needs to be less than y for geometric sum to work out)

	% Base year values (circa 2021)
	params.P0 = 7.89*10^9;	% base year population
	params.Y0 = 12236.6;		% base year GDP per capita

	params.i_COVID = 0.32;	% annual deaths per thousand
	params.i_star = params.i_COVID/2; % min intensity for next pandemic

	arrival.sigma = 0.0113;
	arrival.xi = 1/0.71;
	arrival.alpha = 0.62;
	
	arrival.mu_prime = 10^(-3);
	
	Spanish_mid = 5.694051496;
	Spanish_hi = (100/32) * Spanish_mid;
    
    arrival.mu_prime_prime = Spanish_hi;
	arrival.extinction = 1000;

    % Data for arrival of registered pandemics
	arrival.w = 20; % Window width in years
	arrival.ones = 7; % Years in recent window with one pandemic
	arrival.twos = 0; % Years in recent window with two pandemics
	arrival.threes = 0; % Years in recent window with three pandemics
	arrival.fours = 0; % Years in recent window with four pandemics
	arrival.fives = 0; % Years in recent window with five pandemics

	params.arrival = arrival;

	params.value_of_death = 1.3*10^6; % we use this to monetize death, it is not conceptually a VSL

	params.theta = 0.25; % fraction reduction of pandemic-time investments due to advance capacity

	params.delta = 0.08; 	% annual depreciation (=d in paper)
	params.alpha = 0.7; 	% fraction advance investment recoverable via rental (=phi in paper)

	%%% costs are in units of per course (there can be more than 1 dose per
    %%% course, typically two doses per course)
    params.k_m = 1.5;	% unit cost of mRNA capacity in advance
	params.k_o = 3.0;	% unit cost of traditional capacity in advance
	params.c_m = 6;		% marginal cost of producing mRNA vaccines
	params.c_o = 3;		% marginal cost of producing traditional vaccines

	params.epsilon = 1;	% decreasing returns to capacity installed during pandemic

	params.p_b = 0.5; 	% prob both technologies are successful
	params.p_m = 0.15;	% prob only mRNA successful
	params.p_o = 0.15; 	% prob only traditional platform successful

	params.f_m = 0.3; 	% fraction of at risk capacity successful in mRNA platform
	params.f_o = 0.3; 	% fraction of at risk capacity successful in traditional platform

	params.g_m = 0.4; 	% fraction of at risk capacity unsuccessful/repurpose-able in mRNA platform
	params.g_o = 0.4; 	% fraction of at risk capacity unsuccessful/repurpose-able in traditional platform

	params.tau_A = 0;	% months to approve vaccine (conditional on a successful vaccine)
	params.tau_m = 2;	% months to repurpose mRNA candidate
	params.tau_o = 6;	% months to repurpose traditional candidate

	params.gamma = 0.5; 	% fraction of remaining harm mitigated by vaccine

	params.T = 6;	% months to reach target vaccination rate

	params.beta = 100*10^6;	% in-pandemic kink in capital cost function

% 	params.x_target = 15.7*10^9;   % target total capacity in annual courses (x^{\prime\prime} in paper)
    params.x_target = 15.7*10^9*1.8;   % target total capacity in annual courses (x^{\prime\prime} in paper) -- so that there is 70% vax rate in 6 months in the event both platforms are successful
    params.x_avail = 4.5*10^9;     % total capacity in annual courses that can be achieved in pandemic (x^\prime in paper)

    params.conservative = 1;  % whether harm avoided is calculated at beginning (conservative) or end of period (not conservative)

end