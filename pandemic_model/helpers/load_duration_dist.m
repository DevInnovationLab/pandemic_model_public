function duration_dist = load_duration_dist(config_path)
    arguments
        config_path
    end

    % Load parametrized duration distribution from YAML
    config = yaml.loadFile(config_path); % Can later add min/max durations
    duration_dist = ParametrizedDurationDist(config.dist_family, config.params);

end