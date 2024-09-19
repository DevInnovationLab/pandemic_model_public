function [posterior1, posterior2] = gen_surveil_signals(is_false_arr)

	% alpha and beta satisfies a prior mean of 0.5 (=alpha/(alpha+beta)),
    % which is policy-maker's probability belief of being in a real pandemic, 
	% prior to any signals, follows beta distribution (prior is same 1-false pos rate)
    alpha = 0.5; % parameter of beta distribution
	beta = 0.5; % parameter of beta distribution

	k = alpha + beta;

	n = 10; % number of signals in each surveillance round

	cnt = length(is_false_arr);

	is_pandemic = ~is_false_arr; % true state of the world
	
	% probability that each signal is flipped successfully
	p1 = 0.4 + 0.2 * is_pandemic; % 0.4 when false, 0.6 when true
	p2 = 0.2 + 0.6 * is_pandemic; % 0.2 when false, 0.8 when true
	
	y1 = binornd(n, p1, cnt, 1); % draw of a set of signals for first round
	y2 = binornd(n, p2, cnt, 1); % draw of a set of signals for second round
	
	% Calculate posterior means
	posterior1 = n/(n+k) * y1/n + k/(n+k) * alpha/k;
	posterior2 = n/(n+k) * y2/n + k/(n+k) * alpha/k;
	
end