
draw_lower = 0.867; % this is the cumulative prob for mu \leq 10^{-3} 
draw_upper = 0.9994; % if the uniform draw exceeds this, cannot invert (set to mu_prime_prime)
periods = 200;
sim_cnt = 1000;
save_output = 0;
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

vax_net_benefits_bn_arr = zeros(sim_cnt, 1); % array of net benefits for the simulations
vax_costs_bn_arr = zeros(sim_cnt, 1); % array of costs
vax_benefits_bn_arr = zeros(sim_cnt, 1); % array of benefits

yr_start_arr = zeros(sim_cnt, 1); % array of start yr of pandemic
intensity_arr = zeros(sim_cnt, 1); % array of pandemic intensities (assumed to be intensity associated with start yr)
state_arr = zeros(sim_cnt, 1); % array of state of production
vax_fraction_sum_arr = zeros(sim_cnt, 1); % array of fraction of pop vaccinated

time_arr = (1:periods_tot)';
PV_factor = (1+params.r).^(-time_arr); % array of discount factors
i0 = [mu, mu_prime_prime];

for s = 1:sim_cnt

    r = unifrnd(0, 1, periods, 1); % array of uniform random variables for the periods
    i_arr = zeros(periods, 1); % array of intensities (inverted from the uniform variables)
    for t = 1:periods
        val = r(t);

        if val <= draw_lower
            i = mu;
        elseif val >= draw_upper
            i = mu_prime_prime;
        else
    %         fprintf('%d \n', val)
            fun = @(i) f_cum(i, alpha,mu,sigma,xi,w,ones,twos,threes,fours,fives)- val;
            i = fzero(fun, i0);
        end

        i_arr(t) = i;
    end

    ind = i_arr > params.i_star;
    yr_start = find(ind,1,'first');
    if isempty(yr_start)
        yr_start = NaN; % no pandemic of at least intensity i_star in this simulation
    end
    yr_start_arr(s) = yr_start;

    
    %%%%%%%%%% Costs -- certain %%%%%%%%%%

    x_tot = params.x_target;
    x_m = (1/3) * x_tot; % total capacity mRNA
    x_o = (2/3) * x_tot; % total capacity traditional

    z_tot = params.x_target - (1-params.theta) * params.x_avail; % total advance capacity
    z_m = (1/3) * z_tot; % advance capacity mRNA
    z_o = (2/3) * z_tot; % advance capacity traditional

    cap_costs_arr = zeros(periods_tot, 1); % array of costs
    cap_costs_arr(1) = (params.k_m * z_m + params.k_o * z_o) / 10^9; % costs to install advance capacity in year 1, in bn
    cap_costs_arr(2:(periods+1)) = (1-params.alpha) * params.delta * cap_costs_arr(1); % subsequent years, incur depreciation minus rental income
    cap_costs_arr_PV = PV_factor .* cap_costs_arr;

    if ~isnan(yr_start) % has a pandemic of significant size

        % [0, 0.5) both technologies successful (state = 1)
        % [0.5, 0.65) only mRNA successful (state = 2)
        % [0.65, 0.8) only traditional successful (state = 3)
        % [0.8, 1] nothing is successful (state = 4)

        draw = rand();
        
        if draw < 0.5
            state = 1;
        elseif draw < 0.65
            state = 2;
        elseif draw < 0.8
            state = 3;
        else
            state = 4;
        end
        state_arr(s) = state;

        %%%%%%%%%% BENEFITS %%%%%%%%%%
        intensity = i_arr(yr_start);
        intensity_arr(s) = intensity;

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
        vax_benefits_bn_arr(s) = vax_benefits_bn;
        vax_fraction_sum_arr(s) = vax_fraction_sum;

        %%%%%%%%%% COSTS %%%%%%%%%%
        
        % costs to install needed capacity during pandemic, assume this is
        % done at risk within a pandemic (occurs even when no vaccine is
        % successful
        in_pandemic_cap_costs = capital_costs(x_m-z_m, params, 1) + capital_costs(x_o-z_o, params, 0);

        marginal_cost_m = 0;
        marginal_cost_o = 0;
        if state == 1 % states where both mRNA and traditional are succesful and marginal costs for both are incurred
            total_courses = params.P0 * vax_fraction_sum;
            mRNA_courses = params.f_m * x_m/12 * max(params.T - params.tau_A, 0) ...
                + params.g_m * x_m/12 * max(params.T - params.tau_A - params.tau_m, 0);
            traditional_courses = total_courses - mRNA_courses;
            assert(traditional_courses>0)
            
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

    else
        % if no pandemic, then benefits and in pandemic costs are zero 
        pv_tln_sim_bn = 0;
        vax_benefits_bn = 0;

        in_pandemic_costs_PV = 0;

        intensity_arr(s) = NaN;
        state_arr(s) = NaN;
        vax_fraction_sum_arr(s) = NaN;

        yr_end = periods;

    end
    vax_benefits_bn_arr(s) = vax_benefits_bn;
    
    vax_costs_bn = sum(cap_costs_arr_PV(1:yr_end), 1) + in_pandemic_costs_PV;
    vax_costs_bn_arr(s) = vax_costs_bn;

    vax_net_benefits_bn = vax_benefits_bn - vax_costs_bn;
    vax_net_benefits_bn_arr(s) = vax_benefits_bn - vax_costs_bn;
end

sim_results = table(vax_net_benefits_bn_arr, vax_benefits_bn_arr, vax_costs_bn_arr, ...
    yr_start_arr, intensity_arr, state_arr, vax_fraction_sum_arr);

sim_results.state_desc = repmat({""}, size(sim_results,1), 1);
sim_results.state_desc(sim_results.state_arr==1) = {"both"};
sim_results.state_desc(sim_results.state_arr==2) = {"mRNA_only"};
sim_results.state_desc(sim_results.state_arr==3) = {"trad_only"};
sim_results.state_desc(sim_results.state_arr==4) = {"none"};
sim_results.state_desc(isnan(sim_results.state_arr)) = {"no_pandemic"};

mean(vax_net_benefits_bn_arr, 1)

if save_output == 1
    writetable(sim_results,'sim_results.xlsx','Sheet',1)
end




