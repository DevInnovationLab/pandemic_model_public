function [metric, arrival_dist] = load_arrival_dist(arrival_dist_config_path)
    % Load arrival distribution from YAML config file into MEVD object
    %
    % Parameters:
    %   arrival_dist_config_path - Path to YAML config file containing arrival distribution parameters
    %
    % Returns:
    %   arrival_dist - MEVD object representing the arrival distribution
    
    arguments
        arrival_dist_config_path (1,1) string
    end

    % Load arrival distribution config from YAML
    arrival_dist_config = yaml.loadFile(arrival_dist_config_path);

    % Extract parameters from config
    metric = arrival_dist_config.metric;
    window_counts = cell2mat(arrival_dist_config.arrival_counts);
    base_dist_family = arrival_dist_config.base_dist_family;
    base_dist_params = arrival_dist_config.base_dist_params;
    truncation = arrival_dist_config.truncation;
    upper_bound = arrival_dist_config.upper_bound;
    
    % Create MEVD object
    arrival_dist = MEVD(window_counts, ...
                        base_dist_family, ...
                        base_dist_params, ...
                        truncation, ...
                        upper_bound);
end
