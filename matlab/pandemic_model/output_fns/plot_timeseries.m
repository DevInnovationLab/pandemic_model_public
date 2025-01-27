function fig = plot_timeseries(data_array, varname, options)
    % Plots multiple cumulative time series with summary statistics
    %
    % Args:
    %   data_array: Matrix where rows are simulations and columns are time points
    %   var_name: String name of the variable being plotted
    %   options: options

    arguments
        data_array (:,:) {mustBeNumeric, mustBeReal}
        varname (1,1) string
        options.cumulative (1,1) logical
    end
    
    % Get dimensions
    [n_sims, n_timesteps] = size(data_array);
    years = 1:n_timesteps;
    
    % Calculate cumulative data
    if options.cumulative
        data_array = cumsum(data_array, 2);
    end
    
    % Calculate statistics
    mean_ts = mean(data_array, 1);
    median_ts = median(data_array, 1);
    
    % Calculate percentiles based on sum of values
    sim_sums = sum(data_array, 2);
    [~, sort_idx] = sort(sim_sums);
    p05_idx = ceil(0.05 * n_sims);
    p95_idx = floor(0.95 * n_sims);
    p05_ts = data_array(sort_idx(p05_idx), :);
    p95_ts = data_array(sort_idx(p95_idx), :);

    % Create figure
    label_varname = convert_varnames(varname);
    fig = figure('Name', strcat(label_varname, " timeseries"));
    
    % Plot individual trajectories with low opacity
    hold on
    line(repmat(years, [n_sims, 1])', data_array', ...
         'Color', [0.8 0.8 0.8], ...
         'LineWidth', 0.5, ...
         'HandleVisibility', 'off', ...
         'LineStyle', '-', ...
         'Alpha', 0.1);
    
    % Plot summary statistics with high opacity
    plot(years, mean_ts, 'b-', 'LineWidth', 2, 'DisplayName', 'Mean')
    plot(years, median_ts, 'r-', 'LineWidth', 2, 'DisplayName', 'Median')
    plot(years, p05_ts, 'k--', 'LineWidth', 1.5, 'DisplayName', '5th percentile')
    plot(years, p95_ts, 'k--', 'LineWidth', 1.5, 'DisplayName', '95th percentile')
    
    % Add labels and title
    title = label_varname;
    if options.cumulative
        title = strcat("Cumulative ", title);
    end

    xlabel('Year')
    ylabel(label_varname)
    title(title)
    legend('show')
    
    hold off
end
