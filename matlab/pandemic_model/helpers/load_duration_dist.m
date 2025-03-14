function duration_dist = load_duration_dist(config_path)
    arguments
        config_path
    end

    % Load parametrized duration distribution from YAML
    config = yaml.loadFile(config_path);
    duration_dist = ParametrizedDurationDist(config.dist_family, config.params, config.max_duration);

end