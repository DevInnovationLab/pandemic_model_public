function plot_num_outbreaks_per_sim(job_dir)
    % Plot a histogram of the number of outbreaks per simulation for the baseline scenario and save as CSV.
    % Args:
    %   job_dir: Directory containing job configuration and results

    % Load job configuration and scenario names
    raw_dir = fullfile(job_dir, "raw");

    % Prepare output directory for figures and CSV
    figure_dir = fullfile(job_dir, "figures");
    if ~exist(figure_dir, 'dir')
        mkdir(figure_dir);
    end
    
    % Only use the baseline scenario
    scenario = 'baseline';
    S = load(fullfile(raw_dir, sprintf("%s_pandemic_table.mat", scenario)));
    pandemic_table = S.pandemic_table;

    % Count number of outbreaks per simulation efficiently
    % Only count rows with a valid outbreak (yr_start not NaN)
    valid_rows = ~isnan(pandemic_table.yr_start);
    sim_nums = pandemic_table.sim_num(valid_rows);
    num_sims = max(pandemic_table.sim_num);
    num_outbreaks = accumarray(sim_nums, 1, [num_sims, 1], @sum, 0);

    % Plot histogram (probability normalization)
    fig = figure('Color', 'w', 'Position', [200 200 700 500]);
    histogram(num_outbreaks, 'Normalization', 'probability', ...
        'FaceColor', [0.2 0.5 0.8], 'EdgeColor', 'k', 'LineWidth', 1.2);
    xlabel('Number of outbreaks per simulation', 'FontSize', 14, 'FontWeight', 'normal');
    ylabel('Probability', 'FontSize', 14, 'FontWeight', 'normal');
    title('Distribution of outbreaks per simulation: Baseline', ...
        'FontSize', 16, 'FontWeight', 'normal');
    grid on;
    ax = gca;
    ax.GridAlpha = 0.3;
    ax.GridColor = [0.6 0.6 0.6];

    % Save figure
    fig_name = 'num_outbreaks_per_sim_baseline';
    print(fig, fullfile(figure_dir, fig_name), '-dpng', '-r400');
    close(fig);

    % Save histogram data as CSV
    [counts, edges] = histcounts(num_outbreaks, 'Normalization', 'probability');
    bin_centers = edges(1:end-1) + diff(edges)/2;
    T = table(bin_centers(:), counts(:), 'VariableNames', {'num_outbreaks', 'probability'});
    writetable(T, fullfile(job_dir, 'baseline_num_outbreaks_per_sim.csv'));


end