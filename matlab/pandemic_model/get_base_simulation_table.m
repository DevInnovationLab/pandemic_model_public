function simulation_table = get_base_simulation_table(severity_dist, duration_dist, viral_family_data, seed, params)

	% Set seed
	rng(seed);

	severity_matrix = severity_dist.get_severity(unifrnd(0, 1, params.num_simulations, params.sim_periods));
	severity_matrix(:, 1) = 0;  % Assume no pandemics in first year so capacity logic works.
	duration_matrix = duration_dist.get_duration(unifrnd(0, 1, params.num_simulations, params.sim_periods));
	duration_matrix(:, 1) = 0; % Assume no pandemics in first year so capacity logic works.
	intensity_matrix = severity_matrix ./ duration_matrix;
	intensity_matrix(duration_matrix == 0) = 0; % No intensity when pandemic has zero duration.
	response_idx = find(intensity_matrix > params.response_threshold); % indicator array for when severity triggers pandemic response
	num_response_scenario = size(response_idx, 1);

	% Plot intensity exceedance
	% Plot intensity here
	intensities_for_plot = sort(intensity_matrix(severity_matrix > severity_dist.min_severity));
	total_draws = params.num_simulations * params.sim_periods;
	[unique_intensities, ~, ic] = unique(intensities_for_plot);
	intensity_counts = histcounts(ic, 1:max(ic)+1); % Count occurrences of each unique intensity
	emp_min_intensity_prob = 1 - sum(intensity_counts) / total_draws;
	cdf = (cumsum(intensity_counts) / sum(intensity_counts)) * (sum(intensity_counts) / total_draws) + emp_min_intensity_prob;
	exceedance = 1 - cdf;

	% Plot the empirical intensity exceedance function
	figure('Visible', 'off');
	plot(unique_intensities, exceedance, 'b-', 'LineWidth', 1.5); % Plot with a blue line
	grid on;
	xlabel('Deaths per 10,000 per year'); % Label for x-axis
	ylabel('Exceedance probability'); % Label for y-axis
	title('Empirical pandemic intensity exceedance function'); % Plot title

	% Customize plot appearance
	set(gca, 'XScale', 'log');
	set(gca, 'FontSize', 11); % Set axis font size
	xlim([min(unique_intensities), max(unique_intensities)]);
    ylim([min(exceedance), max(exceedance)]);

	% Add intensity threshold to figure
	threshold_x = params.response_threshold;
	threshold_y = interp1(unique_intensities, exceedance, threshold_x); % May want to interpolate with a different method

	hold on;
	plot(threshold_x, threshold_y, 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 6);

	% Add dashed lines from the threshold point to the axes
	plot([threshold_x threshold_x], [0 threshold_y], 'r--');  % Vertical line to x-axis
	plot([min(unique_intensities) threshold_x], [threshold_y threshold_y], 'r--');  % Horizontal line to y-axis

	% Add label to the point
	text(threshold_x * 0.95, threshold_y * 0.95, sprintf('Pandemic response\nthreshold: %.2f', threshold_x), ...
		'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', 'FontSize', 8);
	hold off;

	saveas(gcf, fullfile(params.outdirpath, "figures", "empirical_intensity_exceedance_prob.png"))

	% Plotting severity exceedance, do non nan effective severity
	% Same with durations

	% Create table of pandemic scenarios
	sim_num = mod(response_idx - 1, size(severity_matrix, 1)) + 1;
	yr_start = ceil(response_idx / size(severity_matrix, 1));
	severity = severity_matrix(response_idx);
	natural_dur = duration_matrix(response_idx);
	intensity = intensity_matrix(response_idx);
	is_false = rand(num_response_scenario, 1) < params.false_positive_rate;

	viral_family = randsample(viral_family_data.viral_family, num_response_scenario, true, viral_family_data.arrival_share);
	mrna_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	trad_vax_state = unifrnd(0, 1, num_response_scenario, 1);
	yr_end = min(yr_start + natural_dur - 1, params.sim_periods);

	[posterior1, posterior2] = gen_surveil_signals(is_false, params.false_positive_rate);

	% Create table of pandemic scenarios
	response_table = table(sim_num, yr_start, severity, ...
						   is_false, viral_family, ...
						   mrna_vax_state, trad_vax_state, ...
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
		
		% Start pruning procedure if more than one pandemic
		if height(sim_data) > 1
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
