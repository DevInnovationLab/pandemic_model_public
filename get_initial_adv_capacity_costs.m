function [z_m, z_o, nom_cost_adv] = get_initial_adv_capacity_costs(params, has_full_adv_cap)

    if params.has_user_cap_setting == 1 % user setting takes priority
        z_m = params.user_z_m;
        z_o = params.user_z_o;
        nom_cost_adv = capital_costs(z_m, params, 1, 1) + capital_costs(z_o, params, 0, 1); % costs to install advance capacity in year 1, in million
    else
        if has_full_adv_cap == 1
            [z_m, z_o] = get_adv_capacity(params); % get advanced capacity
            nom_cost_adv = capital_costs(z_m, params, 1, 1) + capital_costs(z_o, params, 0, 1); % costs to install advance capacity in year 1, in million
        else
            z_m = 0;
            z_o = 0;
            nom_cost_adv = 0; % no cost if no advanced program
        end
    end

end