function [vax_fraction_cum_end, vax_benefits_PV, vax_benefits_nom, inp_marg_costs_m_PV, inp_marg_costs_o_PV, inp_marg_costs_m_nom, inp_marg_costs_o_nom] = ...
    run_pandemic(params, econ_loss_model, tau_A, RD_benefit, yr_start, pandemic_natural_dur, actual_dur, rd_state, severity, cap_avail_m, cap_avail_o)

	% run simulation for a pandemic of significant size (not false pos)

    if RD_benefit == 1
        tau_A = tau_A - params.RD_speedup_months;
    end

    monthly_intensity = severity / (pandemic_natural_dur * 12);
    monthly_econ_loss = econ_loss_model.predict(severity) ./ (pandemic_natural_dur * 12); % total months of pandemic
    actual_dur_months = actual_dur * 12;

	cap_m_arr = zeros(actual_dur_months, 1); % vector of monthly production capacity for mRNA platform, in million
    cap_o_arr = zeros(actual_dur_months, 1); % vector of monthly production capacity for traditional platform, in million
    
    for tau = 1:actual_dur_months
        [~, x_arr] = production_capacity(tau, tau_A, params, rd_state, cap_avail_m/12, cap_avail_o/12);
        cap_m_arr(tau) = x_arr(1);
        cap_o_arr(tau) = x_arr(2);
    end

    % discount factor & growth rate
	PV_factor = zeros(actual_dur_months, 1);
	growth_rate = zeros(actual_dur_months, 1);

	% Calculate growth rate and pv factor
	for tau = 1:actual_dur_months % allocate loss evenly across months in yr, these are gross amounts
	    growth_rate(tau) = (1+params.y)^(yr_start-1) * (1+params.y)^(1/12 * tau);
	    PV_factor(tau) = (1/(1+params.r))^(yr_start-1) * (1/(1+params.r))^(1/12 * tau);
	end

    %%%%%%%%%% BENEFITS %%%%%%%%%%
    
    % Need to check that these formulas are correct.
    ML = (params.value_of_death * params.P0 / 1000) * monthly_intensity ./ 10^6; % mortality lossses for during pandemic (monthly, in million)
    % Update output losses to be estimated on severity
    OL = (params.Y0 .* params.P0 / 100) .* monthly_econ_loss ./ 10^6; % output losses for during pandemic (monthly, in million)

    LL = (10/13.8) .* OL; 
    TL = ML + OL + LL; % in million
    
    [h_arr, vax_fraction_cum] = h_integral(params, actual_dur_months, cap_m_arr, cap_o_arr);

    vax_benefits_nom = params.gamma .* h_arr .* growth_rate .* TL; % in million
    vax_benefits_PV = vax_benefits_nom .* PV_factor; % in million

    vax_fraction_cum_end = vax_fraction_cum(end);

    %%%%%%%%%% COSTS %%%%%%%%%%
    
    % marginal costs
    inp_marg_costs_m_nom = params.c_m .* cap_m_arr; % in million
    inp_marg_costs_m_PV = PV_factor .* inp_marg_costs_m_nom; % in million
    
    inp_marg_costs_o_nom = params.c_o .* cap_o_arr;
    inp_marg_costs_o_PV = PV_factor .* inp_marg_costs_o_nom; % in million

end