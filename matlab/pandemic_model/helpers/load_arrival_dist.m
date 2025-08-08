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
    if isfield(config.param_samples, 'p')
        p = cell2mat(config.param_samples.p);
    elseif isfield(config.param_samples, 'lambda')
        lambda = cell2mat(config.param_samples.lambda);
        p = 1 - exp(-lambda);
    else
        error("Neither 'p' nor 'lambda' found in param_samples.");
    end

    xi = cell2mat(config.param_samples.xi);
    sigma = cell2mat(config.param_samples.sigma);
    mu = config.hyperparams.y_min .* ones(size(xi));
    max_value = config.hyperparams.y_max .* ones(size(xi));
    param_samples = table(xi, sigma, p, mu, max_value, 'VariableNames', ["xi", "sigma", "p", "mu", "max_value"]);

    arrival_dist = ArrivalDistSampler(param_samples, trunc_method, false_positive_rate, measure);
end
