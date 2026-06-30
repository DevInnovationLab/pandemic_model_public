function check_sensitivities_different(sensitivity_dir)
    % Checks which time series differ between sensitivity scenarios and the default baseline.
    %
    % Args:
    %   sensitivity_dir (str): Path to sensitivity analysis output directory
    %
    % Saves sensitivity_dir/timeseries_differences.csv.

    sensitivity_dir = char(sensitivity_dir);
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));
    sensitivity_scenarios = fieldnames(sensitivity_config.sensitivities);

    baseline_raw_dir = fullfile(sensitivity_dir, 'default', 'raw');

    all_files = dir(fullfile(baseline_raw_dir, '*.csv'));
    ts_files = {};
    for i = 1:length(all_files)
        if ~strcmp(all_files(i).name, 'status_quo_pandemic_table.csv')
            ts_files{end+1} = all_files(i).name; %#ok<AGROW>
        end
    end

    baseline_ts = containers.Map();
    for i = 1:length(ts_files)
        baseline_ts(ts_files{i}) = readmatrix(fullfile(baseline_raw_dir, ts_files{i}));
    end

    results = table('Size', [0 4], ...
        'VariableTypes', {'string', 'string', 'string', 'logical'}, ...
        'VariableNames', {'Scenario', 'Value', 'TimeSeries', 'Different'});

    for i = 1:length(sensitivity_scenarios)
        scenario = sensitivity_scenarios{i};

        sensitivity_values = dir(fullfile(sensitivity_dir, scenario));
        sensitivity_values = sensitivity_values([sensitivity_values.isdir]);
        sensitivity_values = {sensitivity_values.name};
        sensitivity_values = sensitivity_values(~ismember(sensitivity_values, {'.', '..'}));

        scenario_has_differences = false;

        for k = 1:length(sensitivity_values)
            value = sensitivity_values{k};
            scenario_dir = fullfile(sensitivity_dir, scenario, value, 'raw');

            for j = 1:length(ts_files)
                ts_file = ts_files{j};
                scenario_ts = readmatrix(fullfile(scenario_dir, ts_file));

                if ~isequal(baseline_ts(ts_file), scenario_ts)
                    results = [results; {scenario, value, ts_file, true}]; %#ok<AGROW>
                    scenario_has_differences = true;
                end
            end
        end

        if ~scenario_has_differences
            results = [results; {scenario, "all", "none", false}]; %#ok<AGROW>
        end
    end

    writetable(results, fullfile(sensitivity_dir, 'timeseries_differences.csv'));
end
