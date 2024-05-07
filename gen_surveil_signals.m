function out_posteriors = gen_surveil_signals(is_false_arr)

	% alpha and beta satisfies a prior mean of 0.5 (=alpha/(alpha+beta)),
    % which is policy-maker's probability belief of being in a real pandemic, prior to any signals, follows beta distribution (prior is same 1-false pos rate)
    alpha = 0.5; % parameter of beta distribution
	beta = 0.5; % parameter of beta distribution

	k = alpha + beta;

	n = 10; % number of signals in each surveillance round

	cnt = length(is_false_arr);

	out_posteriors = zeros(cnt, 2);
	for i=1:cnt
	
		is_pandemic_0 = ~is_false_arr(i); % true state of the world
		
		% probability that each signal is flipped successfully
		if is_pandemic_0 == 0 
			p = 0.4;
		else
			p = 0.6;
		end

		y = binornd(n, p); % draw of a set of signals -- this is the coarse signal that is available with and without surveillance
		theta_posterior1 = n/(n+k) * y/n + k/(n+k) * alpha/k; % posterior mean
		
		if is_pandemic_0 == 0 
			p = 0.2;
		else
			p = 0.8;
		end

		y = binornd(n, p); 
		theta_posterior2 = n/(n+k) * y/n + k/(n+k) * alpha/k; % posterior mean

		out_posteriors(i,:) = [theta_posterior1 theta_posterior2];
	end

end