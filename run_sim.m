function [vax_benefits_arr, vax_fraction_cum_end, PV_factor, in_pandemic_cap_costs_PV, in_pandemic_marg_costs_m_PV, in_pandemic_marg_costs_o_PV] = run_sim(params, yr_start, ...
	pandemic_natural_dur, state, intensity, x_m, x_o, z_m, z_o)

	% run simulation for a pandemic of significant size
		    
        tot_months = pandemic_natural_dur * 12; % total months of pandemic

		cap_m_arr = zeros(tot_months, 1); % vector of monthly production capacity for mRNA platform, in million
        cap_o_arr = zeros(tot_months, 1); % vector of monthly production capacity for traditional platform, in million
        for tau = 1:tot_months
            [~, x_arr] = production_capacity(tau, params, state, x_m/12, x_o/12);
            cap_m_arr(tau) = x_arr(1);
            cap_o_arr(tau) = x_arr(2);
        end

        % discount factor & growth rate
		PV_factor = zeros(tot_months, 1);
		growth_rate = zeros(tot_months, 1);

		% Calculate growth rate and pv factor
		for tau = 1:tot_months % allocate loss evenly across months in yr, these are gross amounts
		    growth_rate(tau) = (1+params.y)^(yr_start-1) * (1+params.y)^(1/12 * tau);
		    PV_factor(tau) = (1/(1+params.r))^(yr_start-1) * (1/(1+params.r))^(1/12 * tau);
		end

        %%%%%%%%%% BENEFITS %%%%%%%%%%

        ML_arr = (params.value_of_death * params.P0 / 1000) * intensity ./ 12 ./ 10^6; % mortality lossses for during pandemic (monthly, in million)
        OL_arr = (params.Y0 * params.P0 / 100) * exp(0.7393) * (intensity^0.4561) ./ 12 ./ 10^6; % output losses for during pandemic (monthly, in million)
        
        LL_arr = (10/13.8) * OL_arr; 
        TL_arr = ML_arr + OL_arr + LL_arr; % in million
        TL_PV_arr = PV_factor .* growth_rate .* TL_arr; % pv of cashflows, in million
        
        [h_arr, vax_fraction_cum] = h_integral(params, tot_months, cap_m_arr, cap_o_arr);

        vax_benefits_arr = params.gamma .* h_arr .* TL_PV_arr; % in million
        vax_fraction_cum_end = vax_fraction_cum(end);

        %%%%%%%%%% COSTS %%%%%%%%%%
        
        % costs to install needed capacity during pandemic, assume this is
        % done at risk within a pandemic (occurs even when no vaccine is
        % successful) and in the first month of pandemic
        in_pandemic_cap_costs = zeros(tot_months, 1);
        in_pandemic_cap_costs(1) = capital_costs(x_m-z_m, params, 1) + capital_costs(x_o-z_o, params, 0); % in million

        in_pandemic_cap_costs_PV = PV_factor .* in_pandemic_cap_costs; % in million

        in_pandemic_marg_costs_m = params.c_m .* cap_m_arr; % in million
        in_pandemic_marg_costs_o = params.c_o .* cap_o_arr; % in million

        in_pandemic_marg_costs_m_PV = PV_factor .* in_pandemic_marg_costs_m;
        in_pandemic_marg_costs_o_PV = PV_factor .* in_pandemic_marg_costs_o;

	end