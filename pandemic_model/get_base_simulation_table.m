function simulation_table = get_base_simulation_table(arrival_dist, viral_family_frequency_table, params)

	severity_matrix = arrival_dist.get_severity(unifrnd(0, 1, params.num_simulations, params.sim_periods));
	severity_matrix(:, 1) = 0; % Assume no pandemics in first year. Does that mean we should extend simulation by one year?
	response_idx = find(severity_matrix > params.response_threshold); % indicator array for when severity triggers pandemic response
	num_response_scenario = size(response_idx, 1);

	% Create table of pandemic resposne scenarios
	sim_num = mod(response_idx - 1, size(severity_matrix, 1)) + 1;
	yr_start = ceil(response_idx / size(severity_matrix, 1));
	severity = severity_matrix(response_idx);
	
	if params.include_false_positives == 1
		is_false = draw_is_false < unifrnd(0, 1, row_cnt, 1);
	else
		is_false = false(num_response_scenario, 1);
	end

	% Create a column of random variable to denote if RD successful (if there is RD)
	viral_family_score = unifrnd(0, 1, num_response_scenario, 1); 
	pathogen_family  = map_RD_score_to_pathogen_family(viral_family_score, viral_family_frequency_table);
	rd_state       = unifrnd(0, 1, num_response_scenario, 1);
	draw_natural_dur = unifrnd(0, 1, num_response_scenario, 1);

	[posterior1, posterior2] = gen_surveil_signals(is_false);

	% Create table of pandemic scenarios
	response_table = table(sim_num, yr_start, severity, ...
						   is_false, pathogen_family, rd_state, ...
						   draw_natural_dur, posterior1, posterior2);

    % Add rows for simulations without pandemics
    all_sims = 1:params.num_simulations;
    no_pandemic_sims = setdiff(all_sims, response_table.sim_num);
    
    % Create a table for simulations without pandemics
    no_response_table = array2table(nan(length(no_pandemic_sims), width(response_table)), 'VariableNames', response_table.Properties.VariableNames);
    no_response_table.sim_num = no_pandemic_sims(:);
    
    % Combine the original response_table with the no_pandemic_table and sort
    simulation_table = sortrows([response_table; no_response_table], {'sim_num', 'yr_start'});

end

