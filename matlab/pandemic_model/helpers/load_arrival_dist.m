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
    truncation_type = string(config.hyperparams.truncation_type);
    variable = string(config.hyperparams.variable);

    % Create table with numeric arrays for each parameter
    xi = cell2mat(config.dist_params.xi);
    sigma = cell2mat(config.dist_params.sigma);
    p = cell2mat(config.dist_params.p);
    mu = cell2mat(config.dist_params.mu);
    max_value = cell2mat(config.dist_params.max_value);
    dist_params = table(xi, sigma, p, mu, max_value, 'VariableNames', ["xi", "sigma", "p", "mu", "max_value"]);

    arrival_dist = ArrivalDistSampler(dist_params, truncation_type, false_positive_rate, variable);
end
