function [cap_costs_arr_PV, cap_avail_m, cap_avail_o] = calc_avail_capacity(yr_start, cap_costs_arr_PV_existing, params, has_full_adv_cap, x_m, z_m, x_o, z_o, i)

    if has_full_adv_cap == 1 % all capacity is "advanced" after the first pandemic
        
        if i == 1 % first pandemic
            cap_build_m = x_m - z_m;
            cap_build_o = x_o - z_o;
        else
            % with full adv program, after the first pandemic, will have no more need to build
            cap_build_m = 0;
            cap_build_o = 0;
        end

        in_pandemic_cap_costs = capital_costs(cap_build_m, params, 1, 0) + capital_costs(cap_build_o, params, 0, 0); % in million of nominal
        cap_costs_arr_PV = cap_costs_arr_PV_existing + calc_adv_capacity_costs(params, yr_start-1, in_pandemic_cap_costs, 1); % add in-pandemic capacity cost to cap cost series

        cap_avail_m = x_m; % capacity avail for this pandemic
        cap_avail_o = x_o; % capacity avail for this pandemic
    else

        % if there is no advanced program or less than full advanced program, then the capacity ratchets up over time (anything built previoulsy is kept/maintained)
        if z_m >= x_m
            cap_build_m = 0;
        else
            cap_build_m = min(x_m - z_m, params.x_avail * params.mRNA_share);
        end

        if z_o >= x_o
            cap_build_o = 0;
        else
            cap_build_o = min(x_o - z_o, params.x_avail * (1-params.mRNA_share));
        end

        in_pandemic_cap_costs = capital_costs(cap_build_m, params, 1, 0) + capital_costs(cap_build_o, params, 0, 0); % in million
        cap_costs_arr_PV = cap_costs_arr_PV_existing + calc_adv_capacity_costs(params, yr_start-1, in_pandemic_cap_costs, 1); % add in-pandemic capacity cost to cap cost series

        cap_avail_m = z_m + cap_build_m;
        cap_avail_o = z_o + cap_build_o;

    end

end