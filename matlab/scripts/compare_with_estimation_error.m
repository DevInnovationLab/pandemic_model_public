function compare_with_estimation_error()
    est_error_dir = fullfile('./output/jobs/allrisk_base_event_sim');
    mle_dir = fullfile('./output/jobs/allrisk_base_event_sim_mle');

    job_config = yaml.loadFile(fullfile(est_error_dir, "job_config.yaml")); % Assuming configs only vary in intensity distribution.
    periods = job_config.sim_periods;
    r = job_config.r;

    %% Annualized NPV comparison
    est_error_baseline_npv = readmatrix(fullfile(est_error_dir, "processed", "baseline_absolute_npv.csv"));
    mle_baseline_npv = readmatrix(fullfile(mle_dir, "processed", "baseline_absolute_npv.csv"));

    annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);

    annualized_est_error_npv = annualization_factor .* sum(est_error_baseline_npv, 2);
    annualized_mle_npv = annualization_factor .* sum(mle_baseline_npv, 2);

    mean_annualized_est_error_npv = mean(annualized_est_error_npv);
    mean_annualized_mle_np = mean(annualized_mle_npv);

    % Create histogram comparing distributions
    figure('Position', [100, 100, 800, 600]);
    histogram(annualized_est_error_npv / 1e12, 100, 'Normalization', 'probability', ...
            'DisplayName', 'With estimation error', ...
            'FaceAlpha', 0.6, 'FaceColor', [0.8500 0.3250 0.0980]);
    hold on;
    histogram(annualized_mle_npv / 1e12, 100, 'Normalization', 'probability', ...
            'DisplayName', 'MLE only', ...
            'FaceAlpha', 0.6, 'FaceColor', [0 0.4470 0.7410]);
    xline(mean_annualized_est_error_npv / 1e12, '--', 'Color', [0.8500 0.3250 0.0980], ...
          'DisplayName', 'Mean with estimation error');
    xline(mean_annualized_mle_np / 1e12, '--', 'Color', [0 0.4470 0.7410], ...
          'DisplayName', 'Mean MLE only');
    hold off;

    % Add labels and title
    xlabel('Expected annual benefits (trillion dollars)');
    ylabel('Probability');
    title('Distribution of expected annual benefits from baseline program');
    legend('Location', 'northeast');

    % Save figure
    saveas(gcf, './output/estimation_error_comparison.png');
    close(gcf);

    %% Ex post exceedance function comparison
    num_draws = job_config.num_simulations .* periods;
    
    est_error_sim_results = readtable(fullfile(est_error_dir, "raw", "baseline_pandemic_table.csv"));
    mle_sim_results = readtable(fullfile(mle_dir, "raw", "baseline_pandemic_table.csv"));

    % Get severities from simulations
    est_error_ex_post_severity = est_error_sim_results.ex_post_severity;
    mle_ex_post_severity = mle_sim_results.ex_post_severity;

    % Sort severities separately
    est_error_severity_sorted = sort(est_error_ex_post_severity);
    mle_severity_sorted = sort(mle_ex_post_severity);

    % Calculate exceedance probabilities
    est_error_exceedance = (height(est_error_severity_sorted):-1:1)' / num_draws;
    mle_exceedance = (height(mle_severity_sorted):-1:1)' / num_draws;

    % Create figure with appropriate size and style
    fig = figure('Position', [100 100 800 600]);
    hold on;

    % Plot exceedance functions
    est_error_color = [0.8500 0.3250 0.0980];
    mle_color = [0 0.4470 0.7410];

    plot(est_error_severity_sorted, est_error_exceedance, 'LineWidth', 2, 'Color', est_error_color, ...
        'DisplayName', 'With estimation error');
    plot(mle_severity_sorted, mle_exceedance, 'LineWidth', 2, 'Color', mle_color, ...
        'DisplayName', 'MLE only');

    % Customize plot appearance
    set(gca, 'XScale', 'log');
    grid on;
    box off;

    % Add labels and title
    xlabel('Severity (Deaths per 10,000)', 'FontSize', 12);
    ylabel('Exceedance Probability', 'FontSize', 12);
    title('Ex post exceedance function comparison', 'FontSize', 16, 'FontWeight', 'normal');

    % Add direct labels to lines
    sorted_est_error = sort(est_error_severity_sorted);
    sorted_mle = sort(mle_severity_sorted);
    
    text(sorted_est_error(60000), est_error_exceedance(60000), 'With estimation error', ...
        'FontSize', 11, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
        'Color', est_error_color);
    text(sorted_mle(20000), mle_exceedance(20000), 'MLE only', ...
        'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
        'Color', mle_color);

    % Remove legend since we're using direct labels
    legend('off');

    % Set axis limits based on all data
    xlim([min([est_error_severity_sorted; mle_severity_sorted]) ...
        max([est_error_severity_sorted; mle_severity_sorted])]);
        
    print(fig, fullfile('./output/estimation_error_exceedance_comparison.png'), '-dpng', '-r400');
    close(fig);

end