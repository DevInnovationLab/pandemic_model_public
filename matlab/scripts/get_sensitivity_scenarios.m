function [scenario_ids, scenario_paths] = get_sensitivity_scenarios(sensitivity_dir)
    % Return canonical list of sensitivity scenario IDs and paths from saved config.
    %
    % Uses the same expansion as run_sensitivity (expand_sensitivities), so IDs and
    % paths match one-parameter, multi-parameter, and mixed configs.
    %
    % Args:
    %   sensitivity_dir (char or string): Path to sensitivity run root
    %     (e.g. output/sensitivity/baseline_vaccine_program_airborne).
    %
    % Returns:
    %   scenario_ids (cell of char): Scenario identifiers for filenames/labels.
    %   scenario_paths (cell of char): Full path to each scenario run directory.

    sensitivity_dir = char(sensitivity_dir);
    config_path = fullfile(sensitivity_dir, 'sensitivity_config.yaml');
    if ~isfile(config_path)
        error('get_sensitivity_scenarios:NoConfig', ...
            'Sensitivity config not found: %s', config_path);
    end

    sensitivity_config = yaml.loadFile(config_path);
    [scenario_ids, rel_paths, ~] = expand_sensitivities(sensitivity_config.sensitivities);

    scenario_paths = cell(size(rel_paths));
    for i = 1:length(rel_paths)
        scenario_paths{i} = fullfile(sensitivity_dir, rel_paths{i});
    end
end
