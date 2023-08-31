function outtable = finish_gen_sim_scens(sim_scens, params)
	
	pandemic_dur_probs = params.pandemic_dur_probs;

    yr_start_arr = sim_scens.yr_start;
	is_false_arr = sim_scens.is_false;
	d1_arr = sim_scens.draw_state;
	d2_arr = sim_scens.draw_natural_dur;
	RD_score_arr = sim_scens.RD_score;

	row_cnt = length(is_false_arr);

	state_arr = NaN(row_cnt, 1);
	natural_dur_arr = NaN(row_cnt, 1);

	for i = 1:row_cnt
		is_false = is_false_arr(i);
		draw1 = d1_arr(i);
		draw2 = d2_arr(i);

        yr_start = yr_start_arr(i);
        
        if ~isnan(yr_start) && ~is_false

            thold1 = params.p_b;
	        thold2 = thold1 + params.p_m;
	        thold3 = thold2 + params.p_o;
    
            if params.has_RD == 1
                RD_score = RD_score_arr(i);
                if RD_score >= params.RD_success_rate
                    thold1 = params.p_b + params.RD_impact_vaccine * 2;
			        thold2 = thold1 + (params.p_m + params.RD_impact_vaccine);
			        thold3 = thold2 + (params.p_o + params.RD_impact_vaccine);
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
    
	        state_arr(i) = state;
	    	natural_dur_arr(i) = pandemic_natural_dur;

        end
    end

    outtable = sim_scens;

    outtable.state = state_arr;
    outtable.natural_dur = natural_dur_arr;

    outtable.state_desc = repmat({""}, row_cnt, 1);
    outtable.state_desc(outtable.state==1) = {"both"};
    outtable.state_desc(outtable.state==2) = {"mRNA_only"};
    outtable.state_desc(outtable.state==3) = {"trad_only"};
    outtable.state_desc(outtable.state==4) = {"none"};
    outtable.state_desc(isnan(outtable.state)) = {"no_pandemic"};

end