function duration_dist = load_duration_dist(config_path)
    arguments
        config_path
    end

    % Load parametrized duration distribution from YAML]
    [~, ~, ext] = fileparts(config_path);

    if strcmp(ext, ".yaml")
        config = yaml.loadFile(config_path);
        duration_dist = ParametrizedDurationDist(config.dist_family, config.params, config.max_duration);
    elseif strcmp(ext, ".csv")
        param_samples = readtable(config_path);
        duration_dist = DurationSampler(param_samples, 10); % Beware that this is hardcoded
    end

end