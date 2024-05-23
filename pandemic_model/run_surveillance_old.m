function prep_start_month_arr = run_surveillance_old(is_false_arr, has_surveil, threshold_surveil_arr)

	threshold_no_surveil = threshold_surveil_arr(1);
	threshold_surveil = threshold_surveil_arr(2);

	% alpha and beta satisfies a prior mean of 0.5 (=alpha/(alpha+beta)),
    % which is policy-maker's probability belief of being in a real pandemic, prior to any signals, follows beta distribution (prior is same 1-false pos rate)
    alpha = 0.5; % parameter of beta distribution
	beta = 0.5; % parameter of beta distribution

	k = alpha + beta;

	n = 10; % number of signals in each surveillance round

	cnt = length(is_false_arr);
	prep_start_month_arr = zeros(cnt, 1);

	for i=1:cnt
	
		is_pandemic_0 = ~is_false_arr(i); % true state of the world
		
		% probability that each signal is flipped successfully
		if is_pandemic_0 == 0 
			p = 0.4;
		else
			p = 0.6;
		end

		y = binornd(n, p); % draw of a set of signals -- this is the coarse signal that is available with and without surveillance
		theta_posterior = n/(n+k) * y/n + k/(n+k) * alpha/k; % posterior mean
		% is_pandemic = binornd(1, theta_posterior); % posterior indication
		% prepare_for_pandemic1 = (is_pandemic & y >= n/2); % decision rule from first set of signals
		
		if has_surveil == 1
			prepare_for_pandemic1 = theta_posterior > threshold_surveil; % decision rule from first set of signals
		else
			prepare_for_pandemic1 = theta_posterior > threshold_no_surveil;
		end

		if has_surveil && ~prepare_for_pandemic1 % a second signal if has surveillance and hasn't acted

			if is_pandemic_0 == 0 
				p = 0.2;
			else
				p = 0.8;
			end

			% draw of a set of signals -- this is the finer signal that is available only with surveillance 
			% and only relevent if the outcome from the first set of signals isn't act
			y = binornd(n, p); 
			theta_posterior = n/(n+k) * y/n + k/(n+k) * alpha/k; % posterior mean
			% is_pandemic = binornd(1, theta_posterior); % posterior indication
			% prepare_for_pandemic2 = (is_pandemic & y >= n/2); % decision rule from second set of signals
			prepare_for_pandemic2 = theta_posterior > threshold_surveil; % decision rule from second set of signals
		end
		
		if has_surveil == 1 % has access to two sets of signals
			
			if prepare_for_pandemic1
				prep_start_month = 0;
            elseif prepare_for_pandemic2
				prep_start_month = 1;
			else
				
				if is_pandemic_0
					prep_start_month = 2;
				else
					prep_start_month = NaN; % correctly anticipated no pandemic
				end

			end
		
		else % no surveil == access to only one set of signals
		
			if prepare_for_pandemic1 % only has access to one set of signals but one month later
				prep_start_month = 1;
			else
				if is_pandemic_0
					prep_start_month = 2;
				else
					prep_start_month = NaN; % correctly anticipated no pandemic
				end
			end
		
		end

		prep_start_month_arr(i) = prep_start_month;
		
	end
end