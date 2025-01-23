function simulate_scenario(simulation_table, econ_loss_model, params)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % NOTE:
    % In these codes, capacity units are in outright levels, whereas anything denominated
    % in dollars is calculated / passed in millions (save for the end, when we dump results out
    % for display, for which we put capacity and anything in dollars into bn of units)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%%%%%%%%%%%%% PARAMETERS

    %%%%%%% LOAD SCENS
    % Consider moving this later
    simulation_table = removevars(simulation_table, {'posterior1', 'posterior2'}); % remove the random draw columns
    
    %%%%%%%%%%%%%%%% INITIALIZATION %%%%%%%%%%%%%%%%
    sim_cnt = max(params.num_simulations); % number of simulations

    % Set up pandemic-wise results table
    sim_table_cols = simulation_table.Properties.VariableNames;
    sim_table_types = varfun(@class, simulation_table, 'OutputFormat', 'cell');

    result_cols = {'cap_avail_m', 'cap_avail_o', 'u_deaths', 'm_deaths', 'vax_benefits', ...
                    'm_mortality_losses', 'm_output_losses', 'm_learning_losses', 'ex_post_severity', ...
                   'vax_fraction_end', 'inp_marg_costs_PV', 'inp_tailoring_costs_PV', 'inp_RD_costs_PV', ...
                   'inp_cap_costs_PV'};
    result_var_types = repmat({'double'}, [1, numel(result_cols)]);
    
    sim_results_cols = [sim_table_cols, result_cols];
    sim_results_var_types = [sim_table_types, result_var_types];
    sim_results = cell(sim_cnt, 1);

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

    %%% costs - adv
    sim_out_arr_costs_adv_cap_nom       = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_adv_cap_PV        = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_adv_RD_nom        = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_adv_RD_PV         = zeros(params.sim_periods, sim_cnt);
    %%% costs - in-pandemic
    sim_out_arr_costs_inp_cap_nom       = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_inp_cap_PV        = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_inp_marg_nom      = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_inp_marg_PV       = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_inp_tailoring_nom = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_inp_tailoring_PV  = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_inp_RD_nom        = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_inp_RD_PV         = zeros(params.sim_periods, sim_cnt);
    
    %%% costs - surveillance (on-going)
    sim_out_arr_costs_surveil_nom = zeros(params.sim_periods, sim_cnt);
    sim_out_arr_costs_surveil_PV = zeros(params.sim_periods, sim_cnt);
    
    if params.enhanced_surveillance == 1 
        time_arr = (1:params.sim_periods)';
        PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors
        surveil_spend_bn_init = repmat(params.surveil_annual_installation_spend, params.surveil_installation_years, 1);
        surveil_spend_bn_maintenance = repmat(params.surveil_maintenance_spend, params.sim_periods - params.surveil_installation_years, 1);
        surveil_spend_bn_arr = [surveil_spend_bn_init; surveil_spend_bn_maintenance];

        sim_out_arr_costs_surveil_nom = repmat(surveil_spend_bn_arr, 1, sim_cnt);
        sim_out_arr_costs_surveil_PV = sim_out_arr_costs_surveil_nom .* repmat(PV_factor_yr, 1, sim_cnt);
    end
    
    %%% losses and benefits
    sim_out_arr_u_deaths   = zeros(params.sim_periods, sim_cnt); % Unmitigated deaths
    sim_out_arr_m_deaths     = zeros(params.sim_periods, sim_cnt); % Mitigated deaths
    sim_out_arr_m_mortality_losses     = zeros(params.sim_periods, sim_cnt); % Mitigated mortality losses
    sim_out_arr_m_output_losses        = zeros(params.sim_periods, sim_cnt); % Mitigated output losses
    sim_out_arr_learning_losses      = zeros(params.sim_periods, sim_cnt); % Mitigated learning losses
    sim_out_arr_benefits_vaccine  = zeros(params.sim_periods, sim_cnt);

    % Adv R&D costs
    time_arr = (1:params.adv_RD_benefit_start)';
    PV_factor_yr = (1+params.r).^(-time_arr); % array of discount factors

    adv_RD_spend_bn_tbl = repmat(params.adv_RD_spend / params.adv_RD_benefit_start, params.adv_RD_benefit_start, sim_cnt); % in millions (consistent with the fact that everthing in codes is in mn, and all time series are in mn as well)
    sim_out_arr_costs_adv_RD_nom(1:params.adv_RD_benefit_start, :) = adv_RD_spend_bn_tbl;
    sim_out_arr_costs_adv_RD_PV(1:params.adv_RD_benefit_start, :) = adv_RD_spend_bn_tbl .* repmat(PV_factor_yr, 1, sim_cnt );

    tic;
    fprintf('Starting simulations...');

    cluster = parcluster;
    pool = parpool(cluster);

    if params.profile == true
        mpiprofile on;
    end

    ticBytes(pool);
    parfor (s = 1:sim_cnt) % loop through each simulation scenario
    % for s =1:sim_cnt
        idx = simulation_table.sim_num == s; % indices of rows for sim s
        row_cnt_s = sum(idx>0); % number of rows for this simulation
        sim_scens_s = simulation_table(idx, :); % filter sim_scens for rows relevant for this simulation
        [yr_start_arr, severity_arr, natural_dur_arr, actual_dur_arr, is_false_arr, rd_state_arr, has_RD_benefit_arr, prep_start_month_arr, yr_end_arr] = ...
            extract_columns_from_table(sim_scens_s); % unpack designated columns as arrays

        % Output rows for pandemic-wise results
        outrows = table('Size', [row_cnt_s, numel(sim_results_cols)], 'VariableTypes', sim_results_var_types, 'VariableNames', sim_results_cols);

        if row_cnt_s == 1 && isnan(yr_start_arr(1)) %  no pandemic in this simulation (benefits and costs stay at their default of zero)

            % Calculate capacity operating costs
            adv_cap_maintenance_cost_over_time = get_capacity_maintenance_cost(adv_cap_stock_value_over_time, params);
            rental_income_fractions = get_rental_fractions(params, adv_cap_m_over_time, adv_cap_o_over_time);
            adv_cap_maintenance_cost_over_time_rent_adjusted = adv_cap_maintenance_cost_over_time .* (1-rental_income_fractions);
            total_adv_cap_costs_over_time = adv_cap_maintenance_cost_over_time_rent_adjusted + adv_cap_capital_costs_over_time;
            
            % Calculate present_value
            total_adv_cap_costs_over_time_pv = total_adv_cap_costs_over_time .* (1./((1+params.r).^(1:params.sim_periods)));
            sim_out_arr_costs_adv_cap_nom(:, s) = total_adv_cap_costs_over_time';
            sim_out_arr_costs_adv_cap_PV(:, s) = total_adv_cap_costs_over_time_pv';

            % Copy scenario parameters and initialize output row
            outrows(1, :) = gen_output_struct(sim_scens_s(1,:), cap_avail_m, cap_avail_o, 0, 0, ...
                                              0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
            sim_results{s} = outrows;

        else
            indx = yr_start_arr(1)-1; % No idea what this part is doing now
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
                yr_start = yr_start_arr(i);
                pandemic_natural_dur = natural_dur_arr(i);
                actual_dur = actual_dur_arr(i);
                rd_state = rd_state_arr(i);
                severity = severity_arr(i);
                is_false = is_false_arr(i);
                has_RD_benefit = has_RD_benefit_arr(i);
                prep_start_month = prep_start_month_arr(i); % interpret prep_start_month as the month where by the end of it, world starts preparing
                yr_pandemic_end = yr_end_arr(i);
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

                % Set response R&D costs
                if has_RD_benefit == true
                    inp_RD_nom = params.inp_RD_with_adv_RD; % mn of nominal
                elseif has_RD_benefit == false
                    inp_RD_nom = params.inp_RD_no_adv_RD; % mn of nominal
                end

                % Get existing advance capacity
                adv_cap_m_current = adv_cap_m_over_time(yr_start-1);
                adv_cap_o_current = adv_cap_o_over_time(yr_start-1);
                surge_cap_m_current = surge_cap_m_over_time(yr_start-1);
                surge_cap_o_current = surge_cap_o_over_time(yr_start-1);

                if isnan(prep_start_month) % correctly anticipated false pos, no wastage, no benefits (nothing needs to be done in codes, just add a row to output)
                    cap_avail_m = adv_cap_m_current + surge_cap_m_current;
                    cap_avail_o = adv_cap_o_current + surge_cap_o_current;

                    % Add pandemic scenario outcomes
                    outrow = gen_output_row(sim_scens_s(i,:), cap_avail_m, cap_avail_o, 0, 0, ...
                                               0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
                    outrows(i, :) = outrow;

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
                    surge_cap_m_build = min(x_m - total_cap_m_before_build, params.x_avail * params.mRNA_share);
                    surge_cap_o_build = min(x_o - total_cap_o_before_build, params.x_avail * (1-params.mRNA_share));
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
                    % We are now applying fill and finish at each pandemic outbreak.
                    tailoring_PV = (1/(1+params.r))^(yr_start-1) * (1/(1+params.r))^(1/12 * (prep_start_month+1));
                    tailoring_nom_costs = adv_cap_m_current * (tailoring_fraction * params.k_m) + ...
                        adv_cap_o_current * (tailoring_fraction * params.k_o);
                    inp_tailoring_costs_PV = tailoring_PV * tailoring_nom_costs;

                    sim_out_arr_costs_inp_tailoring_nom(:, s) = sim_out_arr_costs_inp_tailoring_nom(:, s) + ...
                        [zeros(yr_start-1, 1); tailoring_nom_costs; zeros(params.sim_periods-yr_start, 1)] ; % possible this is after yr_start, seems fine for now to just assign to yr_start
                    sim_out_arr_costs_inp_tailoring_PV(:, s) = sim_out_arr_costs_inp_tailoring_PV(:, s) + ...
                        [zeros(yr_start-1, 1); tailoring_PV * tailoring_nom_costs; zeros(params.sim_periods-yr_start, 1)] ;

                    % assume in pandemic RD occurs also at one month into prep start (so uses same disc factor as tailoring costs)
                    sim_out_arr_costs_inp_RD_nom(:, s) = sim_out_arr_costs_inp_RD_nom(:, s) + ...
                        [zeros(yr_start-1, 1); inp_RD_nom; zeros(params.sim_periods-yr_start, 1)] ;
                    sim_out_arr_costs_inp_RD_PV(:, s) = sim_out_arr_costs_inp_RD_PV(:, s) + ...
                        [zeros(yr_start-1, 1); tailoring_PV * inp_RD_nom; zeros(params.sim_periods-yr_start, 1)] ;
                    
                    inp_RD_costs_PV = tailoring_PV * inp_RD_nom;

                    if is_false % putting these in array formats to match the other if-clause
                        tot_months = tau_A;
                        
                        vax_fraction_end = NaN;
                        vax_benefits_PV = zeros(tot_months, 1);
                        inp_marg_costs_m_PV = zeros(tot_months, 1);
                        inp_marg_costs_o_PV = zeros(tot_months, 1);
                    else
                        [u_deaths, u_mortality_losses, u_output_losses, u_learning_losses] = ...
                            get_pandemic_losses(params, econ_loss_model, yr_start, pandemic_natural_dur, actual_dur, severity);

                        % Get effective capacity over time during pandemic
                        if has_RD_benefit == true
                            tau_A = tau_A - params.RD_speedup_months;
                        end

                        [ind_m, ind_o] = get_capacity_indicators(rd_state);
                        months_arr = (1:height(u_deaths))';
                        [cap_m_arr, cap_o_arr] = get_pandemic_capacity(months_arr, tau_A, params, ind_m, ind_o, cap_avail_m/12, cap_avail_o/12);
                        vax_fractions_cum = get_vax_fractions(params, cap_m_arr, cap_o_arr);
                        vax_fraction_end = vax_fractions_cum(end);
                        
                        h_arr = h(vax_fractions_cum);
                        m_deaths = u_deaths .* (1 - h_arr) .* params.gamma;

                        u_losses = [u_mortality_losses, u_output_losses, u_learning_losses]; % Unmitigated losses
                        m_losses = u_losses .* (1 - h_arr .* params.gamma);
                        m_mortality_losses = m_losses(:, 1);
                        m_output_losses = m_losses(:, 2);
                        m_learning_losses = m_losses(:, 3);
                        
                        vax_benefits_PV = sum(u_losses - m_losses, 2);
                        growth_rate = (1+params.y)^(yr_start-1) .* (1+params.y).^(1/12 .* months_arr);
                        ex_post_severity = sum(m_deaths ./ ((params.P0 / 10000) .* growth_rate), 1);

                        % marginal capacity costs
                        inp_marg_costs_m_nom = params.c_m .* cap_m_arr;
                        inp_marg_costs_o_nom = params.c_o .* cap_o_arr;

                        % Apply present value factor to marginal costs
                        PV_factor = (1/(1+params.r))^(yr_start-1) .* (1/(1+params.r)).^(1/12 .* months_arr); % Discount factor
                        inp_marg_costs_m_PV = PV_factor .* inp_marg_costs_m_nom;
                        inp_marg_costs_o_PV = PV_factor .* inp_marg_costs_o_nom;      
                    end

                    inp_marg_costs_PV = sum(inp_marg_costs_m_PV, 1) + sum(inp_marg_costs_o_PV, 1);
                
                    if ~is_false
                        sim_out_arr_u_deaths(:, s)           = sim_out_arr_u_deaths(:, s) + agg_by_yr(u_deaths, actual_dur, yr_start, params.sim_periods);
                        sim_out_arr_m_deaths(:, s)           = sim_out_arr_m_deaths(:, s) + agg_by_yr(m_deaths, actual_dur, yr_start, params.sim_periods);
                        sim_out_arr_m_mortality_losses(:, s) = sim_out_arr_m_mortality_losses(:, s) + agg_by_yr(m_mortality_losses, actual_dur, yr_start, params.sim_periods);
                        sim_out_arr_m_output_losses(:, s)    = sim_out_arr_m_output_losses(:, s) + agg_by_yr(m_output_losses, actual_dur, yr_start, params.sim_periods);
                        sim_out_arr_learning_losses(:, s)    = sim_out_arr_learning_losses(:, s) + agg_by_yr(m_learning_losses, actual_dur, yr_start, params.sim_periods);
                        sim_out_arr_benefits_vaccine(:, s)   = sim_out_arr_benefits_vaccine(:, s) + agg_by_yr(vax_benefits_PV, actual_dur, yr_start, params.sim_periods);
                        sim_out_arr_costs_inp_marg_PV(:, s)  = sim_out_arr_costs_inp_marg_PV(:, s) + agg_by_yr(inp_marg_costs_o_PV + inp_marg_costs_m_PV, actual_dur, yr_start, params.sim_periods);
                        sim_out_arr_costs_inp_marg_nom(:, s) = sim_out_arr_costs_inp_marg_nom(:, s) + agg_by_yr(inp_marg_costs_o_nom + inp_marg_costs_m_nom, actual_dur, yr_start, params.sim_periods);
                    end
                    
                    % Deal with capacity stuff
                    % If we change ratios from 50-50 I will have to rewrite.
                    surge_cap_m_over_time(in_pandemic_indx) = surge_cap_m_current;
                    surge_cap_o_over_time(in_pandemic_indx) = surge_cap_o_current;
                    surge_cap_m_over_time(pandemic_end_to_next_indx) = surge_cap_m_current * params.capacity_kept;
                    surge_cap_o_over_time(pandemic_end_to_next_indx) = surge_cap_o_current * params.capacity_kept;
                    surge_cap_stock_value_over_time(pandemic_end_to_next_indx) = surge_cap_stock_value_over_time(yr_pandemic_end) .* params.capacity_kept; % This will result in errors unless you have 50-50 mRNA capacity ratios.
                    inp_cap_costs_PV = sum(surge_cap_capital_costs_over_time); % Note we have now changed what this number means.
                    
                    % Copy scenario parameters
                    % Create a temporary row vector to avoid table indexing in parfor
                    outrow = gen_output_row(sim_scens_s(i,:), ...
                        cap_avail_m, cap_avail_o, ...
                        sum(u_deaths, 1), sum(m_deaths, 1), ...
                        sum(vax_benefits_PV, 1), ...
                        sum(m_mortality_losses, 1), ...
                        sum(m_output_losses, 1), ...
                        sum(m_learning_losses, 1), ...
                        ex_post_severity, ...
                        vax_fraction_end, ...
                        inp_marg_costs_PV, ...
                        inp_tailoring_costs_PV, ...
                        inp_RD_costs_PV, ...
                        inp_cap_costs_PV);
                    outrows(i, :) = outrow;                    

                end

                sim_results{s} = outrows;

            end

            % Get rental income fractions
            if params.endogenous_rental == 1
                total_cap_m_over_time = adv_cap_m_over_time + surge_cap_m_over_time;
                total_cap_o_over_time = adv_cap_o_over_time + surge_cap_o_over_time;
                rental_income_fractions = get_rental_fractions(params, total_cap_m_over_time, total_cap_o_over_time);
            else
                rental_income_fractions = repmat(params.rental_share, 1, params.sim_periods);
            end

            assert(length(yr_start_arr) == length(actual_dur_arr))
            for j = 1:length(yr_start_arr)
                yr_start = yr_start_arr(j);
                if is_false_arr(j) == 1
                    yr_end = yr_start;
                else
                    yr_end = min(yr_start + actual_dur_arr(j) - 1, params.sim_periods);
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
            sim_out_arr_costs_adv_cap_nom(:, s) = total_adv_cap_costs_over_time';
            sim_out_arr_costs_adv_cap_PV(:, s) = total_adv_cap_costs_over_time_pv';
            sim_out_arr_costs_inp_cap_nom(:, s) = total_surge_cap_costs_over_time';
            sim_out_arr_costs_inp_cap_PV(:, s) = total_surge_cap_costs_over_time_pv';
        end

        if mod(s, 1000) == 0
           fprintf('finished sim num %d (elaspsed min: %d)\n', s, round(toc/60, 1));
        end
        
    end
    tocBytes(pool)
    
    if params.profile == true
        mpiprofile viewer
    end

    delete(pool);

    net_value = mean(sum(sim_out_arr_benefits_vaccine, 1), 2);
    fprintf('Elapsed time (min): %0.1f\n', round(toc/60, 1));
    fprintf('Avg net value (bn): %d\n', round(net_value/10^9, 0));

    sim_results = vertcat(sim_results{:});

    if params.save_output == 1
        % Transpose matrices before saving to get simulations in rows.
        save_to_file(params.scenario_name, params.outdirpath, sim_results, ...
            sim_out_arr_costs_adv_cap_nom', sim_out_arr_costs_adv_cap_PV', ...
            sim_out_arr_costs_adv_RD_nom', sim_out_arr_costs_adv_RD_PV', ...
            sim_out_arr_costs_surveil_nom', sim_out_arr_costs_surveil_PV', ...
            sim_out_arr_costs_inp_cap_nom', sim_out_arr_costs_inp_cap_PV', ...
            sim_out_arr_costs_inp_marg_nom', sim_out_arr_costs_inp_marg_PV', ...
            sim_out_arr_costs_inp_tailoring_nom', sim_out_arr_costs_inp_tailoring_PV', ...
            sim_out_arr_costs_inp_RD_nom', sim_out_arr_costs_inp_RD_PV', ...
            sim_out_arr_u_deaths', sim_out_arr_m_deaths', ...
            sim_out_arr_m_mortality_losses', sim_out_arr_m_output_losses', ...
            sim_out_arr_learning_losses', sim_out_arr_benefits_vaccine');
    end
end
