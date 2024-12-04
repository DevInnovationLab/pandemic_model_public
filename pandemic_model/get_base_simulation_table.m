function simulation_table = get_base_simulation_table(arrival_dist, duration_dist, viral_family_data, params)

	severity_matrix = arrival_dist.get_severity(unifrnd(0, 1, params.num_simulations, params.sim_periods));
	severity_matrix(:, 1) = 0; % Assume no pandemics in first year. Does that mean we should extend simulation by one year?
	duration_matrix = duration_dist.get_duration(unifrnd(0, 1, params.num_simulations, params.sim_periods));
	duration_matrix(:, 1) = 0; % Assume no pandemics in first year. Does that mean we should extend simulation by one year?
	intensity_matrix = severity_matrix ./ duration_matrix;
	intensity_matrix(isnan(intensity_matrix)) = 0; % Fix zero / zero division.
	response_idx = find(intensity_matrix > params.response_threshold); % indicator array for when severity triggers pandemic response
	num_response_scenario = size(response_idx, 1);

	% Create table of pandemic scenarios
	sim_num = mod(response_idx - 1, size(severity_matrix, 1)) + 1;
	yr_start = ceil(response_idx / size(severity_matrix, 1));
	severity = severity_matrix(response_idx);
	natural_dur = duration_matrix(response_idx);
	intensity = intensity_matrix(response_idx);
	
	if params.include_false_positives == 1
		is_false = draw_is_false < unifrnd(0, 1, row_cnt, 1);
	else
		is_false = false(num_response_scenario, 1);
	end

	pathogen_family = randsample(viral_family_data.viral_family, num_response_scenario, true, viral_family_data.arrival_share);
	rd_state = unifrnd(0, 1, num_response_scenario, 1); % Create a column of random variable to denote if RD successful (if there is RD)
	yr_end = min(yr_start + natural_dur - 1, params.sim_periods);

	[posterior1, posterior2] = gen_surveil_signals(is_false);

	% Create table of pandemic scenarios
	response_table = table(sim_num, yr_start, severity, ...
						   is_false, pathogen_family, rd_state, ...
						   natural_dur, posterior1, posterior2, ...
						   intensity, yr_end);

	% Address overlapping pandemics
	% Ensure parallel processing is enabled
	disp("Pruning overlapping pandemics...");
	if isempty(gcp('nocreate'))
		parpool; % Create a parallel pool if not already available
	end

	response_table = sortrows(response_table, {'sim_num', 'yr_start'});

	% Initialize a cell array to store pruned simulation data
	sim_nums = unique(response_table.sim_num);
	pruned_data = cell(length(sim_nums), 1);

	% Parallel loop over each simulation number
	parfor sim_idx = 1:length(sim_nums)
		sim_num = sim_nums(sim_idx);  % Get the current simulation number
		
		% Extract rows corresponding to the current simulation number
		sim_data = response_table(response_table.sim_num == sim_num, :);
		
		% Start pruning for the current simulation
		i = 2;  % Start from the second row
		while i <= height(sim_data)
			% Check if the current pandemic overlaps with the previous one
			if sim_data.yr_start(i) <= sim_data.yr_end(i-1)
				% If the current pandemic has a smaller intensity than the previous one, remove it
				if sim_data.intensity(i) < sim_data.intensity(i-1)
					sim_data(i, :) = [];  % Remove the smaller pandemic
					continue;  % Skip to the next row (which has shifted)
				else
					% If the current pandemic is more intense, snip the previous one
					sim_data.yr_end(i-1) = sim_data.yr_start(i) - 1;  % Snip the previous pandemic
				end
			end
			% Move to the next row
			i = i + 1;
		end

		% Store the pruned data for this simulation in the cell array
		pruned_data{sim_idx} = sim_data;
	end

	% After pruning, update the response table with all pruned simulations
	pruned_table = vertcat(pruned_data{:});
	response_table = pruned_table;

	delete(gcp);  % Close the parallel pool once all work is done
	disp("Done.");

	% Get effective severity
	% Effective severity is severity after snipping pandemics
	response_table.actual_dur = response_table.yr_end - response_table.yr_start + 1;
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
