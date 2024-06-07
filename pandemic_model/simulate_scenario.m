function simulate_scenario(params, sim_scens_path)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % NOTE:
    % In these codes, capacity units are in outright levels, whereas anything denominated
    % in dollars is calculated / passed in millions (save for the end, when we dump results out
    % for display, for which we put capacity and anything in dollars into bn of units)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%%%%%%%%%%%%% PARAMETERS

    %%%%%%% LOAD SCENS
    load(sim_scens_path, 'sim_scens');
    sim_scens0 = sim_scens;
    clear sim_scens;

    sim_scens0.prep_start_month = run_surveillance(sim_scens0.posterior1, ...
        sim_scens0.posterior2, sim_scens0.is_false, params.enhanced_surveillance, params.surveillance_thresholds);
    
    sim_scens = finish_gen_sim_scens(sim_scens0, params); % adds state, natural_dur and has_RD_benefit columns

    sim_scens = removevars(sim_scens, {'draw_state', 'draw_natural_dur', 'posterior1', 'posterior2'}); % remove the random draw columns
    %%%%%%%%%%%%%%%% INITIALIZATION %%%%%%%%%%%%%%%%

    sim_cnt = max(sim_scens.sim_num); % number of simulations

    vax_net_benefits_bn_arr = zeros(sim_cnt, 1); % array of net benefits for the simulations
    vax_benefits_bn_arr = zeros(sim_cnt, 1); % array of benefits
    vax_costs_bn_arr = zeros(sim_cnt, 1); % array of costs
    
    vax_costs_inp_m_bn_arr = zeros(sim_cnt, 1); % array of costs for in pandemic marginal costs
    vax_costs_inp_tailoring_bn_arr = zeros(sim_cnt, 1); % array of costs for in pandemic fill & finish costs
    vax_costs_inp_RD_bn_arr = zeros(sim_cnt, 1); % array of costs for in pandemic RD costs
    vax_costs_inp_cap_bn_arr = zeros(sim_cnt, 1); % array of costs for in pandemic at risk capacity investments
    vax_costs_upf_cap_bn_arr = zeros(sim_cnt, 1); % array of costs for adv capacity investments

    sim_results = array2table(double.empty(0, 18), 'VariableNames', {'sim_num', 'yr_start', 'intensity', 'is_false', 'pathogen_family', ...
        'prep_start_month', 'state', 'natural_dur', 'has_RD_benefit', 'state_desc', ...
        'cap_avail_m', 'cap_avail_o', 'vax_benefits', 'vax_fraction_cum', 'inp_marg_costs', 'inp_tailoring_costs', 'inp_RD_costs', 'inp_cap_costs'} );

    %%%%%%%%%%%%%%%% Initialize capacity %%%%%%%%%%%

    [x_m, x_o] = get_target_capacity(params); % get target capacity (in millions)
    build_years = params.adv_cap_build_period;
    non_build_years = params.sim_periods - build_years;
    adv_cap_m_build_per_year = params.z_m / build_years;
    adv_cap_o_build_per_year = params.z_o / build_years;

    % Advance capacity built gradually over time and perpetually maintained.
    adv_cap_m_over_time = [adv_cap_m_build_per_year * (1:build_years), repmat(params.z_m, 1, non_build_years)];
    adv_cap_o_over_time = [adv_cap_o_build_per_year * (1:build_years), repmat(params.z_o, 1, non_build_years)];

    % Calculate costs during preparation period.
    tailoring_fraction = params.tailoring_fraction;
    adv_cap_m_capital_costs_build_years = repmat(capital_costs(adv_cap_m_build_per_year, params, tailoring_fraction, 1, 1), 1, build_years);
    adv_cap_o_capital_costs_build_years = repmat(capital_costs(adv_cap_o_build_per_year, params, tailoring_fraction, 0, 1), 1, build_years);
    adv_cap_capital_costs_over_time = [adv_cap_m_capital_costs_build_years + adv_cap_o_capital_costs_build_years, zeros(1, non_build_years)];
    adv_cap_stock_value_over_time = cumsum(adv_cap_capital_costs_over_time);
    adv_cap_capital_costs_build_years_tot = sum(adv_cap_capital_costs_over_time);

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
    
    if params.enhanced_surveillance == 1 
        time_arr = (1:params.sim_periods)';
        PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors
        surveil_spend_bn_init = repmat(params.surveil_annual_installation_spend, 1, params.surveil_installation_years);
        surveil_spend_bn_maintenance = repmat(params.surveil_maintenance_spend, 1, params.sim_periods - params.surveil_installation_years);
        surveil_spend_bn_arr = [surveil_spend_bn_init surveil_spend_bn_maintenance];
        surveil_spend_bn_PV = sum(surveil_spend_bn_arr' .* PV_factor_yr);

        sim_out_arr_costs_surveil_nom = repmat(surveil_spend_bn_arr * 1000, sim_cnt, 1);
        sim_out_arr_costs_surveil_PV = sim_out_arr_costs_surveil_nom .* repmat(PV_factor_yr', sim_cnt, 1);
    end
    
    %%% benefits
    sim_out_arr_benefits_vaccine_nom  = zeros(sim_cnt, params.sim_periods);
    sim_out_arr_benefits_vaccine_PV  = zeros(sim_cnt, params.sim_periods);

    % R&D costs
    inp_RD_nom = params.inp_RD_cost * 1000; % mn of nominal

    time_arr = (1:params.adv_RD_benefit_start)';
    PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors
    
    adv_RD_spend_bn_arr = repmat(params.adv_RD_spend / params.adv_RD_benefit_start, params.adv_RD_benefit_start, 1);
    adv_RD_spend_bn_PV = sum(adv_RD_spend_bn_arr .* PV_factor_yr);

    adv_RD_spend_bn_tbl = repmat(params.adv_RD_spend / params.adv_RD_benefit_start * 1000, sim_cnt, params.adv_RD_benefit_start); % in millions (consistent with the fact that everthing in codes is in mn, and all time series are in mn as well)
    sim_out_arr_costs_adv_RD_nom(:, 1:params.adv_RD_benefit_start) = adv_RD_spend_bn_tbl;
    sim_out_arr_costs_adv_RD_PV(:, 1:params.adv_RD_benefit_start) = adv_RD_spend_bn_tbl .* repmat(PV_factor_yr', sim_cnt, 1 );

    tic;
    fprintf('Starting simulations...');

    cluster = parcluster;
    parfor (s = 1:sim_cnt, cluster) % loop through each simulation scenario
    % for s =1:sim_cnt
        idx = sim_scens.sim_num == s; % indices of rowsinu for sim s
        row_cnt_s = sum(idx>0); % number of rows for this simulation
        sim_scens_s = sim_scens(idx, :); % filter sim_scens for rows relevant for this simulation

        [yr_start_arr, intensity_arr, natural_dur_arr, is_false_arr, state_arr, has_RD_benefit_arr, prep_start_month_arr] = ...
            extract_columns_from_table(sim_scens_s); % unpack designated columns as arrays
        
        vax_benefits_s = 0; % total benefit in simulation (total across pandemics, in million)
        
        inp_cap_costs_PV_s = 0;
        inp_marg_costs_PV_s = 0; 
        inp_tailoring_costs_PV_s = 0;
        inp_RD_costs_PV_s = 0;

        if row_cnt_s == 1 && isnan(yr_start_arr(1)) %  no pandemic in this simulation (benefits and costs stay at their default of zero)

            % Calculate capacity operating costs
            adv_cap_maintenance_cost_over_time = get_capacity_maintenance_cost(adv_cap_stock_value_over_time, params);
            rental_income_fractions = get_rental_fractions(params, adv_cap_m_over_time, adv_cap_o_over_time);
            adv_cap_maintenance_cost_over_time_rent_adjusted = adv_cap_maintenance_cost_over_time .* (1-rental_income_fractions);
            total_adv_cap_costs_over_time = adv_cap_maintenance_cost_over_time_rent_adjusted + adv_cap_capital_costs_over_time;
            
            % Calculate present_value
            total_adv_cap_costs_over_time_pv = total_adv_cap_costs_over_time .* (1./((1+params.r).^(1:params.sim_periods)));
            sim_out_arr_costs_adv_cap_nom(s, :) = total_adv_cap_costs_over_time;
            sim_out_arr_costs_adv_cap_PV(s, :) = total_adv_cap_costs_over_time_pv;
            
            % Not sure yet what purpose this serves.
            upfront_cap_costs = sum(total_adv_cap_costs_over_time_pv); % adv capacity cost (in million)
            total_surge_cap_costs_over_time_pv = zeros(1, params.sim_periods);

            adv_cap_m_end = adv_cap_m_over_time(end);
            adv_cap_o_end = adv_cap_o_over_time(end);
            
            res = gen_output_struct(sim_scens_s(1, :), adv_cap_m_end/10^3, adv_cap_o_end/10^3, 0, NaN, 0, 0, 0, 0);
            sim_results = [sim_results; res];

        else
            indx = yr_start_arr(1)-1;
            if indx > params.adv_cap_build_period
                indx = params.adv_cap_build_period;
            end

            % Add fill and finish to value of advance capital stock.
            % Consider moving this cost to the response category.
            % fill_and_finish_cost = (1/tailoring_fraction) * adv_cap_capital_costs_build_years_tot;
            % adv_cap_stock_value_over_time((indx+1):end) = adv_cap_stock_value_over_time((indx+1):end) + fill_and_finish_cost;
            
            % Initialize surge capacity
            % Might have to do this earlier.
            surge_cap_m_over_time = zeros(1, params.sim_periods);
            surge_cap_o_over_time = zeros(1, params.sim_periods);
            surge_cap_capital_costs_over_time = zeros(1, params.sim_periods);
            surge_cap_stock_value_over_time = zeros(1, params.sim_periods); % This will have to account for fluctuation in stock over time.
            
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
                yr_pandemic_end      = min(yr_start + pandemic_natural_dur - 1, params.sim_periods);
                if is_false == 1
                    yr_pandemic_end = yr_start;
                end
                in_pandemic_indx     = yr_start:yr_pandemic_end;

                if i < row_cnt_s
                    next_signal = yr_start_arr(i+1)-1;
                else
                    next_signal = params.sim_periods;
                end

                pandemic_end_to_next_indx = (yr_pandemic_end+1):next_signal;

                % Get existing advance capacity
                adv_cap_m_current = adv_cap_m_over_time(yr_start-1);
                adv_cap_o_current = adv_cap_o_over_time(yr_start-1);
                surge_cap_m_current = surge_cap_m_over_time(yr_start-1);
                surge_cap_o_current = surge_cap_o_over_time(yr_start-1);

                if isnan(prep_start_month) % correctly anticipated false pos, no wastage, no benefits (nothing needs to be done in codes, just add a row to output)
                    cap_avail_m = adv_cap_m_current + surge_cap_m_current;
                    cap_avail_o = adv_cap_o_current + surge_cap_o_current;
                    
                    assert(cap_avail_m >= adv_cap_m_current)
                    assert(cap_avail_o >= adv_cap_o_current)

                    % Update surge capacity
                    % I don't feel we should be shutting down capacity here tbh.
                    surge_cap_m_over_time(yr_start:next_signal) = surge_cap_m_current * params.capacity_kept; 
                    surge_cap_o_over_time(yr_start:next_signal) = surge_cap_o_current * params.capacity_kept;
                    surge_cap_stock_value_over_time(yr_start:next_signal) = ...
                        surge_cap_stock_value_over_time(yr_start-1) * params.capacity_kept;

                    res = gen_output_struct(sim_scens_s(i, :), cap_avail_m/10^3, cap_avail_o/10^3, 0, NaN, 0, 0, 0, 0);

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

                    % Build capacity
                    total_cap_m_before_build = adv_cap_m_current + surge_cap_m_current;
                    total_cap_o_before_build = adv_cap_o_current + surge_cap_o_current;
                    surge_cap_m_build = min(x_m - total_cap_m_before_build, params.x_avail / 10^6 * params.mRNA_share);
                    surge_cap_o_build = min(x_o - total_cap_o_before_build, params.x_avail / 10^6 * (1-params.mRNA_share));
                    surge_cap_m_current = surge_cap_m_current + surge_cap_m_build;
                    surge_cap_o_current = surge_cap_o_current + surge_cap_o_build;
                    cap_avail_m = adv_cap_m_current + surge_cap_m_current;
                    cap_avail_o = adv_cap_o_current + surge_cap_o_current;

                    surge_cap_m_capital_costs = capital_costs(surge_cap_m_build, params, 0, 1, 0);
                    surge_cap_o_capital_costs = capital_costs(surge_cap_o_build, params, 0, 0, 0);
                    surge_cap_capital_costs = surge_cap_m_capital_costs + surge_cap_o_capital_costs;
                    surge_cap_capital_costs_over_time(yr_start) = surge_cap_capital_costs;
                    surge_cap_stock_value_over_time(in_pandemic_indx) = surge_cap_stock_value_over_time(yr_start-1) + ...
                        surge_cap_capital_costs;
                    
                    % fill and finish incurred at one month into prep start. 
                    tailoring_PV = (1/(1+params.r))^(yr_start-1) * (1/(1+params.r))^(1/12 * (prep_start_month+1));
                    tailoring_nom_costs = adv_cap_m_current * (tailoring_fraction * params.k_m) + ...
                        adv_cap_o_current * (tailoring_fraction * params.k_o);
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
                
                    if ~is_false 
                        sim_out_arr_benefits_vaccine_PV(s, :)  = sim_out_arr_benefits_vaccine_PV(s, :) + agg_by_yr(vax_benefits_PV, pandemic_natural_dur, yr_start, params.sim_periods);
                        sim_out_arr_benefits_vaccine_nom(s, :) = sim_out_arr_benefits_vaccine_nom(s, :) + agg_by_yr(vax_benefits_nom, pandemic_natural_dur, yr_start, params.sim_periods);

                        sim_out_arr_costs_inp_marg_PV(s, :) = sim_out_arr_costs_inp_marg_PV(s, :) + agg_by_yr(inp_marg_costs_o_PV + inp_marg_costs_m_PV, pandemic_natural_dur, yr_start, params.sim_periods);
                        sim_out_arr_costs_inp_marg_nom(s,:) = sim_out_arr_costs_inp_marg_nom(s,:) + agg_by_yr(inp_marg_costs_o_nom + inp_marg_costs_m_nom, pandemic_natural_dur, yr_start, params.sim_periods);
                    end
                    
                    % Deal with capacity stuff
                    % If we change ratios from 50-50 I will have to rewrite.
                    surge_cap_m_over_time(in_pandemic_indx) = surge_cap_m_current;
                    surge_cap_o_over_time(in_pandemic_indx) = surge_cap_o_current;
                    surge_cap_m_over_time(pandemic_end_to_next_indx) = surge_cap_m_current * params.capacity_kept;
                    surge_cap_o_over_time(pandemic_end_to_next_indx) = surge_cap_o_current * params.capacity_kept;
                    surge_cap_stock_value_over_time(pandemic_end_to_next_indx) = surge_cap_stock_value_over_time(yr_pandemic_end) .* params.capacity_kept; % This will result in errors unless you have 50-50 mRNA capacity ratios.
                    inp_cap_costs_PV = sum(surge_cap_capital_costs_over_time); % Note we have now changed what this number means.

                    res = gen_output_struct(sim_scens_s(i, :), cap_avail_m / 10^3, cap_avail_o / 10^3, ...
                        vax_benefits / 10^3, vax_fraction_cum, inp_marg_costs_PV / 10^3, inp_tailoring_costs_PV / 10^3, inp_RD_costs_PV / 10^3, inp_cap_costs_PV / 10^3);
                end

                sim_results = [sim_results; res];

            end

            % Get rental income fractions
            if params.endogenous_rental == 1
                total_cap_m_over_time = adv_cap_m_over_time + surge_cap_m_over_time;
                total_cap_o_over_time = adv_cap_o_over_time + surge_cap_o_over_time;
                rental_income_fractions = get_rental_fractions(params, total_cap_m_over_time, total_cap_o_over_time);
            else
                rental_income_fractions = repmat(params.rental_share, 1, params.sim_periods);
            end

            assert(length(yr_start_arr) == length(natural_dur_arr))
            for j = 1:length(yr_start_arr)
                yr_start = yr_start_arr(j);
                if is_false_arr(j) == 1
                    yr_end = yr_start;
                else
                    yr_end = min(yr_start + natural_dur_arr(j) - 1, params.sim_periods);
                end
                in_pandemic_indx = yr_start:yr_end;
                rental_income_fractions(in_pandemic_indx) = 0;
            end
            
            % Get discount factor series
            annual_pv_discount_factors = (1./((1+params.r).^(1:params.sim_periods)));

            % Not going to bother with the within month discounting sorry.
            % Get within month discount rates
            % surge_cap_discount_factors = annual_discount_factors;
            % maintenance_cost_timing_adjustment = ones(1, params.sim_periods);
            % assert(length(yr_start_arr) == length(prep_start_month_arr))
            % for j = 1:length(prep_start_month_arr)
            %     yr_start = yr_start_arr(j);
            %     prep_start_month = prep_start_month_arr(j);
            %     surge_cap_discount_factors(yr_start) = surge_cap_discount_factors(yr_start) * (1/(1+params.r))^(1/12 * (prep_start_month+1));
            %     maintenance_cost_timing_adjustment(yr_start) = 1/12 * (12-prep_start_month-1);
            % end

            % Get calculate maintenance and total costs.
            % Fix the rental income timing later.
            adv_cap_maintenance_costs_over_time = get_capacity_maintenance_cost(adv_cap_stock_value_over_time, params);
            adv_cap_maintenance_costs_over_time_rent_adjusted = adv_cap_maintenance_costs_over_time .* (1-rental_income_fractions);
            total_adv_cap_costs_over_time = adv_cap_capital_costs_over_time + adv_cap_maintenance_costs_over_time_rent_adjusted;
            surge_cap_maintenance_costs_over_time = get_capacity_maintenance_cost(surge_cap_stock_value_over_time, params);
            surge_cap_maintenance_costs_over_time_rent_adjusted = surge_cap_maintenance_costs_over_time .* (1-rental_income_fractions);
            total_surge_cap_costs_over_time = surge_cap_capital_costs_over_time + surge_cap_maintenance_costs_over_time_rent_adjusted;

            % Get PV
            total_adv_cap_costs_over_time_pv = total_adv_cap_costs_over_time .* annual_pv_discount_factors;
            total_surge_cap_costs_over_time_pv = total_surge_cap_costs_over_time .* annual_pv_discount_factors;

            % Assign to out matrix.
            sim_out_arr_costs_adv_cap_nom(s, :) = total_adv_cap_costs_over_time;
            sim_out_arr_costs_adv_cap_PV(s, :) = total_adv_cap_costs_over_time_pv;
            sim_out_arr_costs_inp_cap_nom(s, :) = total_surge_cap_costs_over_time;
            sim_out_arr_costs_inp_cap_PV(s, :) = total_surge_cap_costs_over_time_pv;

        end 

        % end of simulation s
        upfront_cap_costs = sum(total_adv_cap_costs_over_time_pv);
        inp_cap_costs_PV_s = sum(total_surge_cap_costs_over_time_pv);
        cap_costs_tot = sum(total_adv_cap_costs_over_time_pv + total_surge_cap_costs_over_time_pv);

        vax_costs_bn_s = (inp_marg_costs_PV_s + inp_tailoring_costs_PV_s + inp_RD_costs_PV_s + cap_costs_tot)/10^3;
        
        vax_costs_bn_s = vax_costs_bn_s + adv_RD_spend_bn_PV;

        if params.enhanced_surveillance == 1
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
    vax_costs_RD_bn_arr = repmat(adv_RD_spend_bn_PV, sim_cnt, 1);

    vax_costs_surveil_bn_arr = zeros(sim_cnt, 1);
    if params.enhanced_surveillance == 1
        vax_costs_surveil_bn_arr = repmat(surveil_spend_bn_PV, sim_cnt, 1);
    end

    net_value = mean(vax_net_benefits_bn_arr, 1);
    gross_value = mean(vax_benefits_bn_arr, 1);
    gross_costs = mean(vax_costs_bn_arr, 1);

    fprintf('Elapsed time (min): %0.1f\n', round(toc/60, 1));
    fprintf('Avg net value (bn): %d\n', round(net_value, 0));

    sim_results_sum0 = table(vax_net_benefits_bn_arr, vax_benefits_bn_arr, vax_costs_bn_arr, ...
        vax_costs_RD_bn_arr, vax_costs_surveil_bn_arr, vax_costs_upf_cap_bn_arr, vax_costs_inp_cap_bn_arr, vax_costs_inp_m_bn_arr, vax_costs_inp_tailoring_bn_arr, vax_costs_inp_RD_bn_arr);
    sim_results_sum0.sim_num = (1:sim_cnt)';

    sim_results_sum = [sim_results_sum0(:,end) sim_results_sum0(:, 1:end-1)]; % make sim_num be first column

    if params.save_output == 1
        save_to_file(params.scenario_name, params.outdirpath, sim_results_sum, sim_results, ...
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