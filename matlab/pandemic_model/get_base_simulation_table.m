function [simulation_table, total_removed, total_trimmed] = get_base_simulation_table(arrival_dist, duration_dist, arrival_rates, pathogen_info, seed, chunk_simulations, params)
	% Sample pandemic events from arrival and duration distributions.
	%
	% Draws random severities/intensities and durations for each simulation and year,
	% assembles all matrix outbreaks (including below the response threshold), prunes
	% overlapping intervals, draws false positives only in vacant years, then assigns
	% advance R&D success states (prototype and universal flu vaccine) at the simulation level.
	%
	% Args:
	%   arrival_dist        Arrival distribution object (.ppf, .measure, .false_positive_rate).
	%   duration_dist       Duration distribution object (.get_duration).
	%   arrival_rates       Table of pathogen arrival rates (columns: pathogen, estimate).
	%   pathogen_info       Table with prototype status per pathogen (columns: pathogen, has_prototype).
	%   seed                Random seed for reproducibility.
	%   chunk_simulations   Number of simulations in this chunk.
	%   params              Struct of run parameters. Key fields: sim_periods,
	%                       response_threshold, response_threshold_type,
	%                       ufv_success_prob, prototype_success_prob.
	%
	% Returns:
	%   simulation_table    Table of sampled pandemic events with columns: sim_num,
	%                       yr_start, yr_end, severity, intensity,
	%                       sampled_duration_years, sampled_duration_months,
	%                       calendar_years, harm_months, eff_severity, is_false,
	%                       pathogen, vax states, response_outbreak, and advance R&D
	%                       success columns per non-baseline pathogen.
	%   total_removed       Number of events removed due to overlap (weaker event discarded).
	%   total_trimmed       Number of events snipped due to overlap (yr_end reduced).
	% Set seed
	rng(seed);

	months_matrix = duration_dist.get_duration_months(unifrnd(0, 1, chunk_simulations, params.sim_periods));
	months_matrix = min(months_matrix, params.sim_periods * 12);
	months_matrix(:, 1) = 0; % Assume no pandemics in first year so capacity logic works.
	duration_years = months_matrix ./ 12;

	if strcmp(arrival_dist.measure, 'severity')
		severity_matrix = arrival_dist.ppf(unifrnd(0, 1, chunk_simulations, params.sim_periods));
		severity_matrix(:, 1) = 0;  % Assume no pandemics in first year so capacity logic works.
		intensity_matrix = severity_matrix ./ duration_years;
	elseif strcmp(arrival_dist.measure, 'intensity')
		intensity_matrix = arrival_dist.ppf(unifrnd(0, 1, chunk_simulations, params.sim_periods));
		intensity_matrix(:, 1) = 0;
		severity_matrix = intensity_matrix .* duration_years;
	else
		error("Arrival distribution must be assigned variable 'intensity' or severity' to be used for simulation.")
	end

	% Calculate quantities for threshold and false positives
	resp_threshold_array = ones(chunk_simulations, 1) .* params.response_threshold;
	response_threshold_arrival_rate = -log(arrival_dist.cdf(resp_threshold_array));
	false_pos_multiplier = params.highest_false_positive_rate ./ (1 - params.highest_false_positive_rate);
	false_pos_arrival_rate = response_threshold_arrival_rate * false_pos_multiplier;
	fp_event_prob = 1 - exp(-false_pos_arrival_rate);

	num_sims = size(intensity_matrix, 1);
	num_periods = size(intensity_matrix, 2);

	% Phase 1: all matrix outbreaks, then trim overlapping intervals
	outbreak_idx = find(intensity_matrix > 0);
	sim_num = mod(outbreak_idx - 1, num_sims) + 1;
	yr_start = ceil(outbreak_idx / num_sims);
	severity = severity_matrix(outbreak_idx);
	sampled_duration_months = months_matrix(outbreak_idx);
	sampled_duration_years = sampled_duration_months ./ 12;
	intensity = intensity_matrix(outbreak_idx);
	yr_end = min(yr_start + ceil(sampled_duration_months ./ 12) - 1, params.sim_periods);

	outbreak_table = table(sim_num, yr_start, severity, sampled_duration_years, ...
		sampled_duration_months, intensity, yr_end);
	outbreak_table = sortrows(outbreak_table, {'sim_num', 'yr_start'});
	[outbreak_table, total_removed, total_trimmed] = trim_overlaps_singlepass(outbreak_table);
	outbreak_table.is_false = false(height(outbreak_table), 1);

	% Phase 2: false positives in years below threshold and not covered by any outbreak
	if strcmp(params.response_threshold_type, 'intensity')
		above_thresh = outbreak_table.intensity > params.response_threshold;
	elseif strcmp(params.response_threshold_type, 'severity')
		above_thresh = outbreak_table.severity > params.response_threshold;
	end
	occupied = false(num_sims, num_periods);
	s = outbreak_table.sim_num(above_thresh);
	ys = outbreak_table.yr_start(above_thresh);
	ye = outbreak_table.yr_end(above_thresh);
	for i = 1:numel(s)
		occupied(s(i), ys(i):ye(i)) = true;
	end
	fp_rand = rand(num_sims, num_periods);
	fp_idx = find(~occupied & (fp_rand < fp_event_prob));
	num_fp = numel(fp_idx);

	sim_num = mod(fp_idx - 1, num_sims) + 1;
	yr_start = ceil(fp_idx / num_sims);
	severity = repmat(params.response_threshold, num_fp, 1);
	sampled_duration_years = ones(num_fp, 1);
	sampled_duration_months = sampled_duration_years * 12;
	intensity = severity;
	yr_end = yr_start;
	fp_table = table(sim_num, yr_start, severity, sampled_duration_years, ...
		sampled_duration_months, intensity, yr_end);
	fp_table.is_false = true(num_fp, 1);

	simulation_table = [outbreak_table; fp_table];
	simulation_table = sortrows(simulation_table, {'sim_num', 'yr_start'});

	simulation_table.calendar_years = simulation_table.yr_end - simulation_table.yr_start + 1;
	% Active harm months: sampled length capped by calendar span (incl. overlap trim).
	calendar_months = simulation_table.calendar_years * 12;
	simulation_table.harm_months = min(simulation_table.sampled_duration_months, calendar_months);
	simulation_table.eff_severity = simulation_table.severity .* ...
		(simulation_table.harm_months ./ simulation_table.sampled_duration_months);
	num_events = height(simulation_table);
	simulation_table.pathogen = randsample(arrival_rates.pathogen, num_events, true, arrival_rates.estimate);
	simulation_table.mrna_vax_state = unifrnd(0, 1, num_events, 1);
	simulation_table.trad_vax_state = unifrnd(0, 1, num_events, 1);
	simulation_table.ufv_vax_state = unifrnd(0, 1, num_events, 1);
	simulation_table.early_detection_q = unifrnd(0, 1, num_events, 1);

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

	% Now determine response outbreaks (threshold can be in intensity or severity units)
	if strcmp(params.response_threshold_type, 'intensity')
		response_outbreak_idx = find(simulation_table.intensity >= params.response_threshold);
	elseif strcmp(params.response_threshold_type, 'severity')
		response_outbreak_idx = find(simulation_table.severity >= params.response_threshold);
	else
		error("Unknown response_threshold_type: %s", params.response_threshold_type);
	end
	simulation_table.response_outbreak = false(height(simulation_table), 1);
	simulation_table.response_outbreak(response_outbreak_idx) = true;
end


function [tbl, num_removed, num_trimmed] = trim_overlaps_singlepass(tbl)
% Trim overlapping intervals in one pass over the table (per sim_num).
%
% Table must be pre-sorted by (sim_num, yr_start). For each simulation, overlapping
% intervals are resolved: the more intense interval is kept or trims the earlier one.
%
% Table must be sorted by (sim_num, yr_start) for this to work properly.
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