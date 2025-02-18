function severity_dist = load_severity_dist(severity_dist_config_path, false_positive_rate)
    arguments
        severity_dist_config_path (1,1) string
        false_positive_rate (1,1) double
    end

    % Load arrival distribution from YAML
    severity_dist_config = yaml.loadFile(severity_dist_config_path);

    % Adjust minimum severity probability for false positive rate
    min_exceed_prob = severity_dist_config.arrival_rate / (1 - false_positive_rate);
    assert(min_exceed_prob <= 1, "Min exceedance probability cannot be greater than one. False positive rate too high.")

    if strcmpi(severity_dist_config.dist_family, 'TruncatedPareto') % If Truncated Pareto
        params = severity_dist_config.params;
        severity_dist = TPDSeverityDist(params.b, ...
                                        params.c, ...
                                        params.loc, ...
                                        params.scale, ...
                                        min_exceed_prob);
    else
        severity_dist = ParametrizedSeverityDist(severity_dist_config.dist_family, ...
                                                 min_exceed_prob, ...
                                                 severity_dist_config.min_severity, ...
                                                 severity_dist_config.max_severity, ...
                                                 severity_dist_config.params);
    end
end
