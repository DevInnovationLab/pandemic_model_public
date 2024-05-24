function outtable = finish_gen_sim_scens(sim_scens, params)
	% add production state and pandemic natural dur to simulation scenarios table

	pandemic_dur_probs = params.pandemic_dur_probs;

	sim_cnt = max(sim_scens.sim_num); % number of sims
    row_cnt = length(sim_scens.sim_num); % sim X pandemics
    
	state_arr = NaN(row_cnt, 1);
	natural_dur_arr = NaN(row_cnt, 1);
    has_RD_benefit_arr = NaN(row_cnt, 1);

    remove_arr = zeros(row_cnt, 1); % indicator for if row is to be removed (due to multiple pandemics in a row otherwise)

    sim_start = 1; % row index in sim_scens (keeps track of starting row for each sim, in cumulative fashion)
	for s = 1:sim_cnt % loop through each pandemic in each sim
        
        idx         = sim_scens.sim_num == s; % indices of rows for sim s
        row_cnt_s   = sum(idx>0); % number of rows for this simulation
        sim_scens_s = sim_scens(idx, :); % filter sim_scens for rows relevant for this simulation

        yr_start_arr = sim_scens_s.yr_start;
        is_false_arr = sim_scens_s.is_false;
        d1_arr       = sim_scens_s.draw_state;
        d2_arr       = sim_scens_s.draw_natural_dur;
        pathogen_family_arr = sim_scens_s.pathogen_family;

        if row_cnt_s == 1 && isnan(yr_start_arr(1))
            % nothing in this sim
        else
            yr_start_prev = NaN;
            is_false_prev = NaN;
            dur_prev = NaN;

            for i = 1:row_cnt_s % each pandemic in simulation s
                is_false = is_false_arr(i);
                draw1    = d1_arr(i);
                draw2    = d2_arr(i);

                yr_start = yr_start_arr(i);
                
                if ~isnan(yr_start) && ~is_false

                    has_RD_benefit = 0;
                    thold1 = params.p_b;
        	        thold2 = thold1 + params.p_m;
        	        thold3 = thold2 + params.p_o;
                    
                    if params.has_RD == 1 & yr_start > params.RD_benefit_start
                        pathogen_family = pathogen_family_arr(i);
                        if sum(params.RD_family_invested == pathogen_family) == 1
                            has_RD_benefit = 1;
                            thold1 = params.p_b + params.RD_success_rate_increase_per_platform * 2;
        			        thold2 = thold1 + (params.p_m + params.RD_success_rate_increase_per_platform);
        			        thold3 = thold2 + (params.p_o + params.RD_success_rate_increase_per_platform);
                        end
                    end
                	
                    if draw1 < thold1
                        state = 1;
                    elseif draw1 < thold2
                        state = 2;
                    elseif draw1 < thold3
                        state = 3;
                    else
                        state = 4;
                    end
            
                    if draw2 < pandemic_dur_probs(1)
                        pandemic_natural_dur = 1;
                    elseif draw2 < (pandemic_dur_probs(1) + pandemic_dur_probs(2))
                        pandemic_natural_dur = 2;
                    else
                        pandemic_natural_dur = 3;
                    end
            
        	        state_arr(sim_start+i-1) = state;
        	    	natural_dur_arr(sim_start+i-1) = pandemic_natural_dur;
                    has_RD_benefit_arr(sim_start+i-1) = has_RD_benefit;
                
                end

                if i == 1
                    yr_start_prev = yr_start;
                    is_false_prev = is_false;
                    if ~is_false_prev
                        dur_prev = pandemic_natural_dur;
                    end
                else 
                    if ~is_false_prev
                        if (yr_start_prev + dur_prev - 1) >= yr_start % cannot have real or false pandemic if still in a real pandemic
                            remove_arr(sim_start+i-1) = 1;
                        end
                        % the "prev" stays the same, no updating
                    else

                        yr_start_prev = yr_start;
                        is_false_prev = is_false;
                        dur_prev = pandemic_natural_dur;
                   
                    end
                end


            end
            
        end
        
        sim_start = sim_start + row_cnt_s;

        if mod(s, 1000) == 0
            fprintf('finished generating scenario for sim num %d\n', s);
        end
        
    end

    outtable = sim_scens;

    outtable.state = state_arr;
    outtable.natural_dur = natural_dur_arr;
    outtable.has_RD_benefit = has_RD_benefit_arr;

    outtable(remove_arr == 1,:) = [];

    row_cnt2 = row_cnt - sum(remove_arr);
    outtable.state_desc = repmat({""}, row_cnt2, 1);
    outtable.state_desc(outtable.state==1) = {"both"};
    outtable.state_desc(outtable.state==2) = {"mRNA_only"};
    outtable.state_desc(outtable.state==3) = {"trad_only"};
    outtable.state_desc(outtable.state==4) = {"none"};
    outtable.state_desc(isnan(outtable.state)) = {"no_pandemic"};

end