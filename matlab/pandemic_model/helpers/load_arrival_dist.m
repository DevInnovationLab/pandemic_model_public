function arrival_dist = load_arrival_dist(config_path, false_positive_rate)
    % Load arrival distribution from YAML config file into MEVD object
    %
    % Parameters:
    %   config_path - Path to YAML config file containing arrival distribution parameters
    %   false_positive_rate - False positive rate
    %
    % Returns:
    %   arrival_dist - MEVD object representing the arrival distribution
    
    arguments
        config_path (1,1) string
        false_positive_rate (1,1) double
    end

    config = yaml.loadFile(config_path);
    trunc_method = string(config.hyperparams.trunc_method);
    measure = string(config.hyperparams.measure);

    % Create table with numeric arrays for each parameter
    xi = cell2mat(config.param_samples.xi);
    sigma = cell2mat(config.param_samples.sigma);
    p = cell2mat(config.param_samples.p);
    mu = cell2mat(config.param_samples.mu);
    max_value = cell2mat(config.param_samples.max_value);
    param_samples = table(xi, sigma, p, mu, max_value, 'VariableNames', ["xi", "sigma", "p", "mu", "max_value"]);

    arrival_dist = ArrivalDistSampler(param_samples, trunc_method, false_positive_rate, measure);
end
