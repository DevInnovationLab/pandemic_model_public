function fig = plot_ex_ante_severity_exceedance(dist, n, logscale, visible)
    arguments
        dist {mustBeA(dist, 'ArrivalDist')}
        n (1,1) {mustBeNumeric} = 1000
        logscale (1,1) {mustBeNumericOrLogical} = true; 
        visible (1, 1) {mustBeNumericOrLogical} = false;
    end

    y = linspace(dist.min_severity_exceed_prob, 0, n);
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
    title('Severity vs. Exceedance Probability', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Customize plot appearance
    set(gca, 'FontSize', 11); % Set axis font size
    xlim([min(x), max(x)]);
    ylim([min(y), max(y)]);
    
    % Display
    hold off;
end