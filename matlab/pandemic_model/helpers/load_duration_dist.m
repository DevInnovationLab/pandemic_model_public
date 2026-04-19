function duration_dist = load_duration_dist(config_path, param_range)
    % Load a duration distribution from a YAML config or CSV parameter samples.
    %
    % For YAML inputs, constructs a ParametrizedDurationDist with a fixed family and
    % params. For CSV inputs, reads parameter samples (optionally subsetting rows) and
    % constructs a DurationSampler for bootstrapped distributions.
    %
    % Args:
    %   config_path  Path to a .yaml or .csv duration distribution config.
    %   param_range  [1 x 2] Row range [start, end] for CSV sampling (default: read all).
    %
    % Returns:
    %   duration_dist  DurationDist subclass (ParametrizedDurationDist or DurationSampler).
    arguments
        config_path
        param_range (1,2) double = [nan, nan]
    end

    % Load parametrized duration distribution from YAML]
    [~, ~, ext] = fileparts(config_path);

    if strcmp(ext, ".yaml")
        config = yaml.loadFile(config_path);
        duration_dist = ParametrizedDurationDist(config.dist_family, config.params, config.max_duration);
    elseif strcmp(ext, ".csv")
        if all(~isnan(param_range))
            param_samples = readtable(config_path, ...
                                      'VariableNamesLine', 1, ...
                                      'Range', sprintf('%d:%d', param_range(1) + 1, param_range(2) + 1));
        else
            param_samples = readtable(config_path);
        end
        duration_dist = DurationSampler(param_samples); % Beware that this is hardcoded
    end

end