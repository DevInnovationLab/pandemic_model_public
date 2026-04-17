function new_simulation_table = get_scenario_simulation_table(base_simulation_table, ptrs_pathogen, ...
															  prototype_effect_ptrs, params)
	% Apply scenario-specific interventions to a base simulation table.
	%
	% Adjusts the false-positive rate for the surveillance scenario, computes R&D success
	% outcomes (prototype vaccines across traditional and mRNA platforms, plus universal flu
	% vaccine), determines vaccine readiness timelines, and encodes R&D states.
	%
	% Args:
	%   base_simulation_table   Table from get_base_simulation_table.
	%   ptrs_pathogen           Table of pathogen-level PTRS by platform
	%                           (columns: pathogen, platform, ptrs).
	%   prototype_effect_ptrs   Table of PTRS increments from having a prototype
	%                           (columns: platform, effect_mean).
	%   params                  Struct of run parameters. Key fields:
	%                           improved_early_warning, highest_false_positive_rate,
	%                           new_invested_pathogens, advance_RD_benefit_start,
	%                           rd_months_with/no_prototype, universal_flu_rd.
	%
	% Returns:
	%   new_simulation_table    Augmented table with columns: month_response_vaccine_ready,
	%                           prep_start_month, response_initiated, has_prototype,
	%                           has_adv_prototype, prototype_acquired_from_response,
	%                           ufv_protection, rd_state, rd_state_desc.
	
	% First thing to do is to deal with the false positive outbreaks
	% Keeping right amount for false positive rate implied by early warning
	scenario_false_positive_rate = params.improved_early_warning.active .* (1 -  params.improved_early_warning.precision); 
	false_keep_rate = (...
		(scenario_false_positive_rate .* (1 - params.highest_false_positive_rate)) ./ ...
		(params.highest_false_positive_rate .* (1 - scenario_false_positive_rate)) ...
	);
	false_idx = find(base_simulation_table.is_false);
	outbreaks_keep = ~base_simulation_table.is_false;
	n_keep = round(false_keep_rate * numel(false_idx));
	if n_keep > 0
		rng(params.seed);
		keep_idx = false_idx(randperm(numel(false_idx), n_keep));
		outbreaks_keep(keep_idx) = true;
	end
	new_simulation_table = base_simulation_table(outbreaks_keep, :);

	% Unpack variables for readability
	yr_start = new_simulation_table.yr_start;
	is_false = new_simulation_table.is_false;
	pathogen = new_simulation_table.pathogen;

    % Add surveillance outcomes
    prep_start_month = run_surveillance(new_simulation_table.early_detection_q, ...
										new_simulation_table.is_false, ...
										params.improved_early_warning, ...
										params.months_to_early_detect, ...
										params.months_to_regular_detect);

	% Add R&D success states (convert to string for ismember to avoid categorical/string mismatch across MATLAB versions)
	has_baseline_prototype = ismember(string(pathogen), string(params.pathogens_with_baseline_prototype));
	advance_rd_done = yr_start > params.advance_RD_benefit_start;
	response_initiated = ~is_false | (is_false & ~isnan(prep_start_month));

	% Incorporate advance R&D success states computed in base table into scenario simulation depending on whether it has the invested pathogen.
	has_adv_prototype = false(height(new_simulation_table), 1);
	if ~isempty(params.new_invested_pathogens)
		for i = 1:numel(params.new_invested_pathogens)
			invest_path = params.new_invested_pathogens(i);
			colname = strcat(invest_path, "_prototype_state");
			if ismember(string(colname), string(new_simulation_table.Properties.VariableNames))
				has_adv_prototype = has_adv_prototype | (strcmp(pathogen, invest_path) & new_simulation_table.(colname) & advance_rd_done);
			end
		end
	end

	% Adjust thresholds for RD benefits when research eligible
	trad_idx = strcmp(ptrs_pathogen.platform, "traditional_only");
	mrna_idx = strcmp(ptrs_pathogen.platform, "mrna_only");
	trad_prob_map = dictionary(ptrs_pathogen.pathogen(trad_idx), ptrs_pathogen.ptrs(trad_idx));
	mrna_prob_map = dictionary(ptrs_pathogen.pathogen(mrna_idx), ptrs_pathogen.ptrs(mrna_idx));
	
	% Add PTRS for unknown virus
	trad_prob_map(["unknown_virus", "other_known_virus"]) = min(values(trad_prob_map));
	mrna_prob_map(["unknown_virus", "other_known_virus"]) = min(values(mrna_prob_map));
	trad_prob_map(missing) = NaN;
	mrna_prob_map(missing) = NaN;

	% Only apply R&D benefits after advance_RD_benefit_start years
	trad_increment = prototype_effect_ptrs.effect_mean(prototype_effect_ptrs.platform == "traditional_only");
	mrna_increment = prototype_effect_ptrs.effect_mean(prototype_effect_ptrs.platform == "mrna_only");

	% Sort by (sim_num, pathogen, yr_start) for chronological processing
	[~, sort_idx] = sortrows([new_simulation_table.sim_num, findgroups(pathogen), yr_start]);
	sorted_sim_num = new_simulation_table.sim_num(sort_idx);
	sorted_pathogen = pathogen(sort_idx);
	sorted_has_adv_prototype = has_adv_prototype(sort_idx);
	sorted_has_baseline_prototype = has_baseline_prototype(sort_idx);
	sorted_trad_vax_state = new_simulation_table.trad_vax_state(sort_idx);
	sorted_mrna_vax_state = new_simulation_table.mrna_vax_state(sort_idx);
	sorted_response_initiated = response_initiated(sort_idx);

	% Initial probabilities (baseline + advance prototypes only)
	sorted_trad_probs = trad_prob_map(sorted_pathogen);
	sorted_mrna_probs = mrna_prob_map(sorted_pathogen);
	sorted_trad_probs(sorted_has_adv_prototype) = sorted_trad_probs(sorted_has_adv_prototype) + trad_increment;
	sorted_mrna_probs(sorted_has_adv_prototype) = sorted_mrna_probs(sorted_has_adv_prototype) + mrna_increment;

	% Initial success calculation
	trad_success = (sorted_trad_probs > sorted_trad_vax_state) & response_initiated(sort_idx);
	mrna_success = (sorted_mrna_probs > sorted_mrna_vax_state) & response_initiated(sort_idx);

	% Track prototype acquisition: successful development for non-baseline pathogens
	response_rd_success = trad_success | mrna_success;
	non_id_virus = ismember(string(sorted_pathogen), ["unknown_virus", "other_known_virus"]);

	[grp, ~] = findgroups(sorted_sim_num, sorted_pathogen);

	% Get whether prototype acquired from response
	cond = response_rd_success & ...
		   ~sorted_has_baseline_prototype & ...
		   ~sorted_has_adv_prototype & ...
		   ~non_id_virus;

	% Put into a table and do within-group cummax in-place
	T = table(cond, grp);
	T = grouptransform(T, "grp", @cummax, "cond");
	T = grouptransform(T, "grp", @(x) [false; x(1:end-1)], "cond"); % Shift forward so applies to next outbreak
	prototype_acquired_from_response = T.cond;
	prototype_acquired_from_response(isnan(prototype_acquired_from_response)) = false; % Recode nans when there is no outbreak to false

	% Adjust probabilities for rows that acquire prototype during simulation
	sorted_trad_probs(prototype_acquired_from_response) = sorted_trad_probs(prototype_acquired_from_response) + trad_increment;
	sorted_mrna_probs(prototype_acquired_from_response) = sorted_mrna_probs(prototype_acquired_from_response) + mrna_increment;

	% Recalculate success with updated probabilities
	trad_success(prototype_acquired_from_response) = (...
		(sorted_trad_probs(prototype_acquired_from_response) > sorted_trad_vax_state(prototype_acquired_from_response)) & sorted_response_initiated(prototype_acquired_from_response));
	mrna_success(prototype_acquired_from_response) = (...
		(sorted_mrna_probs(prototype_acquired_from_response) > sorted_mrna_vax_state(prototype_acquired_from_response)) & sorted_response_initiated(prototype_acquired_from_response));

	% Map back to original order
	inv_sort_idx = zeros(size(sort_idx));
	inv_sort_idx(sort_idx) = 1:length(sort_idx);
	trad_success = trad_success(inv_sort_idx);
	mrna_success = mrna_success(inv_sort_idx);
	has_prototype = (has_baseline_prototype | has_adv_prototype | prototype_acquired_from_response(inv_sort_idx));

	% Handle universal flu vaccine investment
	flu_vax_success_prob = trad_prob_map("flu"); % Assume made using traditional platform
	flu_outbreak_idx = strcmp(pathogen, "flu");
	ufv_protection = (...
		params.universal_flu_rd.active & ... % Investment is made
		flu_outbreak_idx & ... % Dealing with influenza
		new_simulation_table.universal_flu_vaccine_state & ... % Investment is successful
		advance_rd_done & ... % Investment is completed
		flu_vax_success_prob > new_simulation_table.ufv_vax_state ... % Vaccine successfully provides protection
	);

	trad_success(flu_outbreak_idx) = trad_success(flu_outbreak_idx) | ufv_protection(flu_outbreak_idx); % Universal vaccine gives you an extra shot at goal with traditional platform

	% When strategy is only to invest in single platform, remove mRNA success when universal flu vaccine is successful
	univ_flu_platform_invest = params.universal_flu_rd.platform_response_invest;
	if params.universal_flu_rd.active && univ_flu_platform_invest == "single"
		mrna_success(flu_outbreak_idx & ufv_protection) = false;
	end
		
	%% Vaccine development timelines

	rd_timeline = nan(height(new_simulation_table), 1);
	rd_timeline(~has_prototype) = params.rd_months_no_prototype;
	rd_timeline(has_prototype) = params.rd_months_with_prototype;
	
	% Ensure all have RD timeline and convert to months
	assert(all(~isnan(rd_timeline)));
	month_response_vaccine_ready = rd_timeline + prep_start_month; % Different timeline for universal flu vaccine and response vaccine

	%% Assign new variables
	new_simulation_table.month_response_vaccine_ready = month_response_vaccine_ready;
	new_simulation_table.prep_start_month = prep_start_month;
	new_simulation_table.response_initiated = response_initiated;
	new_simulation_table.has_prototype = has_prototype;
	new_simulation_table.has_adv_prototype = has_adv_prototype;
	new_simulation_table.prototype_acquired_from_response = prototype_acquired_from_response;
	new_simulation_table.ufv_protection = ufv_protection;

	% Encode non universal vaccine R&D states
	c = rd_state_codes();
	new_simulation_table.rd_state = c.none * ones(size(trad_success));
	new_simulation_table.rd_state(mrna_success & trad_success) = c.both;
	new_simulation_table.rd_state(mrna_success & ~trad_success) = c.mrna;
	new_simulation_table.rd_state(~mrna_success & trad_success) = c.trad;
	new_simulation_table.rd_state(isnan(yr_start)) = nan;

    % Define the categories in order
    rd_state_desc = strings(size(new_simulation_table, 1), 1);

    rd_state_desc(new_simulation_table.rd_state==1) = "both";
    rd_state_desc(new_simulation_table.rd_state==2) = "mRNA_only";
    rd_state_desc(new_simulation_table.rd_state==3) = "trad_only";
    rd_state_desc(new_simulation_table.rd_state==4) = "none";
    rd_state_desc(isnan(new_simulation_table.rd_state)) = "no_pandemic";
    new_simulation_table.rd_state_desc = rd_state_desc;
end


function prep_start_month_arr = run_surveillance(early_detection_q, is_false_arr, ...
												 improved_early_warning, ...
												 months_to_early_detect, months_to_regular_detect)
	% Compute early detection indicator
	early_detect_prob_true = improved_early_warning.recall;
	early_detection = (early_detection_q < early_detect_prob_true .* ~is_false_arr) | is_false_arr;

	prep_start_month_arr = nan(size(is_false_arr));
	prep_start_month_arr(early_detection) = months_to_early_detect;
	prep_start_month_arr(~early_detection) = months_to_regular_detect;
end