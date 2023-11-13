function [vax_fraction_cum_end, vax_benefits_PV, in_pandemic_marg_costs_m_PV, in_pandemic_marg_costs_o_PV, in_pandemic_tailoring_costs_PV] = ...
    run_pandemic(params, RD_benefit, yr_start, is_false, pandemic_natural_dur, state, intensity, cap_avail_m, cap_avail_o)

	% run simulation for a pandemic of significant size

    if RD_benefit == 1
        tau_A = params.tau_A - params.RD_impact_time;
    else
        tau_A = params.tau_A;
    end

	if is_false == 1
        tot_months = tau_A; % if is false pos, then will find out by end of tau_A (~100 day period)
    else
        tot_months = pandemic_natural_dur * 12; % total months of pandemic
    end

	cap_m_arr = zeros(tot_months, 1); % vector of monthly production capacity for mRNA platform, in million
    cap_o_arr = zeros(tot_months, 1); % vector of monthly production capacity for traditional platform, in million
    
    if ~is_false
        for tau = 1:tot_months
            [~, x_arr] = production_capacity(tau, tau_A, params, state, cap_avail_m/12, cap_avail_o/12);
            cap_m_arr(tau) = x_arr(1);
            cap_o_arr(tau) = x_arr(2);
        end
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

    if is_false == 1 % if is false positive, then no benefits / no vaccination
        vax_benefits_PV = zeros(tot_months, 1);
        vax_fraction_cum_end = NaN;
    else
        ML = (params.value_of_death * params.P0 / 1000) * intensity ./ 12 ./ 10^6; % mortality lossses for during pandemic (monthly, in million)
        OL = (params.Y0 * params.P0 / 100) * exp(0.7393) * (intensity^0.4561) ./ 12 ./ 10^6; % output losses for during pandemic (monthly, in million)
        
        if tot_months > 12 % rescale monthly harm so as to not blow up harm with pandemic duration (keep total harm constant at harm from a pandemic of 1 yr duration)
            ML = ML * 12 / tot_months; 
            OL = OL * 12 / tot_months;
        end

        LL = (10/13.8) * OL; 
        TL = ML + OL + LL; % in million
        TL_PV_arr = PV_factor .* growth_rate .* TL; % pv of cashflows, in million
        
        [h_arr, vax_fraction_cum] = h_integral(params, tot_months, cap_m_arr, cap_o_arr);

        vax_benefits_PV = params.gamma .* h_arr .* TL_PV_arr; % in million
        vax_fraction_cum_end = vax_fraction_cum(end);
    end

    %%%%%%%%%% COSTS %%%%%%%%%%
    
    % fill and finish incurred regardless of false pos
    in_pandemic_tailoring_costs = zeros(tot_months, 1);
    in_pandemic_tailoring_costs(1) = cap_avail_m * (params.tailoring_pct * params.k_m) + cap_avail_o * (params.tailoring_pct * params.k_o);
    in_pandemic_tailoring_costs_PV = PV_factor .* in_pandemic_tailoring_costs / 10^6; % in million

    if is_false == 1
        in_pandemic_marg_costs_m_PV = zeros(tot_months, 1);
        in_pandemic_marg_costs_o_PV = zeros(tot_months, 1);
    else
        in_pandemic_marg_costs_m_PV = PV_factor .* params.c_m .* cap_m_arr; % in million
        in_pandemic_marg_costs_o_PV = PV_factor .* params.c_o .* cap_o_arr; % in million
    end

end