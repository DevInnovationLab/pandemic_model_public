function compare_with_estimation_error(job_base, trunc_thresholds)
    % Set up subplots
    num_thresholds = length(trunc_thresholds);
    fig = figure('Position', [100, 100, 1600, 900]);
    
    % Colors for consistent plotting
    est_error_color = [0.8500 0.3250 0.0980];
    mle_color = [0 0.4470 0.7410];
    
    % First row: NPV histograms
    % Initialize table data
    mean_est_error_ann_npv = zeros(num_thresholds, 1);
    mean_mle_values_ann_npv = zeros(num_thresholds, 1);
    percent_diffs = zeros(num_thresholds, 1);
    
    for i = 1:num_thresholds
        threshold = trunc_thresholds(i);
        
        % Get data for this threshold
        [annualized_est_error_npv, annualized_mle_npv] = compare_annualized_npv(job_base, threshold);
        [est_error_severity, mle_severity, est_error_exceedance, mle_exceedance] = compare_exceedance_functions(job_base, threshold);
        
        % Store values for table
        mean_est_error_ann_npv(i) = mean(annualized_est_error_npv)/1e12; % Convert to trillions
        mean_mle_values_ann_npv(i) = mean(annualized_mle_npv)/1e12;
        percent_diffs(i) = 100 * (mean_est_error_ann_npv(i) - mean_mle_values_ann_npv(i)) / mean_mle_values_ann_npv(i);
        
        % NPV histogram subplot
        subplot(2, num_thresholds, i);
        % Calculate common bin edges based on all data
        all_data = [annualized_est_error_npv/1e12; annualized_mle_npv/1e12];
        bin_edges = linspace(min(all_data), max(all_data), 51); % 51 edges = 50 bins
        
        histogram(annualized_est_error_npv/1e12, bin_edges, 'Normalization', 'probability', ...
                'FaceAlpha', 0.6, 'FaceColor', est_error_color, 'DisplayName', 'With estimation error');
        hold on;
        histogram(annualized_mle_npv/1e12, bin_edges, 'Normalization', 'probability', ...
                'FaceAlpha', 0.6, 'FaceColor', mle_color, 'DisplayName', 'MLE only');
        xline(mean(annualized_est_error_npv)/1e12, '--', 'Color', est_error_color, 'DisplayName', 'With estimation error mean');
        xline(mean(annualized_mle_npv)/1e12, '--', 'Color', mle_color, 'DisplayName', 'MLE only mean');
        title(sprintf('Truncation: %d', threshold));
        if i == 1
            ylabel('Probability');
        end
        if i == 1
            legend('Location', 'northeast');
        end
        hold off;
        
        % Second row: Exceedance functions
        subplot(2, num_thresholds, i + num_thresholds);
        plot(est_error_severity, est_error_exceedance, 'LineWidth', 2, 'Color', est_error_color, ...
             'DisplayName', 'With estimation error');
        hold on;
        plot(mle_severity, mle_exceedance, 'LineWidth', 2, 'Color', mle_color, ...
             'DisplayName', 'MLE only');
        set(gca, 'XScale', 'log');
        grid on;
        box off;
        title(sprintf('Truncation: %d', threshold));
        if i == 1
            ylabel('Exceedance probability');
        end
        if i == 1
            legend('Location', 'northeast');
        end
        hold off;
    end
    
    % Create and save comparison table for this job
    comparison_table = table(trunc_thresholds(:), mean_est_error_ann_npv, mean_mle_values_ann_npv, percent_diffs, ...
        'VariableNames', {'truncation', 'ann_npv_est_error', 'ann_npv_mle', 'percent_diff'});
    
    % Save table with job name in filename
    [~, job_name, ~] = fileparts(job_base);
    output_path = sprintf('./output/estimation_error_comparison_%s.csv', job_name);
    writetable(comparison_table, output_path);

    % Add row titles
    annotation('textbox', [0.02 0.91 0.3 0.05], 'String', 'NPV distributions', ...
               'EdgeColor', 'none', 'FontSize', 12, 'FontWeight', 'bold');
    annotation('textbox', [0.02 0.45 0.3 0.05], 'String', 'Exceedance functions', ...
               'EdgeColor', 'none', 'FontSize', 12, 'FontWeight', 'bold');
               
    % Add centered x-labels
    annotation('textbox', [0.35 0.04 0.3 0.05], 'String', 'Expected annual benefits (trillion dollars)', ...
               'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11);
    annotation('textbox', [0.35 0.47 0.3 0.05], 'String', 'Severity (deaths per 10,000)', ...
               'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 11);

    % Add title with spacing
    sgtitle({'Comparison of MLE and estimation error across truncation levels', ''}, ...
            'FontWeight', 'normal', 'FontSize', 13);
            
    print(fig, sprintf('./output/est_error_vs_mle_grid_%s.png', job_base), '-dpng', '-r400');
    
    close all;
end

function [est_error_dir, mle_dir] = get_dirs(job_base, trunc_threshold)
    est_error_dir = sprintf('./output/jobs/%s_%d_dist', job_base, trunc_threshold);
    mle_dir = sprintf('./output/jobs/%s_%d_central', job_base, trunc_threshold);
end

function [annualized_est_error_npv, annualized_mle_npv]= compare_annualized_npv(job_base, trunc_threshold)
    [est_error_dir, mle_dir] = get_dirs(job_base, trunc_threshold);
    job_config = yaml.loadFile(fullfile(est_error_dir, "job_config.yaml")); % Assume job config same other than intensity param samples
    periods = job_config.sim_periods;
    r = job_config.r;

    %% Annualized NPV comparison
    est_error_baseline_npv = readmatrix(fullfile(est_error_dir, "processed", "baseline_absolute_npv.csv"));
    mle_baseline_npv = readmatrix(fullfile(mle_dir, "processed", "baseline_absolute_npv.csv"));

    annualization_factor = (r * (1 + r)^periods) / ((1 + r)^periods - 1);
    annualized_est_error_npv = annualization_factor .* sum(est_error_baseline_npv, 2);
    annualized_mle_npv = annualization_factor .* sum(mle_baseline_npv, 2);
end

function [est_error_severity_sorted, mle_severity_sorted, est_error_exceedance, mle_exceedance] = compare_exceedance_functions(job_base, trunc_threshold)
    [est_error_dir, mle_dir] = get_dirs(job_base, trunc_threshold);
    job_config = yaml.loadFile(fullfile(est_error_dir, "job_config.yaml")); % Assume job config same other than intensity param samples
    num_draws = job_config.sim_periods .* job_config.num_simulations;
    
    est_error_sim_results = readtable(fullfile(est_error_dir, "raw", "baseline_pandemic_table.csv"));
    mle_sim_results = readtable(fullfile(mle_dir, "raw", "baseline_pandemic_table.csv"));

    % Get and sort severities from simulations
    est_error_severity_sorted = sort(est_error_sim_results.ex_post_severity);
    mle_severity_sorted = sort(mle_sim_results.ex_post_severity);

    % Calculate exceedance probabilities separately for each dataset
    est_error_exceedance = (height(est_error_severity_sorted):-1:1)' / num_draws;
    mle_exceedance = (height(mle_severity_sorted):-1:1)' / num_draws;
end