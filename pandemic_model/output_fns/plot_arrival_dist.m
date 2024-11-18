function fig = plot_arrival_dist(dist, severity_response_threshold, n, logscale)
    arguments
        dist {mustBeA(dist, 'ArrivalDist')}
        severity_response_threshold (1,1) {mustBeNumeric}
        n (1,1) {mustBeNumeric} = 1000
        logscale (1,1) {mustBeNumericOrLogical} = true; 
    end

    y = linspace(dist.min_severity_exceed_prob, 0, n);
    x = dist.get_severity(1 - y);

    % Find the point corresponding to the severity response threshold
    threshold_x = severity_response_threshold;
    threshold_y = 1 - dist.get_severity_rank(severity_response_threshold);

    fig = figure;
    plot(x, y, 'LineWidth', 1.5); % Plot the original curve

    if logscale == true
        % Set log scale for both axes
        set(gca, 'XScale', 'log');
    end
    
    % Labels and title
    xlabel('Severity (Deaths / 10,000)', 'FontSize', 12);
    ylabel('Exceedance Probability', 'FontSize', 12);
    title('Severity vs. Exceedance Probability', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Customize plot appearance
    set(gca, 'FontSize', 11); % Set axis font size
    xlim([min(x), max(x)]);
    ylim([min(y), max(y)]);
    
    % Plot the threshold point with a red marker
    hold on;
    plot(threshold_x, threshold_y, 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 6);

    % Add dashed lines from the threshold point to the axes
    plot([threshold_x threshold_x], [0 threshold_y], 'r--');  % Vertical line to x-axis
    plot([min(x) threshold_x], [threshold_y threshold_y], 'r--');  % Horizontal line to y-axis
    
    % Add label to the point
    text(threshold_x * 0.95, threshold_y * 0.95, sprintf('Pandemic response threshold: %.2f', severity_response_threshold), ...
         'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', 'FontSize', 10);
    
    % Display
    hold off;
end