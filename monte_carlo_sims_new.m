function monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, has_false_pos)

    save_output = 1;

    %%%%%%%%%%%%%%%% PARAMETERS

    params = params_default; % main source of params

    % user parameters override defaults
    if ~isempty(params_user)
        fn = fieldnames(params_user);
        for k=1:numel(fn)
            params.(fn{k}) = params_user.(fn{k});
        end
    end

    %%%%%%% LOAD SCENS

    scen_file_name = sprintf('sim_scens_has_false_%d.xlsx', has_false_pos); % this file is made by gen_sim_scens.m
    % scen_file_name = sprintf('sim_scens_test.xlsx'); % this file is made by gen_sim_scens.m
    sim_scens0 = readtable(scen_file_name,'Sheet','Sheet1');

    %%%%%%% FINISH SCEN CONSTRUCTION

    % construct state and pandemic duration, which can potentially change based on knobs turned

    sim_scens = finish_gen_sim_scens(sim_scens0, params); % adds state and natural_dur columns

    %%%%%%%%%%%%%%%% INITIALIZATION

    sim_cnt = sim_scens.sim_num(end); % number of simulations

    vax_net_benefits_bn_arr = zeros(sim_cnt, 1); % array of net benefits for the simulations
    vax_costs_bn_arr = zeros(sim_cnt, 1); % array of costs
    vax_benefits_bn_arr = zeros(sim_cnt, 1); % array of benefits

    sim_results = array2table(double.empty(0,16), 'VariableNames', {'sim_num', 'yr_start', 'intensity', 'is_false', 'RD_score', 'draw_state', 'draw_natural_dur', 'state', 'natural_dur', 'state_desc', ...
        'cap_avail_m', 'cap_avail_o', 'vax_benefits', 'vax_fraction_cum', 'in_pandemic_marg_costs', 'in_pandemic_fill_finish_costs'} );

    %%%%%%%%%% Costs -- certain (advance capacity and depreciation) %%%%%%%%%%

    [x_m, x_o] = get_target_capacity(params); % get target capacity

    tic;

    cluster = parcluster;
    parfor (s = 1:sim_cnt, cluster) % loop through each simulation scenario
%     for s = 1:sim_cnt % loop through each simulation scenario

        idx = sim_scens.sim_num == s; % indices of rows for sim s
        row_cnt = sum(idx>0);
        sim_scens_s = sim_scens(idx, :);

        yr_start_arr = sim_scens_s.yr_start;
        intensity_arr = sim_scens_s.intensity;
        natural_dur_arr = sim_scens_s.natural_dur;
        is_false_arr = sim_scens_s.is_false;
        state_arr = sim_scens_s.state;
        RD_score_arr = sim_scens_s.RD_score;

        if params.has_user_cap_setting == 1
            z_m = params.user_z_m;
            z_o = params.user_z_o;
            nom_cost_adv = (params.k_m * (1-params.fill_finish_pct) * z_m + params.k_o * (1-params.fill_finish_pct) * z_o) / 10^6; % costs to install advance capacity in year 1, in million
        else
            if has_full_adv_cap == 1
                [z_m, z_o] = get_adv_capacity(params); % get advanced capacity
                nom_cost_adv = (params.k_m * (1-params.fill_finish_pct) * z_m + params.k_o * (1-params.fill_finish_pct) * z_o) / 10^6; % costs to install advance capacity in year 1, in million
            else
                z_m = 0;
                z_o = 0;
                nom_cost_adv = 0; % no cost if no advanced program
            end
        end
        
        yr_adv = 1; % yr advance capacity cost, if any, incurred
        cap_costs_arr_PV = calc_adv_capacity_costs(params, yr_adv, nom_cost_adv); % in million
        
        in_pandemic_marg_costs_PV = 0; % add up in pv bc there is monthly discounting inside a pandemic (hard to carry this around in time series, unlike capacity)
        vax_benefits = 0;
        in_pandemic_fill_finish_costs_PV_tot = 0;

        if row_cnt == 1 && isnan(yr_start_arr(1))
            % if no pandemic in this simulation, then benefits and in pandemic costs are zero 
            vax_benefits_bn = 0;
            vax_costs_in_pandemic_bn = 0;

            res = sim_scens_s(1, :);
            res.cap_avail_m = z_m / 10^9; % billion of units of annual capacity
            res.cap_avail_o = z_o / 10^9; % billion of units of annual capacity
            res.vax_benefits = 0;
            res.vax_fraction_cum = NaN;
            res.in_pandemic_marg_costs = 0;
            res.in_pandemic_fill_finish_costs = 0;

            sim_results = [sim_results; res];

        else
            for i = 1:row_cnt % for pandemic i in sim s
                yr_start = yr_start_arr(i);
                pandemic_natural_dur = natural_dur_arr(i);
                state = state_arr(i);
                intensity = intensity_arr(i);
                is_false = is_false_arr(i);
                
                RD_benefit = 0; % if has R&D benefit
                if params.has_RD == 1
                    RD_score = RD_score_arr(i);
                    if RD_score >= params.RD_success_rate
                        RD_benefit = 1;
                    end
                end

                % costs to install needed capacity during pandemic, assume this is
                % done at risk within a pandemic (occurs even when no vaccine is
                % successful and is a false positive) and in the first month of pandemic
                
                if has_full_adv_cap == 1 % all capacity is "advanced" after the first pandemic
                    
                    if i == 1 % first pandemic
                        cap_build_m = x_m - z_m;
                        cap_build_o = x_o - z_o;
                    else
                        % with full adv program, after the first pandemic, will have no more need to build
                        cap_build_m = 0;
                        cap_build_o = 0;
                    end

                    in_pandemic_cap_costs = capital_costs(cap_build_m, params, 1) + capital_costs(cap_build_o, params, 0); % in million of nominal
                    cap_costs_arr_PV = cap_costs_arr_PV + calc_adv_capacity_costs(params, yr_start-1, in_pandemic_cap_costs); % add in-pandemic capacity cost to cap cost series

                    cap_avail_m = x_m; % capacity avail for this pandemic
                    cap_avail_o = x_o; % capacity avail for this pandemic

                    z_m = x_m; % advanced capacity for future pandemics
                    z_o = x_m; % advanced capacity for future pandemics
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

                    in_pandemic_cap_costs = capital_costs(cap_build_m, params, 1) + capital_costs(cap_build_o, params, 0); % in million
                    cap_costs_arr_PV = cap_costs_arr_PV + calc_adv_capacity_costs(params, yr_start-1, in_pandemic_cap_costs); % add in-pandemic capacity cost to cap cost series

                    cap_avail_m = z_m + cap_build_m;
                    cap_avail_o = z_o + cap_build_o;
                    
                    z_m = cap_avail_m; % advanced capacity for future pandemics
                    z_o = cap_avail_o; % advanced capacity for future pandemics
                end
                
                [vax_benefits_arr, vax_fraction_cum, in_pandemic_marg_costs_m_PV, in_pandemic_marg_costs_o_PV, in_pandemic_fill_finish_costs_PV] = ...
                    run_pandemic(params, RD_benefit, yr_start, is_false, pandemic_natural_dur, state, intensity, cap_avail_m, cap_avail_o);

                in_pandemic_marg_costs_PV = in_pandemic_marg_costs_PV + sum(in_pandemic_marg_costs_m_PV, 1) + sum(in_pandemic_marg_costs_o_PV, 1); % total in pandemic costs, in million

                in_pandemic_fill_finish_costs_PV_tot = in_pandemic_fill_finish_costs_PV_tot + sum(in_pandemic_fill_finish_costs_PV, 1); % total in pandemic fill and finish costs, in million

                % add up capital cost accrued prior to pandemic start, and in-pandemic costs
                
                vax_benefits = vax_benefits + sum(vax_benefits_arr, 1); 

                res = sim_scens_s(i, :);
                res.cap_avail_m = cap_avail_m / 10^9; % billion of units of annual capacity
                res.cap_avail_o = cap_avail_o / 10^9; % billion of units of annual capacity
                res.vax_benefits = sum(vax_benefits_arr, 1) / 10^3;
                res.vax_fraction_cum = vax_fraction_cum;
                res.in_pandemic_marg_costs = (sum(in_pandemic_marg_costs_m_PV, 1) + sum(in_pandemic_marg_costs_o_PV, 1)) / 10^3;
                res.in_pandemic_fill_finish_costs = sum(in_pandemic_fill_finish_costs_PV, 1) / 10^3; 

                sim_results = [sim_results; res];

            end

            vax_costs_in_pandemic_bn = (in_pandemic_marg_costs_PV + in_pandemic_fill_finish_costs_PV_tot) / 10^3;
            vax_benefits_bn = vax_benefits / 10^3;
        end

        vax_costs_bn = vax_costs_in_pandemic_bn + (sum(cap_costs_arr_PV, 1))/10^3;
        
        if params.has_RD == 1
            vax_costs_bn = vax_costs_bn + params.RD_spend;
        end

        vax_net_benefits_bn = vax_benefits_bn - vax_costs_bn;

        % store sim results
        vax_benefits_bn_arr(s) = vax_benefits_bn;
        vax_costs_bn_arr(s) = vax_costs_bn;
        vax_net_benefits_bn_arr(s) = vax_net_benefits_bn;

        if mod(s, 1000) == 0
%             fprintf('finished sim num %d (elaspsed min: %d)\n', s, round(toc/60, 1));
            fprintf('finished sim num %d\n', s);
        end
    end
    fprintf('elapsed time (min): %0.1f\n', round(toc/60, 1));

    sim_results_sum = table(vax_net_benefits_bn_arr, vax_benefits_bn_arr, vax_costs_bn_arr);
    sim_results_sum.sim_num = (1:sim_cnt)';

    mean(vax_net_benefits_bn_arr, 1)

    if save_output == 1
        
        if isempty(outfile_label)
            out_filename_sum = 'sim_results_sum.xlsx';
            out_filename = 'sim_results.xlsx';
        else
            out_filename_sum = sprintf('sim_results_%s_sum.xlsx', outfile_label);
            out_filename = sprintf('sim_results_%s.xlsx', outfile_label);
        end
        
        delete(out_filename_sum);
        writetable(sim_results_sum, out_filename_sum, 'Sheet', 1);
        fprintf('printed summary output to %s\n', out_filename_sum);

        delete(out_filename);
        writetable(sim_results, out_filename, 'Sheet', 1)
        fprintf('printed output to %s\n', out_filename);
    end
end