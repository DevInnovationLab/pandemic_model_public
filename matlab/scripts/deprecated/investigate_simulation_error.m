function investigate_simulation_error(job_config_path)
    % This script implements a simple test to understand sample size we need to get small simulation error.

    job_config = yaml.loadFile(job_config_path);

     % Handle folderpath input for scenario configs
     if isfolder(job_config.scenario_configs)
        scenario_config_paths = dir(fullfile(job_config.scenario_configs, '*.yaml'));
    elseif isfile(job_config.scenario_configs)
        scenario_config_paths = dir(fullfile(job_config.scenario_configs));
    else
        print("Improper scenario config")
    end

    % Clean scenario configs
    scenario_configs = cell(length(scenario_config_paths), 1);
    for i = 1:length(scenario_config_paths)
        scenario_config_path = fullfile(scenario_config_paths(i).folder, scenario_config_paths(i).name);
        scenario_config = yaml.loadFile(scenario_config_path);
        scenario_configs{i} = clean_scenario_config(scenario_config);
        [~, scenario_name, ~] = fileparts(scenario_config_path);
        scenario_configs{i}.name = scenario_name;
    end

    % Get the highest false positive rate to inflate pandemic arrivals
    highest_false_positive_rate = 0;
    for i = 1:length(scenario_configs)
        scenario_improved_early_warning = scenario_configs{i}.improved_early_warning;
        scenario_false_positive_rate = scenario_improved_early_warning.active .* (1 - scenario_improved_early_warning.precision);
        if scenario_false_positive_rate > highest_false_positive_rate
            highest_false_positive_rate = scenario_false_positive_rate;
        end
    end
    job_config.highest_false_positive_rate = highest_false_positive_rate;

    % Load inputs from files
    arrival_dist = load_arrival_dist(job_config.arrival_dist_config, highest_false_positive_rate);
    duration_dist = load_duration_dist(job_config.duration_dist_config);
    arrival_rates = readtable(job_config.arrival_rates, "TextType", "string");
    prototype_effect_ptrs = readtable(job_config.prototype_effect_ptrs, "TextType", "string");

    % First let's check how much variation there is in draws based on parameter samples
    boot_share = 2/3;
    tot_params = height(arrival_dist.param_samples);
    boot_n = round(boot_share * tot_params);
    n_boot_iter = 100;  % Number of bootstrap iterations
    
    % Use the same uniform draws across all bootstrap iterations to isolate parameter uncertainty
    % Use independent uniform draws for duration and severity to ensure they are independent
    boot_unif_draws = unifrnd(0, 1, [tot_params, 1]);  % For severity samples (full parameter set)
    boot_unif_draws_duration = unifrnd(0, 1, [tot_params, 1]);  % Independent draws for duration (full parameter set)
    
    % Pre-generate Bernoulli draws for arrival rate and probability increase
    % These will be consistent across all bootstrap iterations
    boot_unif_draws_arrival = unifrnd(0, 1, [tot_params, 1]);  % For arrival rate Bernoulli (full parameter set)
    boot_unif_draws_prob_increase = unifrnd(0, 1, [tot_params, 1]);  % For prob increase Bernoulli (full parameter set)
    
    % Store bootstrap samples: each row is a draw, each column is a bootstrap iteration
    boot_samples_all = zeros(boot_n, n_boot_iter);
    
    for i = 1:n_boot_iter
        boot_idx = randsample(1:tot_params, boot_n, true);
        params_boot = arrival_dist.param_samples(boot_idx, :);
        arrival_dist_boot = ArrivalDistSampler(params_boot, ...
                                       arrival_dist.trunc_method, ...
                                       arrival_dist.false_positive_rate, ...
                                       arrival_dist.measure);

        boot_samples_all(:, i) = arrival_dist_boot.get_y_sample(boot_unif_draws(boot_idx));
    end
    
    % Calculate parameter-induced sampling error statistics
    % For each draw position, calculate variation across bootstrap iterations
    boot_means = mean(boot_samples_all, 2);  % Mean across bootstrap iterations for each draw
    boot_stds = std(boot_samples_all, 0, 2);  % Std across bootstrap iterations for each draw
    boot_cvs = boot_stds ./ boot_means;  % Coefficient of variation
    
    % Overall statistics
    mean_cv = mean(boot_cvs(~isinf(boot_cvs) & ~isnan(boot_cvs)));
    median_cv = median(boot_cvs(~isinf(boot_cvs) & ~isnan(boot_cvs)));
    
    % Percentile-based measures: for each draw, get range across bootstraps
    boot_pct_5 = prctile(boot_samples_all, 5, 2);
    boot_pct_95 = prctile(boot_samples_all, 95, 2);
    boot_pct_range = boot_pct_95 - boot_pct_5;
    boot_pct_range_rel = boot_pct_range ./ boot_means;  % Relative range
    
    % Variation in 95th percentile outcomes across bootstrap iterations
    % For each bootstrap iteration, calculate the 95th percentile across all draws
    boot_p95_outcomes = prctile(boot_samples_all, 95, 1);  % 95th percentile for each bootstrap iteration
    p95_mean = mean(boot_p95_outcomes);
    p95_std = std(boot_p95_outcomes);
    p95_cv = p95_std / p95_mean;
    p95_min = min(boot_p95_outcomes);
    p95_max = max(boot_p95_outcomes);
    p95_range = p95_max - p95_min;
    p95_range_rel = p95_range / p95_mean;
    
    % Variation in 99.9th percentile outcomes across bootstrap iterations
    % For each bootstrap iteration, calculate the 99.9th percentile across all draws
    boot_p999_outcomes = prctile(boot_samples_all, 99.9, 1);  % 99.9th percentile for each bootstrap iteration
    p999_mean = mean(boot_p999_outcomes);
    p999_std = std(boot_p999_outcomes);
    p999_cv = p999_std / p999_mean;
    p999_min = min(boot_p999_outcomes);
    p999_max = max(boot_p999_outcomes);
    p999_range = p999_max - p999_min;
    p999_range_rel = p999_range / p999_mean;
    
    % Count of outbreaks at max severity for each bootstrap iteration
    max_severity = arrival_dist.param_samples.max_value(1);  % Assuming all have same max
    boot_max_counts = sum(boot_samples_all == max_severity, 1);  % Count per bootstrap iteration
    max_count_mean = mean(boot_max_counts);
    max_count_std = std(boot_max_counts);
    max_count_min = min(boot_max_counts);
    max_count_max = max(boot_max_counts);
    
    % Summary statistics
    fprintf('\n=== Parameter-Induced Sampling Error Analysis ===\n');
    fprintf('Number of bootstrap iterations: %d\n', n_boot_iter);
    fprintf('Number of draws per iteration: %d\n', boot_n);
    fprintf('Mean coefficient of variation: %.4f\n', mean_cv);
    fprintf('Median coefficient of variation: %.4f\n', median_cv);
    fprintf('Mean relative 90%% range (p5-p95): %.4f\n', mean(boot_pct_range_rel(~isinf(boot_pct_range_rel) & ~isnan(boot_pct_range_rel))));
    fprintf('Median relative 90%% range (p5-p95): %.4f\n', median(boot_pct_range_rel(~isinf(boot_pct_range_rel) & ~isnan(boot_pct_range_rel))));
    
    % Statistics across all draws and bootstraps
    overall_mean = mean(boot_samples_all(:));
    overall_std = std(boot_samples_all(:));
    overall_cv = overall_std / overall_mean;
    fprintf('\nOverall statistics (across all draws and bootstraps):\n');
    fprintf('  Mean: %.4f\n', overall_mean);
    fprintf('  Std: %.4f\n', overall_std);
    fprintf('  CV: %.4f\n', overall_cv);
    
    % Variation in 95th percentile outcomes
    fprintf('\nVariation in 95th percentile outcomes across bootstrap iterations:\n');
    fprintf('  Mean p95: %.4f\n', p95_mean);
    fprintf('  Std p95: %.4f\n', p95_std);
    fprintf('  CV p95: %.4f\n', p95_cv);
    fprintf('  Min p95: %.4f\n', p95_min);
    fprintf('  Max p95: %.4f\n', p95_max);
    fprintf('  Range p95: %.4f\n', p95_range);
    fprintf('  Relative range p95: %.4f\n', p95_range_rel);
    
    % Variation in 99.9th percentile outcomes
    fprintf('\nVariation in 99.9th percentile outcomes across bootstrap iterations:\n');
    fprintf('  Mean p99.9: %.4f\n', p999_mean);
    fprintf('  Std p99.9: %.4f\n', p999_std);
    fprintf('  CV p99.9: %.4f\n', p999_cv);
    fprintf('  Min p99.9: %.4f\n', p999_min);
    fprintf('  Max p99.9: %.4f\n', p999_max);
    fprintf('  Range p99.9: %.4f\n', p999_range);
    fprintf('  Relative range p99.9: %.4f\n', p999_range_rel);
    
    % Variation in count of max severity outbreaks
    fprintf('\nVariation in count of max severity outbreaks across bootstrap iterations:\n');
    fprintf('  Mean count: %.2f\n', max_count_mean);
    fprintf('  Std count: %.2f\n', max_count_std);
    fprintf('  Min count: %d\n', max_count_min);
    fprintf('  Max count: %d\n', max_count_max);
    
    % Store results for potential return or further analysis
    param_error_stats = struct();
    param_error_stats.boot_samples_all = boot_samples_all;
    param_error_stats.boot_means = boot_means;
    param_error_stats.boot_stds = boot_stds;
    param_error_stats.boot_cvs = boot_cvs;
    param_error_stats.mean_cv = mean_cv;
    param_error_stats.median_cv = median_cv;
    param_error_stats.boot_pct_range_rel = boot_pct_range_rel;
    param_error_stats.p95_outcomes = boot_p95_outcomes;
    param_error_stats.p95_mean = p95_mean;
    param_error_stats.p95_std = p95_std;
    param_error_stats.p95_cv = p95_cv;
    param_error_stats.p999_outcomes = boot_p999_outcomes;
    param_error_stats.p999_mean = p999_mean;
    param_error_stats.p999_std = p999_std;
    param_error_stats.p999_cv = p999_cv;
    param_error_stats.max_counts = boot_max_counts;
    param_error_stats.max_count_mean = max_count_mean;
    param_error_stats.max_count_std = max_count_std;

    % Ok this is given me a good amount of confidence in having enough simulations at this level.
    % Now I need to check once we add in the additional margins.
    min_arrival_rate = min(arrival_rates.estimate(arrival_rates.estimate > 0));
    min_prob_increase = min(prototype_effect_ptrs.effect_mean);

    % Preallocate arrays for probability calculations
    boot_max_severity_probs = zeros(n_boot_iter, 1);
    boot_max_duration_probs = zeros(n_boot_iter, 1);
    boot_joint_probs = zeros(n_boot_iter, 1);
    boot_expected_counts = zeros(n_boot_iter, 1);

    for i = 1:n_boot_iter
        boot_idx = randsample(1:tot_params, boot_n, true);
        arrival_params_boot = arrival_dist.param_samples(boot_idx, :);
        arrival_dist_boot = ArrivalDistSampler(arrival_params_boot, ...
                                       arrival_dist.trunc_method, ...
                                       arrival_dist.false_positive_rate, ...
                                       arrival_dist.measure);

        severity_samples_all(:, i) = arrival_dist_boot.get_y_sample(boot_unif_draws(boot_idx));

        duration_params_boot = duration_dist.param_table(boot_idx, :);
        duration_dist_boot = DurationSampler(duration_params_boot);
        
        % Sample durations for this bootstrap iteration (using independent draws, subset by boot_idx)
        duration_samples = duration_dist_boot.get_duration(boot_unif_draws_duration(boot_idx));
        
        % Sample severities for this bootstrap iteration (using independent draws, subset by boot_idx)
        severity_samples = arrival_dist_boot.get_y_sample(boot_unif_draws(boot_idx));
        
        % Count how many samples hit max duration
        % Extract scalar value (all trunc_value entries should be the same)
        max_duration = duration_dist_boot.max_duration;  % Use scalar property
        count_max_duration = sum(duration_samples >= max_duration);
        
        % Count how many samples hit max severity
        % Extract scalar value (all max_value entries should be the same)
        max_severity = arrival_dist_boot.param_samples.max_value(1);  % First element since all are the same
        count_max_severity = sum(severity_samples >= max_severity);
        % Count how many samples hit both max duration AND max severity
        count_joint_max = sum((duration_samples >= max_duration) & (severity_samples >= max_severity));
        
        % Store empirical probabilities from this bootstrap iteration
        boot_max_duration_probs(i) = count_max_duration / boot_n;
        boot_max_severity_probs(i) = count_max_severity / boot_n;
        boot_joint_probs(i) = count_joint_max / boot_n;

        % disp(boot_max_severity_probs(i))
        % disp(boot_max_duration_probs(i))
        % disp(boot_joint_probs(i))
        
        % Use pre-generated uniform draws for Bernoulli random variables, subset by boot_idx
        % This ensures consistency across bootstrap iterations
        arrival_bernoulli = boot_unif_draws_arrival(boot_idx) < min_arrival_rate;
        prob_increase_bernoulli = boot_unif_draws_prob_increase(boot_idx) < min_prob_increase;
        
        % Count samples that hit max severity AND max duration AND arrival AND prob increase
        joint_with_margins = (duration_samples >= max_duration) & ...
                            (severity_samples >= max_severity) & ...
                            arrival_bernoulli & ...
                            prob_increase_bernoulli;
        
        % Calculate joint probability with all margins within the loop
        boot_joint_probs_with_margins(i) = sum(joint_with_margins) / boot_n;
        
        % Expected count is the sum of all successful outcomes
        boot_expected_counts(i) = sum(joint_with_margins);
    end
    
    % Report statistics on joint probabilities and expected counts
    fprintf('\n=== Joint Probability and Expected Counts Across Bootstrap Iterations ===\n');
    fprintf('\nJoint probability (max severity × max duration):\n');
    fprintf('  Mean: %.10f (1 in %.0f)\n', mean(boot_joint_probs), 1/mean(boot_joint_probs));
    fprintf('  Std: %.10f\n', std(boot_joint_probs));
    fprintf('  CV: %.4f\n', std(boot_joint_probs) / mean(boot_joint_probs));
    fprintf('  Min: %.10f (1 in %.0f)\n', min(boot_joint_probs), 1/min(boot_joint_probs));
    fprintf('  Max: %.10f (1 in %.0f)\n', max(boot_joint_probs), 1/max(boot_joint_probs));
    
    % Joint probability including arrival rate and probability increase
    fprintf('\nJoint probability (max severity × max duration × arrival rate × prob increase):\n');
    fprintf('  Mean: %.10f (1 in %.0f)\n', mean(boot_joint_probs_with_margins), 1/mean(boot_joint_probs_with_margins));
    fprintf('  Std: %.10f\n', std(boot_joint_probs_with_margins));
    fprintf('  CV: %.4f\n', std(boot_joint_probs_with_margins) / mean(boot_joint_probs_with_margins));
    fprintf('  Min: %.10f (1 in %.0f)\n', min(boot_joint_probs_with_margins), 1/min(boot_joint_probs_with_margins));
    fprintf('  Max: %.10f (1 in %.0f)\n', max(boot_joint_probs_with_margins), 1/max(boot_joint_probs_with_margins));
    fprintf('\nExpected count in sample of size %d:\n', boot_n);
    fprintf('  Mean: %.4f\n', mean(boot_expected_counts));
    fprintf('  Std: %.4f\n', std(boot_expected_counts));
    fprintf('  CV: %.4f\n', std(boot_expected_counts) / mean(boot_expected_counts));
    fprintf('  Min: %.4f\n', min(boot_expected_counts));
    fprintf('  Max: %.4f\n', max(boot_expected_counts));
    
    fprintf('\nComponent probabilities:\n');
    fprintf('  P(max severity) - Mean: %.6f, Std: %.6f\n', mean(boot_max_severity_probs), std(boot_max_severity_probs));
    fprintf('  P(max duration) - Mean: %.6f, Std: %.6f\n', mean(boot_max_duration_probs), std(boot_max_duration_probs));
    fprintf('  Min arrival rate: %.6f\n', min_arrival_rate);
    fprintf('  Min prob increase: %.6f\n', min_prob_increase);

end