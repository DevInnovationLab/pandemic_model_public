function [vax_fraction_cum_end, vax_benefits_PV, vax_benefits_nom, inp_marg_costs_m_PV, inp_marg_costs_o_PV, inp_marg_costs_m_nom, inp_marg_costs_o_nom] = ...
    run_pandemic(params, econ_loss_model, tau_A, RD_benefit, yr_start, pandemic_natural_dur, actual_dur, rd_state, severity, cap_avail_m, cap_avail_o)

	% run simulation for a pandemic of significant size (not false pos)

    if RD_benefit == 1
        tau_A = tau_A - params.RD_speedup_months;
    end

    monthly_intensity = severity / (pandemic_natural_dur * 12);
    monthly_econ_loss = econ_loss_model.predict(severity) ./ (pandemic_natural_dur * 12); % total months of pandemic
    actual_dur_months = actual_dur * 12;

    % Get effective capacity over time during pandemic
    months_arr = (1:actual_dur_months)';
    [ind_m, ind_o] = get_capacity_indicators(rd_state);
    monthly_capacity = get_pandemic_capacity(months_arr, tau_A, params, ind_m, ind_o, cap_avail_m/12, cap_avail_o/12);

	% Get vaccination and damage mitigation over time.
    vax_fractions_per_period = monthly_capacity.total * 10^6 / params.P0; % Don't you need two doses?
    vax_fractions_cum = cumsum(vax_fractions_per_period);
    vax_fractions_cum(vax_fractions_cum > 1) = 1; % Can't vaccinate more than population
    if params.conservative == 1 % Use beginning of period vaccinations (rather than end of period)
        vax_fractions_cum = [0; vax_fractions_cum(1:end-1)];
    end

    h_arr = h(vax_fractions_cum);

	% Calculate growth rate and pv factor
    growth_rate = (1+params.y)^(yr_start-1) .* (1+params.y).^(1/12 .* months_arr);
    PV_factor = (1/(1+params.r))^(yr_start-1) .* (1/(1+params.r)).^(1/12 .* months_arr);

    %%%%%%%%%% BENEFITS %%%%%%%%%%
    ML = (params.value_of_death .* params.P0 / 10000) .* monthly_intensity ./ 10^6; % mortality lossses for during pandemic (monthly, in million)
    OL = (params.Y0 .* params.P0 / 100) .* monthly_econ_loss ./ 10^6; % output losses for during pandemic (monthly, in million)
    LL = (10/13.8) .* OL; 
    TL = ML + OL + LL; % in million
    % We should get these as separate streams.

    vax_benefits_nom = params.gamma .* h_arr .* growth_rate .* TL; % in million
    vax_benefits_PV = vax_benefits_nom .* PV_factor; % in million
    vax_fraction_cum_end = vax_fractions_cum(end);

    %%%%%%%%%% COSTS %%%%%%%%%%
    
    % marginal costs
    inp_marg_costs_m_nom = params.c_m .* monthly_capacity.mrna; % in million
    inp_marg_costs_m_PV = PV_factor .* inp_marg_costs_m_nom; % in million
    
    inp_marg_costs_o_nom = params.c_o .* monthly_capacity.trad;
    inp_marg_costs_o_PV = PV_factor .* inp_marg_costs_o_nom; % in million

end


function [ind_m, ind_o] = get_capacity_indicators(rd_state)
    % Get indicators for usable capacity types depending on which vaccine platforms succeeded.
    if rd_state == 1 % both successful
        ind_m = 1;
		ind_o = 1;
    elseif rd_state == 2 % only mRNA successful
        ind_m = 1;
		ind_o = 0;
    elseif rd_state == 3 % only traditional successful
        ind_m = 0;
		ind_o = 1;
    else % nothing is successful
        assert(rd_state == 4);
        ind_m = 0;
		ind_o = 0;
    end
end