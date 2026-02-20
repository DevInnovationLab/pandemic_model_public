function [simulation_table, total_removed, total_trimmed] = get_base_simulation_table(arrival_dist, duration_dist, arrival_rates, pathogen_info, seed, chunk_idx, params)
	% Set seed
	rng(seed);

	duration_matrix = duration_dist.get_duration(unifrnd(0, 1, params.num_simulations, params.sim_periods));
	duration_matrix(:, 1) = 0; % Assume no pandemics in first year so capacity logic works.

	if strcmp(arrival_dist.measure, 'severity')
		severity_matrix = arrival_dist.ppf(unifrnd(0, 1, params.num_simulations, params.sim_periods));
		severity_matrix(:, 1) = 0;  % Assume no pandemics in first year so capacity logic works.
		intensity_matrix = severity_matrix ./ duration_matrix;
	elseif strcmp(arrival_dist.measure, 'intensity')
		intensity_matrix = arrival_dist.ppf(unifrnd(0, 1, params.num_simulations, params.sim_periods));
		intensity_matrix(:, 1) = 0;
		severity_matrix = intensity_matrix .* duration_matrix;
	else
		error("Arrival distribution must be assigned variable 'intensity' or severity' to be used for simulation.")
	end

	intensity_matrix(duration_matrix == 0) = 0; % No intensity when pandemic has zero duration.
	
	outbreak_idx = find(intensity_matrix > 0);
	num_response_scenario = size(outbreak_idx, 1);
	
	% Create table of pandemic scenarios
	sim_num = mod(outbreak_idx - 1, size(duration_matrix, 1)) + (chunk_idx - 1) * params.num_simulations + 1;
	yr_start = ceil(outbreak_idx / size(duration_matrix, 1));
	severity = severity_matrix(outbreak_idx);
	natural_dur = duration_matrix(outbreak_idx);
	intensity = intensity_matrix(outbreak_idx);
	is_false = rand(num_response_scenario, 1) < arrival_dist.false_positive_rate;

	% Set intensities, severities, etc, for false positives. Some will get chucked by trim_overlaps.
	severity(is_false) = 0;
	intensity(is_false) = 0;
	natural_dur(is_false) = 1;

	pathogen = randsample(arrival_rates.pathogen, num_response_scenario, true, arrival_rates.estimate);
	pathogen = categorical(pathogen, unique(arrival_rates.pathogen));
	mrna_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	trad_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	ufv_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	yr_end = min(yr_start + natural_dur - 1, params.sim_periods);
	early_detection_q = unifrnd(0, 1, num_response_scenario, 1); % Rank for true outbreak probability

	% Create table of pandemic scenarios
	simulation_table = table(sim_num, yr_start, severity, ...
						   is_false, pathogen, ...
						   mrna_vax_state, trad_vax_state, ufv_vax_state, ...
						   natural_dur, early_detection_q, ...
						   intensity, yr_end);

	% Sort by sim_num and yr_start for single-pass overlap pruning
	simulation_table = sortrows(simulation_table, {'sim_num', 'yr_start'});

	% Single-pass trim of overlapping intervals (reset active when sim_num changes)
	[simulation_table, total_removed, total_trimmed] = trim_overlaps_singlepass(simulation_table);
		
	% Get effective severity
	% Effective severity is severity after snipping pandemics
	simulation_table.actual_dur = simulation_table.yr_end - simulation_table.yr_start + 1;
	simulation_table.eff_severity = simulation_table.severity .* (simulation_table.actual_dur ./ simulation_table.natural_dur);

	% Create advance R&D success states during baseline scenario setting it's constant across scenarios
	pathogens_no_baseline_prototype = string(pathogen_info.pathogen(pathogen_info.has_prototype == 0));
	known_pathogens_no_baseline_prototype = pathogens_no_baseline_prototype(~ismember(pathogens_no_baseline_prototype, ["unknown_virus", "other_known_virus"]));
	
	advance_rd_success_table = table('Size', [height(simulation_table), size(known_pathogens_no_baseline_prototype, 1) + 1], ...
									 'VariableTypes', repmat({'logical'}, 1, size(known_pathogens_no_baseline_prototype, 1) + 1), ...
									 'VariableNames', ['universal_flu_vaccine_state', strcat(known_pathogens_no_baseline_prototype, '_prototype_state')']);


	% Assign advance R&D success states per simulation, then expand to rows
	sim_num_list = 1:max(simulation_table.sim_num);
	universal_flu_vaccine_sim_states = unifrnd(0, 1, numel(sim_num_list), 1) < params.ufv_success_prob;
	advance_rd_success_table.universal_flu_vaccine_state = universal_flu_vaccine_sim_states(simulation_table.sim_num);

	for i = 1:size(known_pathogens_no_baseline_prototype, 1)
		pathogen_col = strcat(known_pathogens_no_baseline_prototype(i), '_prototype_state');
		proto_sim_states = unifrnd(0, 1, numel(sim_num_list), 1) < params.prototype_success_prob;
		advance_rd_success_table.(pathogen_col) = proto_sim_states(simulation_table.sim_num);
	end

	% Combine simulation table and advance R&D success table
	simulation_table = [simulation_table, advance_rd_success_table];

	% Now determine response outbreaks
	response_outbreak_idx = find(simulation_table.intensity > params.response_threshold);
	simulation_table.response_outbreak = false(height(simulation_table), 1);
	simulation_table.response_outbreak(response_outbreak_idx) = true;
end


function [tbl, num_removed, num_trimmed] = trim_overlaps_singlepass(tbl)
% Trim overlapping intervals in one pass over the table (per sim_num).
%
% Table must be pre-sorted by (sim_num, yr_start). For each simulation, overlapping
% intervals are resolved: the more intense interval is kept or trims the earlier one.
%
% Args:
%   tbl: Table with columns 'sim_num', 'yr_start', 'yr_end', and 'intensity'.
%
% Returns:
%   tbl: The trimmed, overlap-free table (same sort order).
%   num_removed: Number of intervals removed entirely (weaker overlap).
%   num_trimmed: Number of intervals snipped (yr_end reduced).
    n = height(tbl);
    if n <= 1
        num_removed = 0;
        num_trimmed = 0;
        return;
    end
    sim_num = tbl.sim_num;
    yr_start = tbl.yr_start;
    yr_end = tbl.yr_end;
    intensity = tbl.intensity;
    keep = true(n, 1);
    removed = false(n, 1);
    trimmed = false(n, 1);
    active_idx = 1;

    for k = 2:n
        % New simulation or no overlap: current becomes active
        if sim_num(k) ~= sim_num(active_idx) || yr_start(k) > yr_end(active_idx)
            active_idx = k;
            continue;
        end
        % Overlap: stronger interval wins; weaker is removed or active is snipped
        if intensity(k) > intensity(active_idx)
            trimmed(active_idx) = true;
            yr_end(active_idx) = yr_start(k) - 1;
            active_idx = k;
        else
            keep(k) = false;
            removed(k) = true;
        end
    end

    tbl.yr_end = yr_end;
    tbl = tbl(keep, :);
    num_removed = sum(removed);
    num_trimmed = sum(trimmed);
end