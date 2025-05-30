function plot_duration_distributions(base_simulation_table, figure_path, clipped)
    % Plot pandemic duration distributions comparing ex-ante theoretical distribution
    % with realized natural and actual durations from simulations
    %
    % Args:
    %   duration_dist: DurationDist object containing theoretical distribution
    %   base_simulation_table: Table containing simulation results
    %   figure_path: String path to save figure
    %   clipped: whether to include clippped distribution
    
    % Create figure
    fig = figure('Visible', 'off', 'Position', [100 100 800 500]);
    hold on;
    
    % Plot natural duration histogram
    histogram(base_simulation_table.natural_dur, 'Normalization', 'pdf', ...
             'FaceColor', [0.8500 0.3250 0.0980], 'FaceAlpha', 0.6, ...
             'EdgeColor', 'none', 'DisplayName', 'Discretized');
             
    % Plot actual duration histogram
    if clipped
        histogram(base_simulation_table.actual_dur, 'Normalization', 'pdf', ...
                'FaceColor', [0.4940 0.1840 0.5560], 'FaceAlpha', 0.6, ...
                'EdgeColor', 'none', 'DisplayName', 'Discretized + clipped');
    end
    
    % Style the plot
    box off;
    ax = gca;
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    ax.GridAlpha = 0.15;
    ax.LineWidth = 1;
    ax.FontSize = 12;
    ax.TickDir = 'out';
    
    % Remove top and right spines
    ax.XAxis.LineWidth = 1.5;
    ax.YAxis.LineWidth = 1.5;
    ax.Box = 'off';
    
    % Add labels and title
    xlabel('Duration (years)', 'FontSize', 14);
    ylabel('Probability density', 'FontSize', 14);
    title('Pandemic duration distribution', 'FontSize', 16, 'FontWeight', 'normal');
    
    % Add legend
    legend('Location', 'northeast', 'FontSize', 12, 'Box', 'off');
    
    % Save figure
    if clipped
        suffix = "_clipped";
    else
        suffix = "_no_clipped";
    end

    fn = strcat("duration_distributions", suffix, ".jpg");
    saveas(fig, fullfile(figure_path, fn));
    close(fig);
end