function [posterior1, posterior2] = gen_surveil_signals(is_false_arr, false_rate)
	% Generates surveillance signals for pandemic detection based on a two-stage surveillance system
	%
	% Args:
	%   is_false_arr: Array of boolean values indicating if each case is a false positive
	%   false_rate: Base false positive rate used for prior distribution
	%
	% Returns:
	%   posterior1: Array of posterior probabilities after first surveillance round
	%   posterior2: Array of posterior probabilities after second surveillance round
	%
	% The function models a two-stage surveillance system where:
	% - Prior belief follows a Beta distribution parameterized by false positive rate
	% - Each surveillance round generates n=10 binary signals
	% - Signal accuracy improves for true pandemics vs false positives
	% - First round: 60% accuracy for true pandemics, 40% for false positives
	% - Second round: 80% accuracy for true pandemics, 20% for false positives
	% Posterior probabilities are calculated using Bayesian updating

	% Set up prior Beta distribution parameters
    alpha = 1 - false_rate; % parameter of beta distribution
	beta = false_rate; % parameter of beta distribution
	k = alpha + beta;

	n = 10; % number of signals in each surveillance round
	cnt = length(is_false_arr);

	% Define signal accuracy probabilities for each round
	p1 = 0.4 + 0.2 * ~is_false_arr; % 0.4 when false, 0.6 when true
	p2 = 0.2 + 0.6 * ~is_false_arr; % 0.2 when false, 0.8 when true
	
	% Generate binomial draws representing surveillance signals
	y1 = binornd(n, p1, cnt, 1); % draw of a set of signals for first round
	y2 = binornd(n, p2, cnt, 1); % draw of a set of signals for second round
	
	% Calculate posterior probabilities using Bayesian update
	posterior1 = (alpha + y1) ./ (n + k);
	posterior2 = (alpha + y2) ./ (n + k);
	
end