function [scenario_ids, rel_paths, overrides] = expand_sensitivities(sensitivities)
    % Expand sensitivities config into a canonical list of scenarios.
    %
    % Each key in sensitivities is either:
    %   - A struct with fields: one scenario (multi-parameter), id = key, rel_path = key.
    %   - A cell or numeric array: one scenario per value (one-parameter), id = key_value_j,
    %     rel_path = key/value_j.
    % Works for all-array, all-struct, or mixed configs.
    %
    % Args:
    %   sensitivities (struct): The sensitivities field from a sensitivity config.
    %
    % Returns:
    %   scenario_ids (cell of char): Scenario identifier for each scenario.
    %   rel_paths (cell of char): Relative path from sensitivity run root for each scenario.
    %   overrides (cell of struct): Parameter overrides to apply to base config for each scenario.

    keys = fieldnames(sensitivities);
    scenario_ids = {};
    rel_paths = {};
    overrides = {};

    for i = 1:length(keys)
        key = keys{i};
        val = sensitivities.(key);

        if isstruct(val) && ~isempty(fieldnames(val))
            scenario_ids{end+1} = key; %#ok<AGROW>
            rel_paths{end+1} = key; %#ok<AGROW>
            overrides{end+1} = val; %#ok<AGROW>
        elseif iscell(val) || isnumeric(val)
            if isnumeric(val)
                n_vals = numel(val);
                val_cell = num2cell(val);
            else
                n_vals = length(val);
                val_cell = val;
            end
            for j = 1:n_vals
                scenario_ids{end+1} = sprintf('%s_value_%d', key, j); %#ok<AGROW>
                rel_paths{end+1} = fullfile(key, sprintf('value_%d', j)); %#ok<AGROW>
                overrides{end+1} = struct(key, val_cell{j}); %#ok<AGROW>
            end
        else
            error('expand_sensitivities:InvalidEntry', ...
                'Sensitivity entry "%s" must be a struct (multi-parameter) or array (one-parameter).', key);
        end
    end
end
