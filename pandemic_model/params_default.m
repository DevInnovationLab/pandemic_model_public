function params = params_default()
	%%% returns the default set of parameters
	
    params.y = 0.016;        % real gdp growth rate
    params.r = 0.04;         % social discount rate (needs to be less than y for geometric sum to work out)

	% Base year values (circa 2021)
	params.P0 = 7.89*10^9;	% base year population
	params.Y0 = 12236.6;		% base year GDP per capita

    % this is the intensity threshold that doubles the prob of being in a pandemic that exceeds i_star (used for when assuming false pos rate is 50%) (NOT USED)
    % this value is calculated in "arrival_distribution.m"
    % params.i_star_w_false = 0.0559;

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
    % params.value_of_death = 0.13*10^6; % we use this to monetize death, it is not conceptually a VSL

	params.theta = 0.25; % fraction reduction of pandemic-time investments due to advance capacity
	params.delta = 0.19; 	% annual depreciation (=d in paper) (LB)

	%%% costs are in units of per course (there can be more than 1 dose per
    %%% course, typically two doses per course)
    params.mRNA_share = 0.5; % what pct of capacity is mRNA platform (remainder is traditional platform)
    params.capacity_kept = 0.5; % what proportion of capacity is kept after a pandemic (pseudo LB)

    params.k_m = 3.25;	% unit cost of mRNA capacity in advance (LB)
	params.k_o = 0.96;	% unit cost of traditional capacity in advance (LB)
	
	params.tailoring_fraction = 1/3; % pct of unit cost of advance capacity that's "fill and finish" (incurred at start of any pandemic, incl false positives)

	params.c_m = 34;		% marginal cost of producing mRNA vaccines (LB per course)
	params.c_o = 17;		% marginal cost of producing traditional vaccines (LB per course)

	params.epsilon = 1;	% decreasing returns to capacity installed during pandemic

	% adds up to 40% total
	params.p_b = 0.25; 	% prob both technologies are successful
	params.p_m = 0.075;	% prob only mRNA successful
	params.p_o = 0.075;    % prob only traditional platform successful

	params.f_m = 0.2; 	% fraction of at risk capacity successful in mRNA platform
	params.f_o = 0.2; 	% fraction of at risk capacity successful in traditional platform

	params.g_m = 0.4; 	% fraction of at risk capacity unsuccessful/repurpose-able in mRNA platform
	params.g_o = 0.4; 	% fraction of at risk capacity unsuccessful/repurpose-able in traditional platform

	params.tau_A = 14;	% months to approve / prep for vaccination campaign (in status quo, is it tau_A + 1, as surveillance generates possibility of one month quicker)
	params.tau_m = 2;	% months to repurpose mRNA candidate
	params.tau_o = 6;	% months to repurpose traditional candidate

	params.gamma = 0.5; 	% fraction of remaining harm mitigated by vaccine

% 	params.T = 6;	% months to reach target vaccination rate (don't think this is actually used now?)

	params.beta = 100*10^6;	% in-pandemic kink in capital cost function

    params.x_target = 15.7*10^9;   % target total capacity in annual courses (x^{\prime\prime} in paper)
    params.x_avail = 4.5*10^9;     % total capacity in annual courses that can be achieved in pandemic (x^\prime in paper)

    params.conservative = 1;  % whether harm avoided is calculated at beginning (conservative) or end of period (not conservative)

    params.pandemic_dur_probs = [0.5 0.2 0.3]; % prob of pandemic of duration 1y, 2y, 3y (respectively)
	assert(sum(params.pandemic_dur_probs)==1)

    % parameters for R&D (if has_RD == 1)
    params.has_RD = 0;
	params.pathogens_per_family = 3;
	params.pathogen_families_to_research = 3;
	params.adv_RD_cost_per_pathogen = 1.4; % in billion, nominal over period specified by RD_benefit_start (Dimitrios said to use 3x 1.4 bn, times number of families)

    % params.RD_success_rate = 0.5; % what pct of time R&D spend matches the pandemic pathogen realized -- DEPRECIATED

    params.RD_speedup_months = 0; % if R&D successful, how much tau_A is shortened by
    params.RD_success_rate_increase_per_platform = 0; % if R&D successful, how much the prob of vaccine is increased (for 2x for p_b, 1x for p_m, and 1x for p_o)
	params.rental_share = 0.4;

    params.RD_inp_noRD =  0.776297560 ; % bn of nominal
    params.RD_inp_withRD =  0.531221781; % bn of nominal

	% this freq table lists the families and the probabilty mass associated with them (needs to sum to 1)
	params.RD_family_freq_table = [
		1, 0.1;
		2, 0.1;
		3, 0.1;
		4, 0.1;
		5, 0.1;
		6, 0.1;
		7, 0.1;
		8, 0.1;
		9, 0.1;
	   10, 0.1
	];

	params.share_target_advanced_capacity = 0;
	params.enhanced_surveillance = 0;
	params.surveillance_thresholds = [0 0]; % First is for regular signal, second is for enhanced surveillance signal.

	params.RD_benefit_start = 15; % even with RD benefit, won't realize any until after this year

	params.adv_cap_build_period = 30; % number of years it takes to finish building adv capacity

	params.surveil_annual_installation_spend = 5; % Initial spending to install enhanced surveillance, nom bn
	params.surveil_installation_years = 2; % Time initial costs are incurred, nom bn
	params.surveil_maintenance_spend = 1.25; % Maintenance spending on enhanced surveillance nom bn
	params.surveil_spend = 5; 

	params.save_output = 1;

end

% You really ought to move this.
function RD_family_freq_table = create_RD_family_freq_table(num_families)
    % Create the first column with natural numbers from 1 to N
    families = (1:num_families)';
    probabilities = ones(num_families, 1) / num_families;
    
    % Combine the columns into an N by 2 matrix
    RD_family_freq_table = [families, probabilities];
end