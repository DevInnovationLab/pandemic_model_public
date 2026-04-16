function get_difference_from_discretization(run_config_path)
    % Get the difference between the arrival distribution and the discretized distribution
    %
    % Args:
    %   arrival_distribution_path: Path to the arrival distribution

    run_config = yaml.loadFile(run_config_path);
    [~,config_name, ~] = fileparts(run_config_path);
    false_positive_rate = run_config.false_positive_rate;
    sim_years = run_config.sim_periods;
    arrival_distribution = load_arrival_dist(run_config.arrival_dist_config, false_positive_rate);
    
    lambda = arrival_distribution.param_samples.lambda ./ (1 - false_positive_rate);
    exp_outbreak_lost = sim_years .* (lambda - (1 - exp(-lambda)));

    % Plot the distribution of lambda and expected outbreak loss
    outdir = fullfile(run_config.outdir, config_name, "figures");
    if ~exist(outdir, 'dir')
        mkdir(outdir);
    end

    figure;
    subplot(2,1,1);
    histogram(lambda, 'FaceColor', [0.2 0.6 0.8], 'Normalization', 'probability');
    xlabel('\lambda');
    ylabel('Probability');
    title('Distribution of \lambda');

    subplot(2,1,2);
    histogram(exp_outbreak_lost, 'FaceColor', [0.8 0.4 0.4], 'Normalization', 'probability');
    xlabel('Number of outbreaks');
    ylabel('Probability');
    title(['Distribution of expected number of outbreaks' 'lost from discretization']);

    exportgraphics(gcf, fullfile(outdir, 'lambda_and_exp_outbreak_loss.pdf'), ...
        'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
    close(gcf);

end
