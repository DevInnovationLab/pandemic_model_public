function check_sensitivities_different(sensitivity_dir)
    % Checks which time series differ between sensitivity scenarios and baseline
    %
    % Args:
    %   sensitivity_dir (str): Path to sensitivity analysis output directory
    %
    % Returns:
    %   None, but saves summary of differences to file in sensitivity directory

    % Load sensitivity config to get scenarios
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    sensitivity_scenarios = fieldnames(sensitivity_config.sensitivities);

    % Get all CSV files in baseline raw directory except pandemic table
    baseline_dir = fullfile(sensitivity_dir, 'baseline', 'raw');
    all_files = dir(fullfile(baseline_dir, '*.csv'));
    ts_files = {};
    for i = 1:length(all_files)
        if ~strcmp(all_files(i).name, 'baseline_pandemic_table.csv')
            ts_files{end+1} = all_files(i).name;
        end
    end

    % Load baseline time series
    baseline_ts = containers.Map();
    for i = 1:length(ts_files)
        baseline_ts(ts_files{i}) = readmatrix(fullfile(baseline_dir, ts_files{i}));
    end

    % Initialize results table
    results = table('Size', [0 4], ...
                   'VariableTypes', {'string', 'string', 'string', 'logical'}, ...
                   'VariableNames', {'Scenario', 'Value', 'TimeSeries', 'Different'});

    % Check each scenario
    for i = 1:length(sensitivity_scenarios)
        scenario = sensitivity_scenarios{i};
        
        % Get sensitivity values for this scenario
        sensitivity_values = dir(fullfile(sensitivity_dir, scenario));
        sensitivity_values = sensitivity_values([sensitivity_values.isdir]); % Keep only directories
        sensitivity_values = {sensitivity_values.name};
        sensitivity_values = sensitivity_values(~ismember(sensitivity_values, {'.', '..'})); % Remove . and ..
        
        % Track if any differences found for this scenario
        scenario_has_differences = false;
        
        % Check each sensitivity value
        for k = 1:length(sensitivity_values)
            value = sensitivity_values{k};
            scenario_dir = fullfile(sensitivity_dir, scenario, value, 'raw');
            
            % Check each time series
            for j = 1:length(ts_files)
                ts_file = ts_files{j};
                scenario_ts = readmatrix(fullfile(scenario_dir, ts_file));
                
                % Compare with baseline and only add if different
                if ~isequal(baseline_ts(ts_file), scenario_ts)
                    results = [results; {scenario, value, ts_file, true}];
                    scenario_has_differences = true;
                end
            end
        end
        
        % If no differences found for this scenario, add a row indicating that
        if ~scenario_has_differences
            results = [results; {scenario, "all", "none", false}];
        end
    end

    % Save results
    writetable(results, fullfile(sensitivity_dir, 'timeseries_differences.csv'));
end
