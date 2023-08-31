function params = params_default()
	%%% returns the default set of parameters
	
    params.y = 0.016;        % real gdp growth rate
    params.r = 0.04;         % social discount rate (needs to be less than y for geometric sum to work out)

	% Base year values (circa 2021)
	params.P0 = 7.89*10^9;	% base year population
	params.Y0 = 12236.6;		% base year GDP per capita

	params.i_COVID = 0.32;	% annual deaths per thousand
	params.i_star = params.i_COVID/2; % min intensity for next pandemic

    % this is the intensity threshold that doubles the prob of being in a pandemic that exceeds i_star (used for when assuming false pos rate is 50%)
    % this value is calculated in "arrival_distribution.m"
    params.i_star_w_false = 0.0559;

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
    params.mRNA_share = 0.5; % what pct of capacity is mRNA platform (remainder is traditional platform)

    params.k_m = 1.5;	% unit cost of mRNA capacity in advance
	params.k_o = 3.0;	% unit cost of traditional capacity in advance
	
	params.fill_finish_pct = 1/3; % pct of unit cost of advance capacity that's "fill and finish" (incurred at start of pandemic)

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

	params.tau_A = 3;	% months to approve / prep for vaccination campaign
	params.tau_m = 2;	% months to repurpose mRNA candidate
	params.tau_o = 6;	% months to repurpose traditional candidate

	params.gamma = 0.5; 	% fraction of remaining harm mitigated by vaccine

	params.T = 6;	% months to reach target vaccination rate

	params.beta = 100*10^6;	% in-pandemic kink in capital cost function

    params.x_target = 15.7*10^9;   % target total capacity in annual courses (x^{\prime\prime} in paper)
    params.x_avail = 4.5*10^9;     % total capacity in annual courses that can be achieved in pandemic (x^\prime in paper)

    params.conservative = 1;  % whether harm avoided is calculated at beginning (conservative) or end of period (not conservative)

    params.sim_periods = 200; % number of yrs in each simulation

    params.pandemic_dur_probs = [1 0 0]; % prob of pandemic of duration 1y, 2y, 3y (respectively)
	assert(sum(params.pandemic_dur_probs)==1)

    % parameters for R&D (if has_RD == 1)
    params.has_RD = 0;

    params.RD_spend = 5; % in billion, in PV
    params.RD_success_rate = 0.5; % what pct of time R&D spend matches the pandemic pathogen realized

    params.RD_impact_time = 1; % if R&D successful, how much tau_A is shortened by
    assert(params.RD_impact_time <= params.tau_A);

    params.RD_impact_vaccine = 0.01; % if R&D successful, how much the prob of vaccine is increased (for 2x for p_b, 1x for p_m, and 1x for p_o)
    assert(params.RD_impact_vaccine * 4 <= 1 - params.p_b - params.p_m - params.p_o);

    % allows user to specify level of advanced capacity
    params.has_user_cap_setting = 0;
	params.user_z_m = NaN;
	params.user_z_o = NaN;

end