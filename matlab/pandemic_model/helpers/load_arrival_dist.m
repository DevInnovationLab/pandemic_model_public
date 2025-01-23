function arrival_dist = load_arrival_dist(arrival_dist_config_path, interp_method, loginterp)
    arguments
        arrival_dist_config_path
        interp_method (1, 1) string = "linear"
        loginterp (1, 1) {mustBeNumericOrLogical} = true
    end

    [~, ~, file_ext] = fileparts(arrival_dist_config_path);
    
    if strcmpi(file_ext, '.yaml')
        % Load parametrized arrival distribution from YAML
        arrival_dist_config = yaml.loadFile(arrival_dist_config_path);
        arrival_dist = ParametrizedArrivalDist(arrival_dist_config.dist_family, ...
                                               arrival_dist_config.min_severity_exceed_prob, ...
                                               arrival_dist_config.min_severity, ...
                                               arrival_dist_config.max_severity, ...
                                               arrival_dist_config.params);
    elseif strcmpi(file_ext, '.csv')
        % Load empirical arrival distribution from CSV
        data = readtable(arrival_dist_config_path);
        severity_values = data.severity;
        exceed_probs = data.exceedance;
        arrival_dist = EmpiricalArrivalDist(severity_values, exceed_probs, interp_method, loginterp);

    else
        error('Unsupported file format for arrival distribution config: %s', file_ext);
    end
end