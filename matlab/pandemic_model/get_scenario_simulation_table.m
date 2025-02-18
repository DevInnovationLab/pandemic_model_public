% Would love to clean this up later.
function new_simulation_table = get_scenario_simulation_table(base_simulation_table, ptrs_vf, ...
															  ptrs_rd, vf_data, params)
	% add vaccine success state to simulation scenarios table
    new_simulation_table = base_simulation_table;

    % Add surveillance outcomes
    new_simulation_table.prep_start_month = run_surveillance(new_simulation_table.posterior1, ...
                                                             new_simulation_table.posterior2, ...
                                                             new_simulation_table.is_false, ...
                                                             params.enhanced_surveillance, ...
                                                             params.surveillance_thresholds);

	% Handle RD benefits
	rd_eligible = new_simulation_table.yr_start > params.adv_RD_benefit_start;
	family_researched = ismember(new_simulation_table.viral_family, params.viral_families_researched);
	new_simulation_table.has_RD_benefit = rd_eligible & family_researched;

	% Adjust thresholds for RD benefits when research eligible
	trad_idx = strcmp(ptrs_vf.platform, "traditional_only");
	mrna_idx = strcmp(ptrs_vf.platform, "mrna_only");
	trad_prob_map = dictionary(ptrs_vf.viral_family(trad_idx), ptrs_vf.preds(trad_idx));
	mrna_prob_map = dictionary(ptrs_vf.viral_family(mrna_idx), ptrs_vf.preds(mrna_idx));
	
	% Add PTRS for unknown diseases
	adv_rd_idx = strcmp(ptrs_rd.has_adv_rd, "has_adv_rd");
	rd_mrna_idx = strcmp(ptrs_rd.platform, "mrna_only");
	trad_prob_map("unknown") = ptrs_rd.preds(~adv_rd_idx & ~rd_mrna_idx);
	trad_prob_map(missing) = NaN;
	mrna_prob_map("unknown") = ptrs_rd.preds(~adv_rd_idx & rd_mrna_idx);
	mrna_prob_map(missing) = NaN;

	trad_probs = trad_prob_map(new_simulation_table.viral_family);
	mrna_probs = mrna_prob_map(new_simulation_table.viral_family);

	% Adjust probabilities for vaccines invested in
	% Clean this up later when better idea of what you wnat to do.
	trad_increment = ptrs_rd.preds(~rd_mrna_idx & adv_rd_idx) - ptrs_rd.preds(~rd_mrna_idx & ~adv_rd_idx);
	mrna_increment = ptrs_rd.preds(rd_mrna_idx & adv_rd_idx) - ptrs_rd.preds(rd_mrna_idx & ~adv_rd_idx);

	vfs_no_adv = vf_data.viral_family(~vf_data.has_adv_RD);
	increment_idx = ismember(new_simulation_table.viral_family, vfs_no_adv) & new_simulation_table.has_RD_benefit;
	trad_probs(increment_idx) = trad_probs(increment_idx) + trad_increment;
	mrna_probs(increment_idx) = mrna_probs(increment_idx) + mrna_increment;

	% Get whether vaccine platforms succeeded
	trad_success = trad_probs > new_simulation_table.trad_vax_state;
	mrna_success = mrna_probs > new_simulation_table.mrna_vax_state;

	new_simulation_table.rd_state = 4 * ones(size(trad_success)); % Initialize all to state 4 (none successful)
	new_simulation_table.rd_state(mrna_success & trad_success) = 1; % Both successful
	new_simulation_table.rd_state(mrna_success & ~trad_success) = 2; % Only mRNA successful  
	new_simulation_table.rd_state(~mrna_success & trad_success) = 3; % Only traditional successful
	new_simulation_table.rd_state(isnan(new_simulation_table.yr_start)) = nan; % Set to nan if no pandemic

    new_simulation_table.rd_state_desc = repmat({""}, size(new_simulation_table, 1), 1);
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==1) = {"both"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==2) = {"mRNA_only"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==3) = {"trad_only"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==4) = {"none"};
    new_simulation_table.rd_state_desc(isnan(new_simulation_table.rd_state)) = {"no_pandemic"};
end


function prep_start_month_arr = run_surveillance(posterior1, posterior2, is_false_arr, enhanced_surveillance, threshold_surveil_arr)
	% only computes, no random number generation

	% Extract thresholds
	threshold_no_surveil = threshold_surveil_arr(1);
	threshold_surveil = threshold_surveil_arr(2);

	% Compute true state and prepare decisions
	prepare_decision1 = posterior1 > (enhanced_surveillance * threshold_surveil + ~enhanced_surveillance * threshold_no_surveil);
	prepare_decision2 = posterior2 > threshold_surveil;

	% Initialize prep_start_month_arr with default value
	prep_start_month_arr = 2 * ones(size(is_false_arr));

	if enhanced_surveillance
		% Enhanced surveillance logic
		prep_start_month_arr(prepare_decision1) = 0;
		prep_start_month_arr(~prepare_decision1 & prepare_decision2) = 1;
	else
		% No enhanced surveillance logic
		prep_start_month_arr(prepare_decision1) = 1; % We use prep decision 1 as we don't get better signal.
	end

	% Handle cases where no pandemic was correctly anticipated
	no_pandemic_correctly_anticipated = is_false_arr & ((~enhanced_surveillance & ~prepare_decision1) | (enhanced_surveillance & ~prepare_decision1 & ~prepare_decision2));
	prep_start_month_arr(no_pandemic_correctly_anticipated) = NaN;

	% Ensure prep_start_month_arr is a column vector
	prep_start_month_arr = prep_start_month_arr(:);
end