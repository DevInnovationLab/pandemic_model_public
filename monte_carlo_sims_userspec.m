%%%%%%%%%%% USER TOGGLES

has_adv_cap = 1; % if to build capacity in advance

yr_start = 118;
pandemic_natural_dur = 1;
state = 2;
intensity = 1.164258171;

%%%%%%%%%%%%%%%% PARAMETERS

params = params_default; % main source of params

%%%%%%%%%%%%%%%% MAIN

%%%%%%%%%% Costs -- certain (advance capacity and depreciation) %%%%%%%%%%

[x_m, x_o, z_m, z_o] = get_capacity(has_adv_cap, params);
cap_costs_arr_PV = calc_adv_capacity_costs(params, z_m, z_o); % in million

if ~isnan(yr_start)
    [vax_benefits_arr, vax_fraction_cum_end, PV_factor, in_pandemic_cap_costs_PV, in_pandemic_marg_costs_m_PV, in_pandemic_marg_costs_o_PV] = ...
        run_sim(params, yr_start, pandemic_natural_dur, state, intensity, x_m, x_o, z_m, z_o);

    in_pandemic_costs_PV_arr = in_pandemic_cap_costs_PV + in_pandemic_marg_costs_m_PV + in_pandemic_marg_costs_o_PV; % total in pandemic costs, in million

    % add up capital cost accrued prior to pandemic start, and in-pandemic costs
    vax_costs_bn = (sum(cap_costs_arr_PV(1:(yr_start-1)), 1) + sum(in_pandemic_costs_PV_arr, 1)) / 10^3;
    vax_benefits_bn = sum(vax_benefits_arr, 1) / 10^3;

else
    % if no pandemic, then benefits and in pandemic costs are zero 
    vax_benefits_bn = 0;
    vax_costs_bn = sum(cap_costs_arr_PV(1:params.sim_periods), 1) / 10^3;
end

vax_net_benefits_bn = vax_benefits_bn - vax_costs_bn;

    
