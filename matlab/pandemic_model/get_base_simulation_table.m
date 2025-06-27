function simulation_table = get_base_simulation_table(arrival_dist, duration_dist, viral_family_data, seed, params)
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
		lower_bound = min(arrival_dist.param_samples.mu) ./ duration_matrix.max_value;
	elseif strcmp(arrival_dist.measure, 'intensity')
		condition_matrix = intensity_matrix;
		lower_bound = min(arrival_dist.param_samples.mu);
	end

	empirical_intensity_exceed_fig = plot_empirical_intensity_exceedance(intensity_matrix, condition_matrix, lower_bound, params);
	saveas(empirical_intensity_exceed_fig, fullfile(params.outdirpath, "figures", "empirical_intensity_exceedance_prob.png"))

	% Create table of pandemic scenarios
	sim_num = mod(response_idx - 1, size(duration_matrix, 1)) + 1;
	yr_start = ceil(response_idx / size(duration_matrix, 1));
	severity = severity_matrix(response_idx);
	natural_dur = duration_matrix(response_idx);
	intensity = intensity_matrix(response_idx);
	is_false = rand(num_response_scenario, 1) < params.false_positive_rate;

	viral_family = randsample(viral_family_data.viral_family, num_response_scenario, true, viral_family_data.arrival_share);
	mrna_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	trad_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	ufv_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	yr_end = min(yr_start + natural_dur - 1, params.sim_periods);

	[posterior1, posterior2] = gen_surveil_signals(is_false, params.false_positive_rate);

	% Create table of pandemic scenarios
	response_table = table(sim_num, yr_start, severity, ...
						   is_false, viral_family, ...
						   mrna_vax_state, trad_vax_state, ufv_vax_state, ...
						   natural_dur, posterior1, posterior2, ...
						   intensity, yr_end);

	% Address overlapping pandemics
	[~, ~, sim_groups] = unique(response_table.sim_num);
	pruned_tables = accumarray(sim_groups, (1:height(response_table))', [], ...
		@(x) {trim_overlaps(response_table(x,:))}); % cell array
	response_table = vertcat(pruned_tables{:}); % final result

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
end


function tbl = trim_overlaps(tbl)
% PRE: tbl has columns yr_start, duration OR yr_end, and intensity.
%      All rows belong to one sim_num and are unsorted.
%
% POST: tbl is sorted, overlap–free, and the earlier interval is snipped
%       if a later, more intense one collides with it.
    tbl = sortrows(tbl, 'yr_start'); % O(n log n)

	n = height(tbl);
    keep = true(n,1);    % rows to keep
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
            tbl.yr_end(active_idx) = tbl.yr_start(k) - 1;
            active_idx = k;  % current becomes new active interval
        else
            % Current interval weaker: remove current interval
            keep(k) = false;
        end
    end

    % Final slicing
    tbl = tbl(keep,:);
end