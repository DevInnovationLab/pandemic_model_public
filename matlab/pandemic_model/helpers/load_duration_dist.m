function duration_dist = load_duration_dist(config_path, param_range)
    % Load a duration distribution from a parameter-sample CSV.
    %
    % Args:
    %   config_path  Path to a .csv file with columns mu, sigma, and loc.
    %   param_range  [1 x 2] Row range [start, end] for CSV sampling (default: read all).
    %
    % Returns:
    %   duration_dist  DurationSampler built from the parameter draws.
    arguments
        config_path
        param_range (1,2) double = [nan, nan]
    end

    [~, stem, ext] = fileparts(config_path);
    assert(strcmp(ext, ".csv"), ...
        "Duration distribution must be a CSV file: %s", config_path);
    assert(isempty(regexp(stem, '__dur__trunc\d+_', 'once')), ...
        "Duration distribution path uses obsolete trunc naming: %s", config_path);

    if all(~isnan(param_range))
        param_samples = readtable(config_path, ...
                                  'VariableNamesLine', 1, ...
                                  'Range', sprintf('%d:%d', param_range(1) + 1, param_range(2) + 1));
    else
        param_samples = readtable(config_path);
    end

    duration_dist = DurationSampler(param_samples);
end
