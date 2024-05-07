% rng(0);

is_pandemic_0 = 0; % true state of the world

theta_prior = 0.5; % policy-maker's probability belief of being in a real pandemic, prior to any signals, follows beta distribution

alpha = 0.5; % parameter of beta distribution
beta = 0.5; % parameter of beta distribution

k = alpha + beta;

n = 10; % number of signals in each surveillance round

% probability that each signal is flipped successfully
if is_pandemic_0 == 0 
	p = 0.3;
else
	p = 0.7;
end

y = binornd(n, p);

theta_posterior = n/(n+k) * y/n + k/(n+k) * alpha/k;

is_pandemic = binornd(1, theta_posterior);

prepare_for_pandemic = (is_pandemic & y >= n/2);
