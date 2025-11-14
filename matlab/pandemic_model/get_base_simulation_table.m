function [simulation_table, total_removed, total_trimmed] = get_base_simulation_table(arrival_dist, duration_dist, arrival_rates, pathogen_info, seed, params)
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
	
	response_idx = find(intensity_matrix > params.response_threshold); % indicator array for when severity triggers pandemic response
	num_response_scenario = size(response_idx, 1);

	% Plot empirical intensity exceedance
	if strcmp(arrival_dist.measure, 'severity')
		condition_matrix = severity_matrix;
		lower_bound = min(arrival_dist.param_samples.mu) ./ duration_dist.max_duration;
	elseif strcmp(arrival_dist.measure, 'intensity')
		condition_matrix = intensity_matrix;
		lower_bound = min(arrival_dist.param_samples.mu);
	end

	empirical_intensity_exceed_fig = plot_empirical_intensity_exceedance(intensity_matrix, condition_matrix, lower_bound, params);
	saveas(empirical_intensity_exceed_fig, fullfile(params.outdirpath, "figures", "empirical_intensity_exceedance_prob.png"));

	% Create table of pandemic scenarios
	sim_num = mod(response_idx - 1, size(duration_matrix, 1)) + 1;
	yr_start = ceil(response_idx / size(duration_matrix, 1));
	severity = severity_matrix(response_idx);
	natural_dur = duration_matrix(response_idx);
	intensity = intensity_matrix(response_idx);
	is_false = rand(num_response_scenario, 1) < params.false_positive_rate;

	pathogen = randsample(arrival_rates.pathogen, num_response_scenario, true, arrival_rates.estimate);
	mrna_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	trad_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	ufv_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	yr_end = min(yr_start + natural_dur - 1, params.sim_periods);
	early_detection_q = unifrnd(0, 1, num_response_scenario, 1); % Rank for true outbreak probability

	% Create table of pandemic scenarios
	response_table = table(sim_num, yr_start, severity, ...
						   is_false, pathogen, ...
						   mrna_vax_state, trad_vax_state, ufv_vax_state, ...
						   natural_dur, early_detection_q, ...
						   intensity, yr_end);

	% Sort by sim_num and year_start for efficient comparison
	response_table = sortrows(response_table, {'sim_num', 'yr_start'});

	% Shifted vectors for comparison
	prev_sim = [NaN; response_table.sim_num(1:end-1)];
	prev_end = [NaN; response_table.yr_end(1:end-1)];

	% Overlap if same sim_num and previous end >= current start
	is_overlap = (response_table.sim_num == prev_sim) & (prev_end >= response_table.yr_start);
	
	[sim_groups, ~] = findgroups(response_table.sim_num);
	groups_with_overlap = unique(sim_groups(is_overlap));
	rows_with_overlap = ismember(sim_groups, groups_with_overlap);

	% Fast path: rows in non-overlapping groups are kept as-is
	tbl_passthrough = response_table(~rows_with_overlap, :);

	% Indices we need to process
	idx = find(rows_with_overlap);

	% Group IDs for those indices
	[gID, ~] = findgroups(sim_groups(idx));

	% Use splitapply: give it the indices, grouped by gID.
	payloads = splitapply(@(I) local_trim(I, response_table), idx, gID);

	% Stitch results
	tbl_processed = vertcat(payloads.tbl);
	total_removed = sum([payloads.num_removed]);
	total_trimmed = sum([payloads.num_trimmed]);

	% Final table = passthrough + processed (optionally resort if you want)
	tbl_out = [tbl_passthrough; tbl_processed];
	response_table = sortrows(tbl_out, {'sim_num','yr_start'});  % or whatever you need
		
	% Get effective severity
	% Effective severity is severity after snipping pandemics
	response_table.actual_dur = response_table.yr_end - response_table.yr_start + 1;
	response_table.eff_severity = response_table.severity .* (response_table.actual_dur ./ response_table.natural_dur);

    % Create a table for simulations without pandemics
	all_sims = 1:params.num_simulations;
    no_pandemic_sims = setdiff(all_sims, response_table.sim_num);

    no_response_table = table('Size', [length(no_pandemic_sims), width(response_table)], ...
							  'VariableTypes', response_table.Properties.VariableTypes, ...
							  'VariableNames', response_table.Properties.VariableNames);

    % Fill numeric columns with NaN
    numeric_vars = varfun(@isnumeric, response_table, 'OutputFormat', 'uniform');
    numeric_cols = response_table.Properties.VariableNames(numeric_vars);
    no_response_table{:, numeric_cols} = NaN;

    % Fill logical columns with false 
    logical_vars = varfun(@islogical, response_table, 'OutputFormat', 'uniform');
    logical_cols = response_table.Properties.VariableNames(logical_vars);
    no_response_table{:, logical_cols} = false;

    % Fill string/char columns with empty strings
    string_vars = varfun(@isstring, response_table, 'OutputFormat', 'uniform');
    string_cols = response_table.Properties.VariableNames(string_vars);
    no_response_table{:, string_cols} = missing;
    
    % Combine the original response_table with the no_pandemic_table and sort
	no_response_table.sim_num = no_pandemic_sims(:);
    simulation_table = sortrows([response_table; no_response_table], {'sim_num', 'yr_start'});

	% Create advance R&D success states during baseline scenario setting it's constant across scenarios
	pathogens_no_baseline_prototype = string(pathogen_info.pathogen(pathogen_info.has_prototype == 0));
	known_pathogens_no_baseline_prototype = pathogens_no_baseline_prototype(~ismember(pathogens_no_baseline_prototype, ["unknown_virus", "other_known_virus"]));
	
	advance_rd_success_table = table('Size', [height(simulation_table), size(known_pathogens_no_baseline_prototype, 1) + 1], ...
									 'VariableTypes', repmat({'logical'}, 1, size(known_pathogens_no_baseline_prototype, 1) + 1), ...
									 'VariableNames', ['universal_flu_vaccine_state', strcat(known_pathogens_no_baseline_prototype, '_prototype_state')']);

	advance_rd_success_table.universal_flu_vaccine_state = (...
		unifrnd(0, 1, height(advance_rd_success_table), 1) < params.ufv_success_prob);

	for i = 1:size(known_pathogens_no_baseline_prototype, 1)
		advance_rd_success_table.(strcat(known_pathogens_no_baseline_prototype(i), '_prototype_state')) = (...
			unifrnd(0, 1, height(advance_rd_success_table), 1) < params.prototype_success_prob);
	end

	% Combine simulation table and advance R&D success table
	simulation_table = [simulation_table, advance_rd_success_table];
end


function S = local_trim(I, response_table)
    % I: global row indices for one group
    [tbl_i, num_removed, num_trimmed] = trim_overlaps(response_table(I,:));
    S = struct('tbl', tbl_i, ...
               'num_removed', num_removed, ...
               'num_trimmed', num_trimmed);
end


function [tbl, num_removed, num_trimmed] = trim_overlaps(tbl)
% Trim overlapping intervals in a table of pandemic scenarios.
%
% This function sorts the table by yr_start and removes or trims overlapping
% intervals such that, for any overlap, the more intense interval is kept or
% snips the earlier interval. It also returns the number of intervals removed
% (snipped) and the number of intervals trimmed (removed).
%
% Args:
%   tbl: Table with columns 'yr_start', 'yr_end', and 'intensity'.
%
% Returns:
%   tbl: The trimmed, sorted, overlap-free table.
%   num_removed: Number of intervals that were snipped (had their yr_end reduced).
%   num_trimmed: Number of intervals that were removed entirely.

    tbl = sortrows(tbl, 'yr_start');

    n = height(tbl);
    keep = true(n,1);    % rows to keep
    removed = false(n,1);    % rows that were snipped (yr_end changed)
    trimmed = false(n,1);% rows that were removed
    active_idx = 1;      % index of current "active" interval

    for k = 2:n
        % If current interval starts after active ends, update active interval
        if tbl.yr_start(k) > tbl.yr_end(active_idx)
            active_idx = k;
            continue;
        end

        % Current interval overlaps with active interval
        if tbl.intensity(k) > tbl.intensity(active_idx)
            % Current interval stronger: make active interval end before current starts
            trimmed(active_idx) = true;
            tbl.yr_end(active_idx) = tbl.yr_start(k) - 1;
            active_idx = k;  % current becomes new active interval
        else
            % Current interval weaker: remove current interval
            keep(k) = false;
            removed(k) = true;
        end
    end

    % Final slicing
    tbl = tbl(keep,:);
    num_removed = sum(removed);      % Number of intervals removed (among kept)
    num_trimmed = sum(trimmed);      % Number of intervals snipped
end