function monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, has_false_pos)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % NOTE:
    % In these codes, capacity units are in outright levels, whereas anything denominated
    % in dollars is calculated / passed in millions (save for the end, when we dump results out
    % for display, for which we put capacity and anything in dollars into bn of units)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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
    sim_scens0 = readtable(scen_file_name,'Sheet','Sheet1');

    %%%%%%% FINISH SCENARIO CONSTRUCTION
    % construct state and pandemic duration, which can potentially change based on knobs turned

    sim_scens = finish_gen_sim_scens(sim_scens0, params); % adds state, natural_dur and has_RD_benefit columns

    %%%%%%%%%%%%%%%% INITIALIZATION %%%%%%%%%%%%%%%%

    sim_cnt = sim_scens.sim_num(end); % number of simulations

    vax_net_benefits_bn_arr   = zeros(sim_cnt, 1); % array of net benefits for the simulations
    vax_benefits_bn_arr       = zeros(sim_cnt, 1); % array of benefits
    vax_costs_bn_arr          = zeros(sim_cnt, 1); % array of costs
    
    vax_costs_in_p_m_bn_arr   = zeros(sim_cnt, 1); % array of costs for in pandemic marginal costs
    vax_costs_in_p_tailoring_bn_arr  = zeros(sim_cnt, 1); % array of costs for in pandemic fill & finish costs
    vax_costs_in_p_cap_bn_arr = zeros(sim_cnt, 1); % array of costs for in pandemic at risk capacity investments

    sim_results = array2table(double.empty(0,18), 'VariableNames', {'sim_num', 'yr_start', 'intensity', 'is_false', ...
        'RD_score', 'draw_state', 'draw_natural_dur', 'state', 'natural_dur', 'has_RD_benefit', 'state_desc', ...
        'cap_avail_m', 'cap_avail_o', 'vax_benefits', 'vax_fraction_cum', 'in_p_marg_costs', 'in_p_tailoring_costs', 'in_p_cap_costs'} );

    %%%%%%%%%%%%%%%% Initialize capacity %%%%%%%%%%%

    [x_m, x_o] = get_target_capacity(params); % get target capacity
    [z_m0, z_o0, nom_cost_adv0] = get_initial_adv_capacity_costs(params, has_full_adv_cap);

    yr_adv = 1; % yr advance capacity cost, if any, incurred
    cap_costs_arr_PV0 = calc_adv_capacity_costs(params, yr_adv, nom_cost_adv0, 1); % in million, time series for full sim period
    upfront_cap_costs = sum(cap_costs_arr_PV0, 1); % upfront capacity cost (in million)

    tic;
    fprintf('Starting simulations for scen %s ... \n', outfile_label);

    cluster = parcluster;
    parfor (s = 1:sim_cnt, cluster) % loop through each simulation scenario
%     for s = 1:1 % loop through each simulation scenario

%         if s == 2
%             blah = 1;
%         end

        idx         = sim_scens.sim_num == s; % indices of rowsinu for sim s
        row_cnt_s   = sum(idx>0); % number of rows for this simulation
        sim_scens_s = sim_scens(idx, :); % filter sim_scens for rows relevant for this simulation

        [yr_start_arr, intensity_arr, natural_dur_arr, is_false_arr, state_arr, has_RD_benefit_arr] = extract_columns_from_table(sim_scens_s); % unpack designated columns as arrays
        
        % initialize adv capacity for simluation s, these are the capacity that we enter a pandemic with (and gets updated if more is built in a pandemic)
        z_m = z_m0;
        z_o = z_o0;        
        cap_costs_arr_PV = cap_costs_arr_PV0;
        
        vax_benefits_bn_s = 0; % total benefit in simulation (total across pandemics)
        
        in_p_cap_costs_PV_s = 0;
        in_p_marg_costs_PV_s = 0; 
        in_p_tailoring_costs_PV_s = 0;


        if row_cnt_s == 1 && isnan(yr_start_arr(1)) %  no pandemic in this simulation (benefits and costs stay at their default of zero)
            
            res = gen_output_struct(sim_scens_s(1, :), z_m/10^9, z_o/10^9, 0, NaN, 0, 0, 0);
            sim_results = [sim_results; res];

        else
            for i = 1:row_cnt_s % for pandemic i in sim s
                yr_start             = yr_start_arr(i);
                pandemic_natural_dur = natural_dur_arr(i);
                state                = state_arr(i);
                intensity            = intensity_arr(i);
                is_false             = is_false_arr(i);
                has_RD_benefit       = has_RD_benefit_arr(i);

                % costs to install needed capacity during pandemic, assume this is
                % done at risk within a pandemic (occurs even when no vaccine is
                % successful and is a false positive) and in the first month of pandemic
                
                cap_costs_arr_PV_existing = cap_costs_arr_PV; % existing cap costs series
                [cap_costs_arr_PV, cap_avail_m, cap_avail_o] = calc_avail_capacity(yr_start, cap_costs_arr_PV_existing, params, has_full_adv_cap, x_m, z_m, x_o, z_o, i);
                
                in_p_cap_costs_PV = + sum(cap_costs_arr_PV - cap_costs_arr_PV_existing, 1);
                in_p_cap_costs_PV_s = in_p_cap_costs_PV_s + in_p_cap_costs_PV;

                [vax_fraction_cum, vax_benefits_PV, in_p_marg_costs_m_PV, in_p_marg_costs_o_PV, in_p_tailoring_costs_PV] = ...
                    run_pandemic(params, has_RD_benefit, yr_start, is_false, pandemic_natural_dur, state, intensity, cap_avail_m, cap_avail_o);

                in_p_marg_costs_PV = sum(in_p_marg_costs_m_PV, 1) + sum(in_p_marg_costs_o_PV, 1);
                in_p_marg_costs_PV_s = in_p_marg_costs_PV_s + in_p_marg_costs_PV; % total in pandemic costs, in million

                in_p_tailoring_costs_PV = sum(in_p_tailoring_costs_PV, 1); 
                in_p_tailoring_costs_PV_s = in_p_tailoring_costs_PV_s + in_p_tailoring_costs_PV; % total in pandemic fill and finish costs, in million
                
                vax_benefits_bn = sum(vax_benefits_PV, 1) / 10^3;
                vax_benefits_bn_s = vax_benefits_bn_s + vax_benefits_bn; 
                
                res = gen_output_struct(sim_scens_s(i, :), cap_avail_m / 10^9, cap_avail_o / 10^9, ...
                    vax_benefits_bn, vax_fraction_cum, in_p_marg_costs_PV / 10^3, in_p_tailoring_costs_PV / 10^3, in_p_cap_costs_PV / 10^3);

                sim_results = [sim_results; res];

                z_m = cap_avail_m; % update advanced capacity for future pandemics
                z_o = cap_avail_o; % update advanced capacity for future pandemics
            end

        end 

        % end of simulation s

        cap_costs_tot = sum(cap_costs_arr_PV, 1);
        diff_check = (in_p_cap_costs_PV_s + upfront_cap_costs) - cap_costs_tot;
        assert(round(diff_check, 0) == 0) 

        vax_costs_bn_s = (in_p_marg_costs_PV_s + in_p_tailoring_costs_PV_s + cap_costs_tot)/10^3;
        
        if params.has_RD == 1
            vax_costs_bn_s = vax_costs_bn_s + params.RD_spend;
        end

        % store sim results
        vax_net_benefits_bn_arr(s) = vax_benefits_bn_s - vax_costs_bn_s;
        vax_benefits_bn_arr(s)     = vax_benefits_bn_s;
        vax_costs_bn_arr(s)        = vax_costs_bn_s;
        
        vax_costs_in_p_cap_bn_arr(s)= in_p_cap_costs_PV_s / 10^3;
        vax_costs_in_p_m_bn_arr(s) = in_p_marg_costs_PV_s / 10^3;
        vax_costs_in_p_tailoring_bn_arr(s)= in_p_tailoring_costs_PV_s / 10^3;

        if mod(s, 1000) == 0
%             fprintf('finished sim num %d (elaspsed min: %d)\n', s, round(toc/60, 1));
            fprintf('finished sim num %d\n', s);
        end
        
    end

    vax_costs_RD_bn_arr = zeros(sim_cnt, 1);
    if params.has_RD == 1
        vax_costs_RD_bn_arr = repmat(params.RD_spend, sim_cnt, 1);
    end

    vax_costs_upfront_cap_bn_arr = repmat( upfront_cap_costs / 10^3, sim_cnt, 1);

    fprintf('elapsed time (min): %0.1f\n', round(toc/60, 1));
    fprintf('Avg net value (bn): %d\n', round(mean(vax_net_benefits_bn_arr, 1), 0));

    sim_results = removevars(sim_results,{'RD_score', 'draw_state', 'draw_natural_dur'}); % remove the random draw columns

    sim_results_sum0 = table(vax_net_benefits_bn_arr, vax_benefits_bn_arr, vax_costs_bn_arr, ...
        vax_costs_RD_bn_arr, vax_costs_upfront_cap_bn_arr, vax_costs_in_p_cap_bn_arr, vax_costs_in_p_m_bn_arr, vax_costs_in_p_tailoring_bn_arr);
    sim_results_sum0.sim_num = (1:sim_cnt)';

    sim_results_sum = [sim_results_sum0(:,end) sim_results_sum0(:, 1:end-1)]; % make sim_num be first column

    if save_output == 1
       save_to_file(outfile_label, sim_results_sum, sim_results);
    end
end