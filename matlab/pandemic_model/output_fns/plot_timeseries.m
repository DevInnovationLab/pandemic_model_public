function fig = plot_timeseries(data_array, varname, options)
    % Plots multiple cumulative time series with summary statistics
    %
    % Args:
    %   data_array: Matrix where rows are simulations and columns are time points
    %   var_name: String name of the variable being plotted
    %   cumulative: whether to display cumulative simulation values
    %   samples: number of simulation lines to display
    %   visible: whether to display plot or not.

    arguments
        data_array (:,:) {mustBeNumeric, mustBeReal}
        varname (1,1) string
        options.cumulative (1,1) logical
        options.samples (1,1) = nan
        options.visible (1,1) string = 'off'
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
    p05_ts = prctile(data_array, 5, 1);
    p95_ts = prctile(data_array, 95, 1);

    % Get number of simulations to display
    if ~isnan(options.samples) && options.samples < n_sims
        % Calculate sum of each simulation
        if options.cumulative
            sim_sums = data_array(:,end);
        else
            sim_sums = sum(data_array, 2);
        end
        
        % Sort simulations by their sums and get evenly spaced indices
        [~, sorted_indices] = sort(sim_sums);
        sample_indices = round(linspace(1, n_sims, options.samples));
        
        % Select the samples and update n_sims
        data_array = data_array(sorted_indices(sample_indices), :);
        n_sims = options.samples;
    end

    % Create figure
    label_varname = convert_varnames(varname);
    fig = figure('Name', strcat(label_varname, " timeseries"), 'Visible', options.visible);
    
    % Plot individual trajectories with low opacity
    hold on
    line(repmat(years, [n_sims, 1])', data_array', ...
         'Color', [0.8 0.8 0.8 0.1], ...
         'LineWidth', 0.5, ...
         'HandleVisibility', 'off', ...
         'LineStyle', '-');
    
    % Plot summary statistics with high opacity
    plot(years, mean_ts, 'b-', 'LineWidth', 2, 'DisplayName', 'Mean')
    plot(years, median_ts, 'r-', 'LineWidth', 2, 'DisplayName', 'Median')
    plot(years, p05_ts, 'k--', 'LineWidth', 1.5, 'DisplayName', '5th percentile')
    plot(years, p95_ts, 'k--', 'LineWidth', 1.5, 'DisplayName', '95th percentile')
    
    % Add labels and title
    plot_title = label_varname;
    if options.cumulative
        plot_title = strcat("Cumulative ", plot_title);
    end

    xlabel('Year')
    ylabel(label_varname)
    title(plot_title)
    legend('show')
    
    hold off
end
