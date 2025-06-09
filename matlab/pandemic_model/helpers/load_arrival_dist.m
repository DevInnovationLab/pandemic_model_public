function [metric, arrival_dist] = load_arrival_dist(arrival_dist_config_path, false_positive_rate)
    % Load arrival distribution from YAML config file into MEVD object
    %
    % Parameters:
    %   arrival_dist_config_path - Path to YAML config file containing arrival distribution parameters
    %   false_positive_rate - False positive rate
    %
    % Returns:
    %   arrival_dist - MEVD object representing the arrival distribution
    
    arguments
        arrival_dist_config_path (1,1) string
        false_positive_rate (1,1) double
    end
    % Check file extension
    [~, ~, ext] = fileparts(arrival_dist_config_path);
    
    if strcmp(ext, '.yaml')
        % Load arrival distribution config from YAML
        arrival_dist_config = yaml.loadFile(arrival_dist_config_path);

        % Extract parameters from config
        metric = arrival_dist_config.metric;
        window_counts = cell2mat(arrival_dist_config.arrival_counts);
        base_dist_family = arrival_dist_config.base_dist_family;
        base_dist_params = arrival_dist_config.base_dist_params;
        truncation = arrival_dist_config.truncation;
        upper_bound = arrival_dist_config.upper_bound;

        % False positive adjustment, this is hacky
        false_pos_add = ceil(sum(window_counts) * false_positive_rate) / (1 - false_positive_rate);
        false_pos_increment = [ones(false_pos_add, 1); zeros(height(window_counts) - false_pos_add, 1)];
        assert(isequal(size(false_pos_increment), size(window_counts)));
        window_counts = window_counts + false_pos_increment;
        
        % Create MEVD object
        arrival_dist = MEVD(window_counts, ...
                            base_dist_family, ...
                            base_dist_params, ...
                            truncation, ...
                            upper_bound);
                            
    elseif strcmp(ext, ".csv")
        % Hardcoding a bunch of stuff that really shouldn't be because I'm lazy.
        param_samples = readtable(arrival_dist_config_path);
        metric = 'intensity';
        arrival_dist = ParametrizedSeveritySampler(param_samples, 0.01);
    end
end
