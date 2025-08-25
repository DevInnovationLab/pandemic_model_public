function fig = plot_empirical_intensity_exceedance(intensity_matrix, condition_matrix, lower_bound, params)
    % Plot intensity exceedance function with response threshold
    %
    % Args:
    %   intensity_matrix: Matrix of pandemic intensities
    %   condition_matrix: Matrix to use to decide which pandemics are above the exceedance threshold.
    %   lower_bound: lower_bound for threshold exceeding events
    %   params: Parameter struct containing response threshold and output paths
    
    intensities_for_plot = sort(intensity_matrix(condition_matrix > lower_bound));
    
    % Calculate exceedance probabilities
    total_draws = params.num_simulations * params.sim_periods;
    [unique_intensities, ~, ic] = unique(intensities_for_plot);
    intensity_counts = histcounts(ic, 1:max(ic)+1);
    emp_min_intensity_prob = 1 - sum(intensity_counts) / total_draws;
    cdf = (cumsum(intensity_counts) / sum(intensity_counts)) * (sum(intensity_counts) / total_draws) + emp_min_intensity_prob;
    exceedance = 1 - cdf;

    % Create and customize plot
    fig = figure('Visible', 'off');
    plot(unique_intensities, exceedance, 'b-', 'LineWidth', 1.5);
    grid on;
    box off;
    xlabel('Deaths per 10,000 per year');
    ylabel('Exceedance probability'); 
    title('Simulated pandemic intensity exceedance function');

    set(gca, 'XScale', 'log');
    set(gca, 'FontSize', 11);
    xlim([min(unique_intensities), max(unique_intensities)]);
    ylim([min(exceedance), max(exceedance)]);

    % Add threshold point and lines
    threshold_x = params.response_threshold;
    threshold_y = interp1(unique_intensities, exceedance, threshold_x);

    hold on;
    plot(threshold_x, threshold_y, 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
    plot([threshold_x threshold_x], [0 threshold_y], 'r--');
    plot([lower_bound, threshold_x], [threshold_y threshold_y], 'r--');

    text(threshold_x * 0.95, threshold_y * 0.95, sprintf('Pandemic response\nthreshold: %.2f', threshold_x), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', 'FontSize', 8);
    hold off;
end