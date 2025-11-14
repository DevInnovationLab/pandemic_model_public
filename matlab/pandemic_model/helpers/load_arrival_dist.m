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

    hyperparams = yaml.loadFile(fullfile(config_path, "hyperparams.yaml"));
    trunc_method = hyperparams.trunc_method;
    measure = hyperparams.measure;

    % Create table with numeric arrays for each parameter
    param_samples = readtable(fullfile(config_path, "param_samples.csv"));

    if ismember('lambda', param_samples.Properties.VariableNames)
        param_samples.p = 1 - exp(-param_samples.lambda);
    elseif ~ismember('p', param_samples.Properties.VariableNames)
        error("Neither 'p' nor 'lambda' found in param_samples.csv.");
    end

    param_samples.max_value = hyperparams.y_max .* ones(size(param_samples, 1), 1);
    param_samples.mu = hyperparams.y_min .* ones(size(param_samples, 1), 1);

    arrival_dist = ArrivalDistSampler(param_samples, trunc_method, false_positive_rate, measure);
end
