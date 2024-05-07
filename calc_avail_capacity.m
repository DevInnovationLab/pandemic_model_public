function [cap_costs_arr_PV, cap_costs_arr_nom, cap_avail_m, cap_avail_o] = calc_avail_capacity(yr_start, prep_start_month, params, x_m, z_m, x_o, z_o, i)

    cap_build_m = min(x_m - z_m, params.x_avail / 10^6 * params.mRNA_share);
    assert(cap_build_m >= 0); % never negative bc x_m >= z_m
    cap_build_o = min(x_o - z_o, params.x_avail / 10^6 * (1-params.mRNA_share));
    assert(cap_build_o >= 0); % never negative bc x_o >= z_o

    in_pandemic_cap_costs = capital_costs(cap_build_m, params, 1, 0) + capital_costs(cap_build_o, params, 0, 0); % in millions of nominal
    
    pv = 1;
    cap_costs_arr_PV = calc_adv_capacity_costs(params, yr_start, prep_start_month, in_pandemic_cap_costs, pv, params.capacity_kept); % add in-pandemic capacity cost to cap cost series

    pv = 0;
    cap_costs_arr_nom = calc_adv_capacity_costs(params, yr_start, prep_start_month, in_pandemic_cap_costs, pv, params.capacity_kept); % add in-pandemic capacity cost to cap cost series

    cap_avail_m = z_m + cap_build_m;
    cap_avail_o = z_o + cap_build_o;
    
end