function fig = plot_ex_ante_severity_exceedance(dist, n, logscale, visible)
    % Plot the ex-ante pandemic severity exceedance function for a severity distribution.
    %
    % Args:
    %   dist      SeverityDist object with .arrival_rate and .get_severity() method.
    %   n         Number of evaluation points (default: 1000).
    %   logscale  If true, use log scale on the x-axis (default: true).
    %   visible   If true, make the figure visible on screen (default: false).
    %
    % Returns:
    %   fig  Figure handle.
    arguments
        dist {mustBeA(dist, 'SeverityDist')}
        n (1,1) {mustBeNumeric} = 1000
        logscale (1,1) {mustBeNumericOrLogical} = true; 
        visible (1, 1) {mustBeNumericOrLogical} = false;
    end

    y = linspace(dist.arrival_rate, 0, n);
    x = dist.get_severity(1 - y);
    fig = figure('Visible', visible);
    plot(x, y, 'LineWidth', 1.5); % Plot the original curve

    if logscale == true
        % Set log scale for both axes
        set(gca, 'XScale', 'log');
    end
    
    % Labels and title
    xlabel('Severity (Deaths / 10,000)', 'FontSize', 12);
    ylabel('Exceedance Probability', 'FontSize', 12);
    title('Pandemic severity exceedance function', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Customize plot appearance
    set(gca, 'FontSize', 11, 'Box', 'off'); % Set axis font size
    xlim([min(x), max(x)]);
    ylim([min(y), max(y)]);
    
    % Display
    hold off;
end