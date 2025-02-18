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
        options.plot_samples (1,1) = 0
        options.visible (1,1) string = 'off'
        options.fig = []
        options.median (1,1) logical = false
        options.mean_linestyle (1,1) string = 'k-'
        options.pctile_linestyle (1,1) string = 'k--'
        options.median_linestyle (1,1) string = 'r-'
        options.pctile_in_legend (1,1) string = 'on'
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
    p05_ts = prctile(data_array, 5, 1);
    p95_ts = prctile(data_array, 95, 1);

    if options.median
        median_ts = median(data_array, 1);
    end

    % Get number of simulations to display
    % Calculate sum of each simulation
    if options.plot_samples > 0
        assert(options.plot_samples < size(data_array, 1))

        if options.cumulative
            sim_sums = data_array(:,end);
        else
            sim_sums = sum(data_array, 2);
        end
        
        % Sort simulations by their sums and get evenly spaced indices
        [~, sorted_indices] = sort(sim_sums);
        sample_indices = round(linspace(1, n_sims, options.plot_samples));
        
        % Select the samples and update n_sims
        plot_sims = data_array(sorted_indices(sample_indices), :);
        n_plot_sims = options.plot_samples;
    end

    % Create figure
    label_varname = convert_varnames(varname);
    if ~isempty(options.fig)
        fig = figure(options.fig);
    else
        fig = figure('Name', strcat(label_varname, " timeseries"), 'Visible', options.visible);
    end
    
    % Plot individual trajectories with low opacity
    hold on
    if options.plot_samples > 0
        line(repmat(years, [n_plot_sims, 1])', plot_sims', ...
            'Color', [0.8 0.8 0.8 0.1], ...
            'LineWidth', 0.5, ...
            'HandleVisibility', 'off', ...
            'LineStyle', '-');
    end
    
    % Plot summary statistics with high opacity
    plot(years, mean_ts, options.mean_linestyle, 'LineWidth', 2, 'DisplayName', 'Mean')
    plot(years, p05_ts, options.pctile_linestyle, 'LineWidth', 1.5, 'DisplayName', '5th percentile', ...
        'HandleVisibility', options.pctile_in_legend)
    plot(years, p95_ts, options.pctile_linestyle, 'LineWidth', 1.5, 'DisplayName', '95th percentile', ...
        'HandleVisibility', options.pctile_in_legend)

    if options.median
        plot(years, median_ts, options.median_linestyle, 'LineWidth', 2, 'DisplayName', 'Median')
    end

    
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
