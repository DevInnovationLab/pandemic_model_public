function [net_value, gross_value, gross_costs] = monte_carlo_sims_new(params_user, outfile_label, has_false_pos, has_surveil, threshold_surveil_arr)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % NOTE:
    % In these codes, capacity units are in outright levels, whereas anything denominated
    % in dollars is calculated / passed in millions (save for the end, when we dump results out
    % for display, for which we put capacity and anything in dollars into bn of units)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    save_output = params_user.save_output;

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
    % scen_file_name = sprintf('sim_scens_has_false_%d.xlsx', has_false_pos); % this file is made by gen_sim_scens_new.m
    % sim_scens0 = readtable(scen_file_name,'Sheet','Sheet1');

    scen_file_name = sprintf('sim_scens_has_false_%d', has_false_pos);
    load(scen_file_name, 'sim_scens');
    sim_scens0 = sim_scens;
    clear sim_scens;

    sim_scens0.prep_start_month = run_surveillance(sim_scens0.posterior1, sim_scens0.posterior2, sim_scens0.is_false, has_surveil, threshold_surveil_arr);
    sim_scens = finish_gen_sim_scens(sim_scens0, params); % adds state, natural_dur and has_RD_benefit columns

    sim_scens = removevars(sim_scens, {'draw_state', 'draw_natural_dur', 'posterior1', 'posterior2'}); % remove the random draw columns
    %%%%%%%%%%%%%%%% INITIALIZATION %%%%%%%%%%%%%%%%

    sim_cnt = max(sim_scens.sim_num); % number of simulations

    vax_net_benefits_bn_arr   = zeros(sim_cnt, 1); % array of net benefits for the simulations
    vax_benefits_bn_arr       = zeros(sim_cnt, 1); % array of benefits
    vax_costs_bn_arr          = zeros(sim_cnt, 1); % array of costs
    
    vax_costs_inp_m_bn_arr   = zeros(sim_cnt, 1); % array of costs for in pandemic marginal costs
    vax_costs_inp_tailoring_bn_arr  = zeros(sim_cnt, 1); % array of costs for in pandemic fill & finish costs
    vax_costs_inp_RD_bn_arr  = zeros(sim_cnt, 1); % array of costs for in pandemic RD costs
    vax_costs_inp_cap_bn_arr = zeros(sim_cnt, 1); % array of costs for in pandemic at risk capacity investments
    vax_costs_upf_cap_bn_arr = zeros(sim_cnt, 1); % array of costs for adv capacity investments

    sim_results = array2table(double.empty(0, 18), 'VariableNames', {'sim_num', 'yr_start', 'intensity', 'is_false', 'pathogen_family', ...
        'prep_start_month', 'state', 'natural_dur', 'has_RD_benefit', 'state_desc', ...
        'cap_avail_m', 'cap_avail_o', 'vax_benefits', 'vax_fraction_cum', 'inp_marg_costs', 'inp_tailoring_costs', 'inp_RD_costs', 'inp_cap_costs'} );

    %%%%%%%%%%%%%%%% Initialize capacity %%%%%%%%%%%

    [x_m, x_o] = get_target_capacity(params); % get target capacity (in millions)
    [z_m0_arr, z_o0_arr, cap_costs_arr_PV0, cap_costs_arr_nom0] = get_initial_adv_capacity_costs(params); % in millions

    %%% costs - adv
    sim_out_arr_costs_adv_cap_nom       = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_adv_cap_PV        = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_adv_RD_nom        = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_adv_RD_PV         = zeros(sim_cnt, params.sim_periods);
    %%% costs - in-pandemic
    sim_out_arr_costs_inp_cap_nom       = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_inp_cap_PV        = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_inp_marg_nom      = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_inp_marg_PV       = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_inp_tailoring_nom = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_inp_tailoring_PV  = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_inp_RD_nom        = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_inp_RD_PV         = zeros(sim_cnt, params.sim_periods);
    
    %%% costs - surveillance (on-going)
    sim_out_arr_costs_surveil_nom = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_costs_surveil_PV = zeros(sim_cnt, params.sim_periods);
    surveil_spend_bn_PV = 0;
    
    if has_surveil == 1 
        time_arr = (1:params.sim_periods)';
        PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors
        surveil_spend_bn_arr = repmat(params.surveil_spend, params.sim_periods, 1);
        surveil_spend_bn_PV = sum(surveil_spend_bn_arr .* PV_factor_yr);

        sim_out_arr_costs_surveil_nom = repmat(params.surveil_spend * 1000, sim_cnt, params.sim_periods);
        sim_out_arr_costs_surveil_PV = sim_out_arr_costs_surveil_nom .* repmat(PV_factor_yr', sim_cnt, 1 );
    end
    
    %%% benefits
    sim_out_arr_benefits_vaccine_nom    = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_benefits_vaccine_PV     = zeros(sim_cnt, params.sim_periods);

    inp_RD_nom = params.RD_inp_noRD * 1000; % mn of nominal
    RD_spend_bn_PV = 0;
    if params.has_RD == 1 % figure out PV of the total spend, which is nominal and over RD_benefit_start years
        time_arr = (1:params.RD_benefit_start)';
        PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors
        
        RD_spend_bn_arr = repmat(params.RD_spend / params.RD_benefit_start, params.RD_benefit_start, 1);
        RD_spend_bn_PV = sum(RD_spend_bn_arr .* PV_factor_yr);

        RD_spend_bn_tbl = repmat(params.RD_spend / params.RD_benefit_start * 1000, sim_cnt, params.RD_benefit_start); % in millions (consistent with the fact that everthing in codes is in mn, and all time series are in mn as well)
        sim_out_arr_costs_adv_RD_nom(:, 1:params.RD_benefit_start) = RD_spend_bn_tbl;
        sim_out_arr_costs_adv_RD_PV(:, 1:params.RD_benefit_start) = RD_spend_bn_tbl .* repmat(PV_factor_yr', sim_cnt, 1 );

        inp_RD_nom = params.RD_inp_withRD * 1000; % mn of nominal
    end

    tic;
    fprintf('Starting simulations for scen %s ... \n', outfile_label);

    cluster = parcluster;
    parfor (s = 1:sim_cnt, cluster) % loop through each simulation scenario
%     for s =1:500

        idx         = sim_scens.sim_num == s; % indices of rowsinu for sim s
        row_cnt_s   = sum(idx>0); % number of rows for this simulation
        sim_scens_s = sim_scens(idx, :); % filter sim_scens for rows relevant for this simulation

        [yr_start_arr, intensity_arr, natural_dur_arr, is_false_arr, state_arr, has_RD_benefit_arr, prep_start_month_arr] = ...
            extract_columns_from_table(sim_scens_s); % unpack designated columns as arrays
        
        vax_benefits_s = 0; % total benefit in simulation (total across pandemics, in million)
        
        inp_cap_costs_PV_s = 0;
        inp_marg_costs_PV_s = 0; 
        inp_tailoring_costs_PV_s = 0;
        inp_RD_costs_PV_s = 0;

        if row_cnt_s == 1 && isnan(yr_start_arr(1)) %  no pandemic in this simulation (benefits and costs stay at their default of zero)
            
            z_m0 = z_m0_arr(end); % full amount of adv will have been built in this sim
            z_o0 = z_o0_arr(end); % full amount of adv will have been built in this sim

            z_m = z_m0;
            z_o = z_o0;
            
            cap_costs_arr_PV = cap_costs_arr_PV0(:, end);
            sim_out_arr_costs_adv_cap_nom(s, :) = (cap_costs_arr_nom0(:, end))';
            sim_out_arr_costs_adv_cap_PV(s, :) = (cap_costs_arr_PV0(:, end))';

            upfront_cap_costs = sum(cap_costs_arr_PV); % adv capacity cost (in million)
            cap_costs_arr_PV_cum = cap_costs_arr_PV;
            
            res = gen_output_struct(sim_scens_s(1, :), z_m/10^3, z_o/10^3, 0, NaN, 0, 0, 0, 0);
            sim_results = [sim_results; res];

        else

            indx = yr_start_arr(1)-1;
            if indx > params.adv_cap_build_period
                indx = params.adv_cap_build_period;
            end
            z_m0 = z_m0_arr(indx); % get adv capacity corresponding to end of year before first pandemic
            z_o0 = z_o0_arr(indx);

            z_m = z_m0;
            z_o = z_o0;
            
            cap_costs_arr_PV = cap_costs_arr_PV0(:, indx);
            sim_out_arr_costs_adv_cap_nom(s, :) = (cap_costs_arr_nom0(:, indx))';
            sim_out_arr_costs_adv_cap_PV(s, :) = (cap_costs_arr_PV0(:, indx))';

            upfront_cap_costs = sum(cap_costs_arr_PV); % adv capacity cost (in million)

            cap_costs_arr_PV_cum = cap_costs_arr_PV;
            for i = 1:row_cnt_s % for pandemic i in sim s
                % if i == 2
                %     blah = 1+1;
                % end
                yr_start             = yr_start_arr(i);
                pandemic_natural_dur = natural_dur_arr(i);
                state                = state_arr(i);
                intensity            = intensity_arr(i);
                is_false             = is_false_arr(i);
                has_RD_benefit       = has_RD_benefit_arr(i);
                prep_start_month     = prep_start_month_arr(i); % interpret prep_start_month as the month where by the end of it, world starts preparing
                
                if isnan(prep_start_month) % correctly anticipated false pos, no wastage, no benefits (nothing needs to be done in codes, just add a row to output)
                    res = gen_output_struct(sim_scens_s(i, :), z_m/10^3, z_o/10^3, 0, NaN, 0, 0, 0, 0);

                    assert(z_m >= z_m0)
                    assert(z_o >= z_o0)

                    z_m = z_m0 + (z_m-z_m0) * params.capacity_kept; % update advanced capacity for future pandemics
                    z_o = z_o0 + (z_o-z_o0) * params.capacity_kept; % update advanced capacity for future pandemics
                else 
                    tau_A = params.tau_A;

                    if ~is_false
                        tau_A = params.tau_A + prep_start_month; % in a real pandemic, when a vaccine is available depends on when you started
                        % assert(tau_A < (pandemic_natural_dur * 12)) % sanity check, nothing interesting if it takes longer to prepare than the pandemic length 
                    end

                    %%% Case 1: false pos and decided to act -- wastage through tau_A
                    %%% Case 2: real pandemic and decided to act -- saved time
                    %%% Case 3: real pandemic and didn't decide to act -- no saved time
                    %%% (Case 2 and 3 are reflected in a longer tau_A)

                    % capacity costs should be incurred at one month into prep start
                    [cap_costs_arr_PV, cap_costs_arr_nom, cap_avail_m, cap_avail_o] = calc_avail_capacity(yr_start, prep_start_month, params, x_m, z_m, x_o, z_o, i); 

                    inp_cap_costs_PV = sum(cap_costs_arr_PV, 1);
                    inp_cap_costs_PV_s = inp_cap_costs_PV_s + inp_cap_costs_PV;

                    cap_costs_arr_PV_cum = cap_costs_arr_PV_cum + cap_costs_arr_PV;

                    sim_out_arr_costs_inp_cap_nom(s, :) = sim_out_arr_costs_inp_cap_nom(s, :) + cap_costs_arr_nom';
                    sim_out_arr_costs_inp_cap_PV(s, :) = sim_out_arr_costs_inp_cap_PV(s, :) + cap_costs_arr_PV';
                    
                    % fill and finish incurred at one month into prep start 
                    tailoring_PV = (1/(1+params.r))^(yr_start-1) * (1/(1+params.r))^(1/12 * (prep_start_month+1));
                    tailoring_nom_costs = cap_avail_m * (params.tailoring_pct * params.k_m) + cap_avail_o * (params.tailoring_pct * params.k_o);
                    inp_tailoring_costs_PV = tailoring_PV * tailoring_nom_costs;

                    sim_out_arr_costs_inp_tailoring_nom(s, :) = sim_out_arr_costs_inp_tailoring_nom(s, :) + ...
                        [repmat(0, 1, yr_start-1) tailoring_nom_costs repmat(0, 1, params.sim_periods-yr_start)] ; % possible this is after yr_start, seems fine for now to just assign to yr_start
                    sim_out_arr_costs_inp_tailoring_PV(s, :) = sim_out_arr_costs_inp_tailoring_PV(s, :) + ...
                        [repmat(0, 1, yr_start-1) tailoring_PV * tailoring_nom_costs repmat(0, 1, params.sim_periods-yr_start)] ;

                    % assume in pandemic RD occurs also at one month into prep start (so uses same disc factor as tailoring costs)
                    sim_out_arr_costs_inp_RD_nom(s, :) = sim_out_arr_costs_inp_RD_nom(s, :) + ...
                        [repmat(0, 1, yr_start-1) inp_RD_nom repmat(0, 1, params.sim_periods-yr_start)] ;
                    sim_out_arr_costs_inp_RD_PV(s, :) = sim_out_arr_costs_inp_RD_PV(s, :) + ...
                        [repmat(0, 1, yr_start-1) tailoring_PV * inp_RD_nom repmat(0, 1, params.sim_periods-yr_start)] ;
                    
                    inp_RD_costs_PV = tailoring_PV * inp_RD_nom;

                    if is_false % putting these in array formats to match the other if-clause
                        tot_months = tau_A;
                        
                        vax_fraction_cum = NaN;
                        vax_benefits_PV = zeros(tot_months, 1);
                        inp_marg_costs_m_PV = zeros(tot_months, 1);
                        inp_marg_costs_o_PV = zeros(tot_months, 1);
                    else
                        [vax_fraction_cum, vax_benefits_PV, vax_benefits_nom, inp_marg_costs_m_PV, inp_marg_costs_o_PV, inp_marg_costs_m_nom, inp_marg_costs_o_nom] = ...
                            run_pandemic(params, tau_A, has_RD_benefit, yr_start, pandemic_natural_dur, state, intensity, cap_avail_m, cap_avail_o);
                    end

                    inp_marg_costs_PV = sum(inp_marg_costs_m_PV, 1) + sum(inp_marg_costs_o_PV, 1);
                    inp_marg_costs_PV_s = inp_marg_costs_PV_s + inp_marg_costs_PV; % total in pandemic costs, in million

                    inp_tailoring_costs_PV_s = inp_tailoring_costs_PV_s + inp_tailoring_costs_PV; % total in pandemic fill and finish costs, in million
                    inp_RD_costs_PV_s = inp_RD_costs_PV_s + inp_RD_costs_PV; % total in pandemic RD costs, in million
                    
                    vax_benefits = sum(vax_benefits_PV, 1);
                    vax_benefits_s = vax_benefits_s + vax_benefits; 
                
                    yr_end = yr_start + pandemic_natural_dur - 1;

                    if ~is_false 
                        sim_out_arr_benefits_vaccine_PV(s, :)  = sim_out_arr_benefits_vaccine_PV(s, :) + agg_by_yr(vax_benefits_PV, pandemic_natural_dur, yr_start, params.sim_periods);
                        sim_out_arr_benefits_vaccine_nom(s, :) = sim_out_arr_benefits_vaccine_nom(s, :) + agg_by_yr(vax_benefits_nom, pandemic_natural_dur, yr_start, params.sim_periods);

                        sim_out_arr_costs_inp_marg_PV(s, :) = sim_out_arr_costs_inp_marg_PV(s, :) + agg_by_yr(inp_marg_costs_o_PV + inp_marg_costs_m_PV, pandemic_natural_dur, yr_start, params.sim_periods);
                        sim_out_arr_costs_inp_marg_nom(s,:) = sim_out_arr_costs_inp_marg_nom(s,:) + agg_by_yr(inp_marg_costs_o_nom + inp_marg_costs_m_nom, pandemic_natural_dur, yr_start, params.sim_periods);
                    end

                    assert(cap_avail_m >= z_m0)
                    assert(cap_avail_o >= z_o0)

                    z_m = z_m0 + (cap_avail_m-z_m0) * params.capacity_kept; % update advanced capacity for future pandemics
                    z_o = z_o0 + (cap_avail_o-z_o0) * params.capacity_kept; % update advanced capacity for future pandemics

                    res = gen_output_struct(sim_scens_s(i, :), cap_avail_m / 10^3, cap_avail_o / 10^3, ...
                        vax_benefits / 10^3, vax_fraction_cum, inp_marg_costs_PV / 10^3, inp_tailoring_costs_PV / 10^3, inp_RD_costs_PV / 10^3, inp_cap_costs_PV / 10^3);
                end

                sim_results = [sim_results; res];

            end

        end 

        % end of simulation s

        cap_costs_tot = sum(cap_costs_arr_PV_cum, 1);
        diff_check = (inp_cap_costs_PV_s + upfront_cap_costs) - cap_costs_tot;
        assert(round(diff_check, 0) == 0) 

        vax_costs_bn_s = (inp_marg_costs_PV_s + inp_tailoring_costs_PV_s + inp_RD_costs_PV_s + cap_costs_tot)/10^3;
        
        if params.has_RD == 1
            vax_costs_bn_s = vax_costs_bn_s + RD_spend_bn_PV;
        end

        if has_surveil == 1
            vax_costs_bn_s = vax_costs_bn_s + surveil_spend_bn_PV;
        end

        % store sim results
        vax_net_benefits_bn_arr(s) = vax_benefits_s / 10^3 - vax_costs_bn_s;
        vax_benefits_bn_arr(s)     = vax_benefits_s / 10^3;
        vax_costs_bn_arr(s)        = vax_costs_bn_s;
        
        vax_costs_inp_cap_bn_arr(s)       = inp_cap_costs_PV_s / 10^3;
        vax_costs_inp_m_bn_arr(s)         = inp_marg_costs_PV_s / 10^3;
        vax_costs_inp_tailoring_bn_arr(s) = inp_tailoring_costs_PV_s / 10^3;
        vax_costs_inp_RD_bn_arr(s)        = inp_RD_costs_PV_s / 10^3;
        vax_costs_upf_cap_bn_arr(s)       = upfront_cap_costs / 10^3;

        if mod(s, 1000) == 0
%             fprintf('finished sim num %d (elaspsed min: %d)\n', s, round(toc/60, 1));
            fprintf('finished sim num %d\n', s);
        end
        
    end

    vax_costs_RD_bn_arr = zeros(sim_cnt, 1);
    if params.has_RD == 1
        vax_costs_RD_bn_arr = repmat(RD_spend_bn_PV, sim_cnt, 1);
    end

    vax_costs_surveil_bn_arr = zeros(sim_cnt, 1);
    if has_surveil == 1
        vax_costs_surveil_bn_arr = repmat(surveil_spend_bn_PV, sim_cnt, 1);
    end

    net_value = mean(vax_net_benefits_bn_arr, 1);
    gross_value = mean(vax_benefits_bn_arr, 1);
    gross_costs = mean(vax_costs_bn_arr, 1);

    fprintf('elapsed time (min): %0.1f\n', round(toc/60, 1));
    fprintf('Avg net value (bn): %d\n', round(net_value, 0));

    sim_results_sum0 = table(vax_net_benefits_bn_arr, vax_benefits_bn_arr, vax_costs_bn_arr, ...
        vax_costs_RD_bn_arr, vax_costs_surveil_bn_arr, vax_costs_upf_cap_bn_arr, vax_costs_inp_cap_bn_arr, vax_costs_inp_m_bn_arr, vax_costs_inp_tailoring_bn_arr, vax_costs_inp_RD_bn_arr);
    sim_results_sum0.sim_num = (1:sim_cnt)';

    sim_results_sum = [sim_results_sum0(:,end) sim_results_sum0(:, 1:end-1)]; % make sim_num be first column

    if save_output == 1
        save_to_file(outfile_label, sim_results_sum, sim_results, ...
            sim_out_arr_costs_adv_cap_nom, sim_out_arr_costs_adv_cap_PV, ...
            sim_out_arr_costs_adv_RD_nom, sim_out_arr_costs_adv_RD_PV, ...
            sim_out_arr_costs_surveil_nom, sim_out_arr_costs_surveil_PV, ...
            sim_out_arr_costs_inp_cap_nom, sim_out_arr_costs_inp_cap_PV, ...
            sim_out_arr_costs_inp_marg_nom, sim_out_arr_costs_inp_marg_PV, ...
            sim_out_arr_costs_inp_tailoring_nom, sim_out_arr_costs_inp_tailoring_PV, ...
            sim_out_arr_costs_inp_RD_nom, sim_out_arr_costs_inp_RD_PV, ...
            sim_out_arr_benefits_vaccine_nom, sim_out_arr_benefits_vaccine_PV);
    end
end