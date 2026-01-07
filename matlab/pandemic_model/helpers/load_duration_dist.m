function duration_dist = load_duration_dist(config_path, param_range)
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