% Would love to clean this up later.
function new_simulation_table = get_scenario_simulation_table(base_simulation_table, ptrs_pathogen, ...
															  ptrs_rd, response_rd_timelines, ...
															  pathogen_data, params)
	% add vaccine success state to simulation scenarios table
    new_simulation_table = base_simulation_table;

	% Unpack variables for readability
	yr_start = new_simulation_table.yr_start;
	is_false = new_simulation_table.is_false;
	
    % Add surveillance outcomes
    prep_start_month = run_surveillance(new_simulation_table.early_detection_q, ...
										new_simulation_table.is_false, ...
										params.improved_early_warning, ...
										params.months_to_early_detect, ...
										params.months_to_regular_detect, ...
										params.base_early_detect_prob_true, ...
										params.base_early_detect_prob_false, ...
										params.inc_early_detect_prob_true, ...
										params.inc_early_detect_prob_false);
	
	pathogens_with_baseline_prototype = pathogen_data.pathogen(pathogen_data.has_prototype == 1);
	pathogens_no_baseline_prototype = pathogen_data.pathogen(pathogen_data.has_prototype == 0);

	pathogen = new_simulation_table.pathogen;
	existing_prototype = ismember(pathogen, pathogens_with_baseline_prototype);
	gains_prototype = ismember(pathogen, pathogens_no_baseline_prototype(ismember(pathogens_no_baseline_prototype, params.pathogens_with_prototype)));
	prototype_RD_done = yr_start > params.prototype_RD_benefit_start;
	has_prototype = existing_prototype | (gains_prototype & prototype_RD_done);

	% Adjust thresholds for RD benefits when research eligible
	trad_idx = strcmp(ptrs_pathogen.platform, "traditional_only");
	mrna_idx = strcmp(ptrs_pathogen.platform, "mrna_only");
	trad_prob_map = dictionary(ptrs_pathogen.pathogen(trad_idx), ptrs_pathogen.preds(trad_idx));
	mrna_prob_map = dictionary(ptrs_pathogen.pathogen(mrna_idx), ptrs_pathogen.preds(mrna_idx));
	
	% Add PTRS for unknown virus
	prototype_rd_idx = strcmp(ptrs_rd.has_prototype, "has_prototype");
	rd_mrna_idx = strcmp(ptrs_rd.platform, "mrna_only");
	trad_prob_map("unknown_virus") = ptrs_rd.preds(~prototype_rd_idx & ~rd_mrna_idx);
	trad_prob_map(missing) = NaN;
	mrna_prob_map("unknown_virus") = ptrs_rd.preds(~prototype_rd_idx & rd_mrna_idx);
	mrna_prob_map(missing) = NaN;

	trad_probs = trad_prob_map(pathogen);
	mrna_probs = mrna_prob_map(pathogen);

	% Adjust probabilities for vaccines invested in
	% Clean this up later when better idea of what you wnat to do.
	trad_increment = ptrs_rd.preds(~rd_mrna_idx & prototype_rd_idx) - ptrs_rd.preds(~rd_mrna_idx & ~prototype_rd_idx);
	mrna_increment = ptrs_rd.preds(rd_mrna_idx & prototype_rd_idx) - ptrs_rd.preds(rd_mrna_idx & ~prototype_rd_idx);

	% Only apply R&D benefits after prototype_RD_benefit_start years
	trad_probs(gains_prototype & prototype_RD_done) = trad_probs(gains_prototype & prototype_RD_done) + trad_increment;
	mrna_probs(gains_prototype & prototype_RD_done) = mrna_probs(gains_prototype & prototype_RD_done) + mrna_increment;

	% Get whether vaccine platforms succeeded
	trad_success = trad_probs > new_simulation_table.trad_vax_state;
	mrna_success = mrna_probs > new_simulation_table.mrna_vax_state;

	% Handle universal flu vaccine investment
	flu_vax_success_prob = trad_prob_map("flu"); % Assume made using traditional platform
	flu_outbreak_idx = strcmp(pathogen, "flu");
	ufv_protection = (...
		params.ufv_invest & ... % Investment was made
		flu_outbreak_idx & ... % Dealing with influenza
		prototype_RD_done & ... % After R&D benefit starts
		flu_vax_success_prob > new_simulation_table.ufv_vax_state ... % Vaccine successfully provides protection
	);

	trad_success(flu_outbreak_idx) = trad_success(flu_outbreak_idx) | ufv_protection(flu_outbreak_idx); % Universal vaccine gives you an extra shot at goal
	mrna_success(flu_outbreak_idx) = mrna_success(flu_outbreak_idx) & ~ufv_protection(flu_outbreak_idx); % Don't invest in mRNA if universal vaccine works

	%% Vaccine development timelines
	rd_timeline = nan(height(new_simulation_table), 1);
	pathogen_rd_timelines_with_prototype = response_rd_timelines(response_rd_timelines.has_prototype == 1, :);
	pathogen_rd_timelines_no_prototype = pathogen_rd_timelines_with_prototype;
	pathogen_rd_timelines_no_prototype.preds = pathogen_rd_timelines_no_prototype.preds * 2; % Naively just double timeline, make sure to report 

    % Create lookup tables for R&D timelines
    [~, loc_has_proto] = ismember(pathogen, pathogen_rd_timelines_with_prototype.pathogen);
    [~, loc_no_proto] = ismember(pathogen, pathogen_rd_timelines_no_prototype.pathogen);
  
    % Assign timelines
    idx_has_proto = has_prototype & loc_has_proto;
	idx_no_proto = ~has_prototype & loc_no_proto;
    rd_timeline(idx_has_proto) = pathogen_rd_timelines_with_prototype.preds(loc_has_proto(idx_has_proto));
    rd_timeline(idx_no_proto) = pathogen_rd_timelines_no_prototype.preds(loc_no_proto(idx_no_proto));

	rd_timeline(isnan(rd_timeline)) = max(pathogen_rd_timelines_no_prototype.preds); % Take maximum timeline for unknown pathogens
	
	% Ensure all have RD timeline and convert to months
	assert(all(~isnan(rd_timeline)));
	rd_timeline = round(rd_timeline * 12); % Convert to months and round to nearest
	month_vaccine_ready = rd_timeline + prep_start_month;
	month_vaccine_ready(ufv_protection) = ~is_false(ufv_protection) .* prep_start_month(ufv_protection); % When universal vaccine works it's immediately ready

	%% Assign new variables
	new_simulation_table.month_vaccine_ready = month_vaccine_ready;
	new_simulation_table.prep_start_month = prep_start_month;
	new_simulation_table.has_prototype = has_prototype;
	new_simulation_table.ufv_protection = ufv_protection;

	% Encode non universal vaccine R&D states
	new_simulation_table.rd_state = 4 * ones(size(trad_success)); % Initialize all to state 4 (none successful)
	new_simulation_table.rd_state(mrna_success & trad_success) = 1; % Both successful
	new_simulation_table.rd_state(mrna_success & ~trad_success) = 2; % Only mRNA successful  
	new_simulation_table.rd_state(~mrna_success & trad_success) = 3; % Only traditional successful
	new_simulation_table.rd_state(isnan(yr_start)) = nan; % Set to nan if no pandemic

    new_simulation_table.rd_state_desc = repmat({""}, size(new_simulation_table, 1), 1);
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==1) = {"both"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==2) = {"mRNA_only"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==3) = {"trad_only"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==4) = {"none"};
    new_simulation_table.rd_state_desc(isnan(new_simulation_table.rd_state)) = {"no_pandemic"};
end


function prep_start_month_arr = run_surveillance(early_detection_q, is_false_arr, ...
												 improved_early_warning, ...
												 months_to_early_detect, months_to_regular_detect, ...
												 base_early_detect_prob_true, base_early_detect_prob_false, ...
												 inc_early_detect_prob_true, inc_early_detect_prob_false)
	% Compute early detection indidcator
	early_detect_prob_true = base_early_detect_prob_true + improved_early_warning .* inc_early_detect_prob_true;
	early_detect_prob_false = base_early_detect_prob_false + improved_early_warning .* inc_early_detect_prob_false;
	early_detection = early_detection_q < (early_detect_prob_true .* ~is_false_arr + early_detect_prob_false .* is_false_arr);

	prep_start_month_arr = nan(size(is_false_arr));
	prep_start_month_arr(early_detection) = months_to_early_detect;
	prep_start_month_arr(~early_detection & ~is_false_arr) = months_to_regular_detect;
end