function outtable = finish_gen_sim_scens(sim_scens, params)
	% add production state and pandemic natural dur to simulation scenarios table

	row_cnt = size(sim_scens, 1);

	% Preallocate arrays
	rd_state_arr = NaN(row_cnt, 1);
	natural_dur_arr = NaN(row_cnt, 1);
	has_RD_benefit_arr = zeros(row_cnt, 1);
	remove_arr = false(row_cnt, 1);

	% Vectorized operations for state and natural duration
	is_pandemic = ~sim_scens.is_false;
	rd_state = sim_scens.rd_state(is_pandemic);
	draw_natural_dur = sim_scens.draw_natural_dur(is_pandemic);

	% Determine state (1: both, 2: mRNA only, 3: traditional only, 4: none)
	rd_thresholds = cumsum([params.p_b, params.p_m, params.p_o]);
	rd_state_arr(is_pandemic) = sum(rd_state >= rd_thresholds, 2) + 1;

	% Determine natural duration (1: one year, 2: two years, 3: three years)
	dur_thresholds = cumsum(params.pandemic_dur_probs);
	natural_dur_arr(is_pandemic) = sum(draw_natural_dur >= dur_thresholds(1:2), 2) + 1;

	% Handle RD benefits
	if params.has_RD == 1
		rd_eligible = is_pandemic & (sim_scens.yr_start > params.adv_RD_benefit_start);
		family_researched = ismember(sim_scens.pathogen_family, params.viral_families_researched);
		has_RD_benefit_arr = rd_eligible & family_researched;

		% Adjust thresholds for RD benefits
		rd_adjustment = params.RD_success_rate_increase_per_platform * [2, 1, 1];
		adjusted_thresholds = rd_thresholds + cumsum(rd_adjustment);
		
		rd_state = sum(rd_state >= adjusted_thresholds, 2) + 1;
		rd_state_arr(rd_eligible & researched_families) = rd_state(rd_eligible & researched_families);
	end

	% Identify and remove overlapping pandemics
	sim_groups = findgroups(sim_scens.sim_num);
	[~, idx] = sortrows([sim_groups, sim_scens.yr_start]);
	sorted_yr_start = sim_scens.yr_start(idx);
	sorted_natural_dur = natural_dur_arr(idx);
    sorted_yr_end = sorted_yr_start + sorted_natural_dur - 1;

	next_start = [sorted_yr_start(2:end); NaN];
    next_group = [sim_groups(2:end); NaN];
	remove_arr(idx) = (next_start <= sorted_yr_end) & (next_group == sim_groups);
    % This removes the first of the two overlapping pandemics; updated later to remove the second.
    % It also removes all in a sequence, even if removing intermediary would make the others non-overlapping.

	% Reorder arrays back to original order
	[~, original_order] = sort(idx);
	remove_arr = remove_arr(original_order);

    outtable = sim_scens;

    outtable.rd_state = rd_state_arr;
    outtable.natural_dur = natural_dur_arr;
    outtable.has_RD_benefit = has_RD_benefit_arr;

    outtable(remove_arr == 1,:) = [];

    row_cnt2 = row_cnt - sum(remove_arr);
    outtable.state_desc = repmat({""}, row_cnt2, 1);
    outtable.state_desc(outtable.rd_state==1) = {"both"};
    outtable.state_desc(outtable.rd_state==2) = {"mRNA_only"};
    outtable.state_desc(outtable.rd_state==3) = {"trad_only"};
    outtable.state_desc(outtable.rd_state==4) = {"none"};
    outtable.state_desc(isnan(outtable.rd_state)) = {"no_pandemic"};

end