%%%%%%%%%%% USER TOGGLES

has_adv_cap = 1; % if to build capacity in advance
save_output = 0;

%%%%%%%%%%%%%%%% PARAMETERS

params = params_default; % main source of params

%%%%%%% LOAD SCENS

scen_file_name = 'sim_scens.xlsx'; % this file is made by gen_sim_scens.m
sim_scens = readtable(scen_file_name,'Sheet','Sheet1');

yr_start_arr = sim_scens.yr_start_arr;
intensity_arr = sim_scens.intensity_arr;
natural_dur_arr = sim_scens.natural_dur_arr;

state_arr = sim_scens.state_arr;
state_desc = sim_scens.state_desc;

sz = size(sim_scens);
sim_cnt = sz(1); % number of simulations

%%%%%%%%%%%%%%%% INITIALIZATION

if save_output
    out_filename = sprintf('sim_results_adv_%d.xlsx', has_adv_cap);
end

vax_fraction_cum_arr = NaN(sim_cnt, 1); % array of fraction of pop vaccinated by end of eval period

vax_net_benefits_bn_arr = zeros(sim_cnt, 1); % array of net benefits for the simulations
vax_costs_bn_arr = zeros(sim_cnt, 1); % array of costs
vax_benefits_bn_arr = zeros(sim_cnt, 1); % array of benefits

%%%%%%%%%%%%%%%% MAIN

%%%%%%%%%% Costs -- certain (advance capacity and depreciation) %%%%%%%%%%

[x_m, x_o, z_m, z_o] = get_capacity(has_adv_cap, params);
cap_costs_arr_PV = calc_adv_capacity_costs(params, z_m, z_o); % in million

for s = 1:sim_cnt % loop through each simulation scenario

	yr_start = yr_start_arr(s);
    pandemic_natural_dur = natural_dur_arr(s);
    state = state_arr(s);
    intensity = intensity_arr(s);
    
    if ~isnan(yr_start)
        [vax_benefits_arr, vax_fraction_cum_end, PV_factor, in_pandemic_cap_costs_PV, in_pandemic_marg_costs_m_PV, in_pandemic_marg_costs_o_PV] = ...
            run_sim(params, yr_start, pandemic_natural_dur, state, intensity, x_m, x_o, z_m, z_o);

        in_pandemic_costs_PV_arr = in_pandemic_cap_costs_PV + in_pandemic_marg_costs_m_PV + in_pandemic_marg_costs_o_PV; % total in pandemic costs, in million

        % add up capital cost accrued prior to pandemic start, and in-pandemic costs
        vax_costs_bn = (sum(cap_costs_arr_PV(1:(yr_start-1)), 1) + sum(in_pandemic_costs_PV_arr, 1)) / 10^3;
        vax_benefits_bn = sum(vax_benefits_arr, 1) / 10^3; 

        vax_fraction_cum_arr(s) = vax_fraction_cum_end;
    else
        % if no pandemic, then benefits and in pandemic costs are zero 
        vax_benefits_bn = 0;
        vax_costs_bn = sum(cap_costs_arr_PV(1:params.sim_periods), 1) / 10^3;
    end
    
    vax_net_benefits_bn = vax_benefits_bn - vax_costs_bn;

    % store sim results
    vax_benefits_bn_arr(s) = vax_benefits_bn;
    vax_costs_bn_arr(s) = vax_costs_bn;
    vax_net_benefits_bn_arr(s) = vax_net_benefits_bn;

end

sim_results = table(vax_net_benefits_bn_arr, vax_benefits_bn_arr, vax_costs_bn_arr, ...
    yr_start_arr, intensity_arr, state_arr, vax_fraction_cum_arr, natural_dur_arr, state_desc);

mean(vax_net_benefits_bn_arr, 1)

if save_output == 1
    delete(out_filename);
    writetable(sim_results, out_filename,'Sheet',1)
    fprintf('printed output to %s\n', out_filename);
end