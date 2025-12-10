function plot_base_simulation_table_diagnostics(base_simulation_table, figure_path, job_config)

    % Pandemics per simulation histogram
    h = histogram(base_simulation_table.eff_severity, 'Visible', 'off');
    counts = h.Values / job_config.num_simulations;
    midpoints = h.BinEdges(1:end-1) + diff(h.BinEdges) / 2;
    average_simulation_hist = figure('Visible', 'off');
    bar(midpoints, counts);
    xlabel("Effective severity");
    ylabel("Average number of pandemics per simulation (200 years)");
    title("Histogram of pandemic severities for average simulation");
    saveas(average_simulation_hist, fullfile(figure_path, "average_simulation_hist.jpg"));

    % Ex post severity exceedance function
    ex_post_severity_fig = figure('Visible', 'off');
    total_draws = job_config.num_simulations * job_config.sim_periods;
    [unique_severities, ~, ic] = unique(sort(base_simulation_table.severity));
    severity_counts = histcounts(ic, 1:max(ic)+1); % Count occurrences of each unique intensity
    emp_min_severity_prob = 1 - sum(severity_counts) / total_draws;
    cdf = (cumsum(severity_counts) / sum(severity_counts)) * (sum(severity_counts) / total_draws) + emp_min_severity_prob;
    exceedance = 1 - cdf;

    plot(unique_severities, exceedance, 'b-', 'LineWidth', 1.5); % Plot with a blue line
    grid on;
    xlabel('Deaths per 10,000'); % Label for x-axis
    ylabel('Exceedance probability'); % Label for y-axis
    title('Ex post severity exceedance function'); % Plot title

    % Customize plot appearance
    set(gca, 'XScale', 'log');
    set(gca, 'FontSize', 11); % Set axis font size

    saveas(ex_post_severity_fig, fullfile(figure_path, "ex_post_severity_exceedance.jpg"))

    % Plot duration distribution
    plot_duration_distributions(base_simulation_table, figure_path, false); % No clipped durations

    dur_severity_scatterhist = figure('Visible', 'off');
    subplot(2, 2, 3);  % Bottom-left position for scatter plot
    scatterhist(base_simulation_table.actual_dur, base_simulation_table.eff_severity, ...
        'Kernel', 'on', 'Location', 'SouthEast');
    xlabel('Actual duration (years)');
    ylabel('Effective severity (deaths / 10,000)');
    title('Effective severity vs pandemic duration');
    grid on;
    
    saveas(dur_severity_scatterhist, fullfile(figure_path, "dur_severity_scatterhist.jpg"))

    % 3d histogram of effective duration and severity
    severity_dur_hist = figure('Visible', 'off');
    histogram2(base_simulation_table.eff_severity, base_simulation_table.actual_dur, 'Normalization', 'probability');
    view(3);
    view(129, 28);
    xlabel("Actual severity (Deaths per 1,0000)");
    ylabel("Actual duration (years)");
    zlabel("Probability");
    title("Realized pandemic severity and duration histogram");
    saveas(severity_dur_hist, fullfile(figure_path, 'dur_severity_histogram.jpg'));
end