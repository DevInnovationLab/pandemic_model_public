function simulation_table = get_base_simulation_table(arrival_dist, duration_dist, viral_family_data, params)

	severity_matrix = arrival_dist.get_severity(unifrnd(0, 1, params.num_simulations, params.sim_periods));
	severity_matrix(:, 1) = 0; % Assume no pandemics in first year. Does that mean we should extend simulation by one year?
	response_idx = find(severity_matrix > params.response_threshold); % indicator array for when severity triggers pandemic response
	num_response_scenario = size(response_idx, 1);

	% Create table of pandemic scenarios
	sim_num = mod(response_idx - 1, size(severity_matrix, 1)) + 1;
	yr_start = ceil(response_idx / size(severity_matrix, 1));
	severity = severity_matrix(response_idx);
	
	if params.include_false_positives == 1
		is_false = draw_is_false < unifrnd(0, 1, row_cnt, 1);
	else
		is_false = false(num_response_scenario, 1);
	end

	pathogen_family = randsample(viral_family_data.viral_family, num_response_scenario, true, viral_family_data.arrival_share);
	rd_state = unifrnd(0, 1, num_response_scenario, 1); % Create a column of random variable to denote if RD successful (if there is RD)
	natural_dur = duration_dist.get_duration(unifrnd(0, 1, num_response_scenario, 1));
	intensity = severity ./ natural_dur; % Problem if dividing by zero
	yr_end = min(yr_start + natural_dur - 1, params.sim_periods);

	[posterior1, posterior2] = gen_surveil_signals(is_false);

	% Create table of pandemic scenarios
	response_table = table(sim_num, yr_start, severity, ...
						   is_false, pathogen_family, rd_state, ...
						   natural_dur, posterior1, posterior2, ...
						   intensity, yr_end);

	% Address overlapping pandemics
	response_table = sortrows(response_table, {'sim_num', 'yr_start'});
	
	% Identify overlapping pandemics
	% Note: actually have to do sequentially, you may be throwing out more than you want.
	same_simulation = [false; response_table.sim_num(2:end) == response_table.sim_num(1:(end-1))];
	is_overlapping = same_simulation & ...
		[false; response_table.yr_start(2:end) <= response_table.yr_end(1:(end-1))]; % Next pandemic starts before previous over

	% Remove pandemics that are smaller than ongoing one
	smaller_outbreak = is_overlapping & [false; response_table.intensity(2:end) <= response_table.intensity(1:(end-1))];
	response_table = response_table(~smaller_outbreak, :);
	is_overlapping = is_overlapping(~smaller_outbreak);

	% Snip current pandemic if new pandemic is more intense
	% Make sam sim and is overlapping index first one rather than subsequent one now
	same_simulation = [response_table.sim_num(2:end) == response_table.sim_num(1:(end-1)); false; ];
	is_overlapping = same_simulation & ...
		[response_table.yr_start(2:end) <= response_table.yr_end(1:(end-1)); false; ]; % Next pandemic starts before previous over
	next_bigger = is_overlapping & [response_table.intensity(1:(end-1)) <= response_table.intensity(2:end); false];
	response_table.yr_end(next_bigger) = response_table.yr_start([false; next_bigger(1:(end-1))]) - 1; % Snip before start of next pandemic

	% Get effective severity
	response_table.actual_dur = response_table.yr_end - response_table.yr_start + 1;

	temp = response_table(1:100, :);
	temp(temp.actual_dur > temp.natural_dur, :)

	response_table.eff_severity = response_table.severity .* (response_table.actual_dur ./ response_table.natural_dur);

    % Add rows for simulations without pandemics
    all_sims = 1:params.num_simulations;
    no_pandemic_sims = setdiff(all_sims, response_table.sim_num);
    
    % Create a table for simulations without pandemics
    no_response_table = array2table(nan(length(no_pandemic_sims), width(response_table)), 'VariableNames', response_table.Properties.VariableNames);
    no_response_table.sim_num = no_pandemic_sims(:);
    
    % Combine the original response_table with the no_pandemic_table and sort
    simulation_table = sortrows([response_table; no_response_table], {'sim_num', 'yr_start'});

end

