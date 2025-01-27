% Would love to clean this up later.
function new_simulation_table = get_scenario_simulation_table(base_simulation_table, vf_ptrs_model, adv_rd_ptrs_model, params)
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
	family_researched = ismember(new_simulation_table.pathogen_family, params.viral_families_researched);
	has_RD_benefit = rd_eligible & family_researched;
	new_simulation_table.has_RD_benefit = has_RD_benefit;

	% Adjust thresholds for RD benefits when research eligible
	trad_prob_map = dictionary(vaccine_ptrs_data.viral_family, vaccine_ptrs_data.trad_only);
	mrna_prob_map = dictionary(vaccine_ptrs_data.viral_family, vaccine_ptrs_data.mrna_only);
	trad_probs = trad_prob_map(new_simulation_table.pathogen_family);
	mrna_probs = mrna_prob_map(new_simulation_table.pathogen_family);

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


function prep_start_month_arr = run_surveillance(posterior1, posterior2, is_false, enhanced_surveillance, threshold_surveil_arr)
	% only computes, no random number generation

	% Extract thresholds
	threshold_no_surveil = threshold_surveil_arr(1);
	threshold_surveil = threshold_surveil_arr(2);

	% Compute true state and prepare decisions
	prepare_decision1 = posterior1 > (enhanced_surveillance * threshold_surveil + ~enhanced_surveillance * threshold_no_surveil);
	prepare_decision2 = posterior2 > threshold_surveil;

	% Initialize prep_start_month_arr with default value
	prep_start_month_arr = 2 * ones(size(is_false));

	if enhanced_surveillance
		% Enhanced surveillance logic
		prep_start_month_arr(prepare_decision1) = 0;
		prep_start_month_arr(~prepare_decision1 & prepare_decision2) = 1;
	else
		% No surveillance logic
		prep_start_month_arr(prepare_decision1) = 1;
	end

	% Handle cases where no pandemic was correctly anticipated
	no_pandemic_correctly_anticipated = ((~enhanced_surveillance & ~prepare_decision1) | (enhanced_surveillance & ~prepare_decision1 & ~prepare_decision2));
	prep_start_month_arr(no_pandemic_correctly_anticipated) = NaN;

	% Ensure prep_start_month_arr is a column vector
	prep_start_month_arr = prep_start_month_arr(:);
end