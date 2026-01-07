function arrival_dist = load_arrival_dist(config_path, false_positive_rate, param_range)
    % Load arrival distribution from YAML config file into MEVD object
    %
    % Parameters:
    %   config_path - Path to YAML config file containing arrival distribution parameters
    %   false_positive_rate - False positive rate
    %   param_range - Optional [start_row, end_row] range for loading subset of parameters
    %
    % Returns:
    %   arrival_dist - MEVD object representing the arrival distribution
    
    arguments
        config_path (1,1) string
        false_positive_rate (1,1) double
        param_range (1,2) double = [nan, nan]
    end

    hyperparams = yaml.loadFile(fullfile(config_path, "hyperparams.yaml"));
    trunc_method = hyperparams.trunc_method;
    measure = hyperparams.measure;

    % Load parameter samples, optionally with specified row range
    if all(~isnan(param_range))
        param_samples = readtable(fullfile(config_path, "param_samples.csv"), ...
                                  'Range', sprintf('%d:%d', param_range(1) + 1, param_range(2) + 1), ...
                                  'VariableNamesLine', 1);
    else
        param_samples = readtable(fullfile(config_path, "param_samples.csv"));
    end

    if ismember('lambda', param_samples.Properties.VariableNames)
        param_samples.p = 1 - exp(-param_samples.lambda);
    elseif ~ismember('p', param_samples.Properties.VariableNames)
        error("Neither 'p' nor 'lambda' found in param_samples.csv.");
    end

    param_samples.max_value = hyperparams.y_max .* ones(size(param_samples, 1), 1);
    param_samples.mu = hyperparams.y_min .* ones(size(param_samples, 1), 1);

    arrival_dist = ArrivalDistSampler(param_samples, trunc_method, false_positive_rate, measure);
end
