%%%%%%%%%%%%%%%%%% user input parameters %%%%%%%%%%%%%%%%%%
yr_start = 15;
intensity = 0.455755823162853;
state = 3;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

draw_lower = 0.867; % this is the cumulative prob for mu \leq 10^{-3} 
draw_upper = 0.9994; % if the uniform draw exceeds this, cannot invert (set to mu_prime_prime)
periods = 200;
% sim_cnt = 100;
addl_yrs = 5; % additional years to simulate out costs and benefits in case a pandemic hits at end of the 200-yr simulation period
periods_tot = periods + addl_yrs;
pandemic_natural_dur = 0; % assume a pandemic naturally lasts pandemic_natural_dur+1 years;

% parameters that need to be unpacked for functions to work

params = params_default;
arrival = params.arrival;

alpha = arrival.alpha;
mu = arrival.mu_prime;
mu_prime_prime = arrival.mu_prime_prime;
sigma = arrival.sigma;
xi = arrival.xi;

w = arrival.w;
ones = arrival.ones;
twos = arrival.twos;
threes = arrival.threes;
fours = arrival.fours;
fives = arrival.fives;

% vax_net_benefits_bn_arr = zeros(sim_cnt, 1); % array of net benefits for the simulations
% vax_costs_bn_arr = zeros(sim_cnt, 1); % array of costs
% vax_benefits_bn_arr = zeros(sim_cnt, 1); % array of benefits

% yr_start_arr = zeros(sim_cnt, 1); % array of start yr of pandemic
% intensity_arr = zeros(sim_cnt, 1); % array of pandemic intensities (assumed to be intensity associated with start yr)
% state_arr = zeros(sim_cnt, 1); % array of state of production

time_arr = (1:periods_tot)';
PV_factor = (1+params.r).^(-time_arr); % array of discount factors
i0 = [mu, mu_prime_prime];
    
%%%%%%%%%% Costs -- certain %%%%%%%%%%

x_tot = params.x_target;
x_m = (1/3) * x_tot; % total capacity mRNA
x_o = (2/3) * x_tot; % total capacity traditional

z_tot = params.x_target - (1-params.theta) * params.x_avail; % total advance capacity
z_m = (1/3) * z_tot; % advance capacity mRNA
z_o = (2/3) * z_tot; % advance capacity traditional

cap_costs_arr = zeros(periods_tot, 1); % array of costs
cap_costs_arr(1) = (params.k_m * z_m + params.k_o * z_o) / 10^9; % costs to install advance capacity in year 1, in bn
cap_costs_arr(2:(periods_tot)) = (1-params.alpha) * params.delta * cap_costs_arr(1); % subsequent years, incur depreciation minus rental income
cap_costs_arr_PV = PV_factor .* cap_costs_arr;

%%%%%%%%%% BENEFITS %%%%%%%%%%

ML_arr = zeros(periods_tot, 1); % mortality lossses
OL_arr = zeros(periods_tot, 1); % output losses

for t = yr_start:periods_tot % start counting losses from yr of pandemic start, but assume losses grow from base year 0
    ML_arr(t) = ((1+params.y)^t) .* (params.value_of_death * params.P0 / 1000) * intensity;

    OL_arr(t) = ((1+params.y)^t) .* (params.Y0 * params.P0 / 100) * exp(0.7393) * (intensity^0.4561);
end

LL_arr = (10/13.8) .* OL_arr; 
TL_arr = ML_arr + OL_arr + LL_arr; 

TL_PV_arr = PV_factor .* TL_arr;

yr_end = yr_start + pandemic_natural_dur;
pv_tln_sim = sum(TL_PV_arr(yr_start:yr_end), 1);
pv_tln_sim_bn = pv_tln_sim/10^9;

% if enters pandemic, suppose lasts for T months
assert((params.T/12) <= pandemic_natural_dur+1);

[h_sum, vax_fraction_sum] = h_integral(params, state);
vax_benefits_bn = params.gamma * pv_tln_sim_bn * h_sum / 12; % h_sum is in months, so need to divide by 12

%%%%%%%%%% COSTS %%%%%%%%%%
in_pandemic_cap_costs = capital_costs(x_m-z_m, params, 1) + capital_costs(x_o-z_o, params, 0); % costs to install needed capacity during pandemic

marginal_cost_m = 0;
marginal_cost_o = 0;
if state == 1 % states where both mRNA and traditional are succesful and marginal costs for both are incurred
    total_courses = params.P0 * vax_fraction_sum;
    mRNA_courses = params.f_m * x_m/12 * max(params.T - params.tau_A, 0) ...
        + params.g_m * x_m/12 * max(params.T - params.tau_A - params.tau_m, 0);
    traditional_courses = total_courses - mRNA_courses;

    marginal_cost_m = params.c_m * mRNA_courses;
    marginal_cost_o = params.c_o * traditional_courses;
end

if state == 2 % only mRNA successful
    marginal_cost_m = params.c_m * (vax_fraction_sum * params.P0);
end

if state == 3 % only traditional is successful
    marginal_cost_o = params.c_o * (vax_fraction_sum * params.P0);
end

in_pandemic_costs = (in_pandemic_cap_costs + marginal_cost_o + marginal_cost_m) / 10^9; % costs in annualized terms (in bn)
in_pandemic_costs_PV = 1/((1+params.r)^yr_start) * in_pandemic_costs;

vax_costs_bn = sum(cap_costs_arr_PV(1:yr_end), 1) + in_pandemic_costs_PV;
vax_net_benefits_bn = vax_benefits_bn - vax_costs_bn




