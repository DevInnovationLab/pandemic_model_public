function scenario_config_paths = resolve_scenario_config_paths(scenario_spec)
    % Resolve scenario config specifications into an ordered path list.
    %
    % Supports two formats:
    %   - Legacy directory path (char/string): includes all *.yaml files in that folder.
    %   - Cell array/list of strings:
    %       * Existing file path string -> literal scenario config.
    %       * Non-file string -> MATLAB regex pattern matched against
    %         repo-relative scenario paths under ./config/scenario_configs.
    %
    % Duplicate files are removed while preserving first appearance. The status-quo
    % scenario is required and forced to the first position in the resolved list.
    %
    % Args:
    %   scenario_spec (char | string | cell): scenario_configs value from run config.
    %
    % Returns:
    %   scenario_config_paths (cell): Absolute paths to resolved scenario YAML files.

    if ischar(scenario_spec) || isStringScalar(scenario_spec)
        scenario_config_paths = resolve_from_directory(scenario_spec);
    elseif iscell(scenario_spec)
        scenario_config_paths = resolve_from_list(scenario_spec);
    else
        error('scenario_configs must be a directory path or a list (got %s).', class(scenario_spec));
    end

    scenario_config_paths = dedupe_preserve_order(scenario_config_paths);
    scenario_config_paths = force_status_quo_first(scenario_config_paths);
end


function scenario_config_paths = resolve_from_directory(scenarios_dir)
    scenarios_dir = to_char(scenarios_dir);
    dir_path = normalize_dir_path(scenarios_dir);

    yaml_files = dir(fullfile(dir_path, '*.yaml'));
    if isempty(yaml_files)
        error('No scenario YAML files in directory: %s', dir_path);
    end

    scenario_config_paths = cell(length(yaml_files), 1);
    for i = 1:length(yaml_files)
        scenario_config_paths{i} = fullfile(yaml_files(i).folder, yaml_files(i).name);
    end
end


function scenario_config_paths = resolve_from_list(scenario_entries)
    if isempty(scenario_entries)
        error('scenario_configs list cannot be empty.');
    end

    scenario_config_paths = {};
    for i = 1:length(scenario_entries)
        entry = scenario_entries{i};

        if ischar(entry) || isStringScalar(entry)
            entry_text = to_char(entry);
            fp = normalize_file_path(entry_text);
            if isfile(fp)
                scenario_config_paths{end+1, 1} = fp; %#ok<AGROW>
            else
                expanded = resolve_regex_pattern(entry_text);
                for j = 1:length(expanded)
                    scenario_config_paths{end+1, 1} = expanded{j}; %#ok<AGROW>
                end
            end
        else
            error('scenario_configs list entry %d must be a string (got %s).', i, class(entry));
        end
    end
end


function resolved_paths = resolve_regex_pattern(pattern)
    scenario_root = normalize_dir_path('./config/scenario_configs');
    yaml_paths = list_yaml_files_recursive(scenario_root);
    resolved_paths = {};
    for j = 1:length(yaml_paths)
        full_path = yaml_paths{j};
        rel_path = erase(full_path, [scenario_root filesep]);
        rel_path_norm = strrep(rel_path, '\', '/');
        full_path_norm = strrep(full_path, '\', '/');
        [~, base_name, ext] = fileparts(full_path);
        file_name = [base_name ext];
        if ~isempty(regexp(rel_path_norm, pattern, 'once')) || ...
                ~isempty(regexp(full_path_norm, pattern, 'once')) || ...
                ~isempty(regexp(file_name, pattern, 'once'))
            resolved_paths{end+1, 1} = full_path; %#ok<AGROW>
        end
    end

    if isempty(resolved_paths)
        error('scenario_configs entry "%s" did not match any files under ./config/scenario_configs.', pattern);
    end
end


function yaml_paths = list_yaml_files_recursive(root_dir)
    % Return all *.yaml file paths under root_dir recursively.
    paths = strsplit(genpath(root_dir), pathsep);
    yaml_paths = {};
    for i = 1:length(paths)
        dir_path = paths{i};
        if isempty(dir_path)
            continue;
        end
        yaml_files = dir(fullfile(dir_path, '*.yaml'));
        for j = 1:length(yaml_files)
            yaml_paths{end+1, 1} = fullfile(yaml_files(j).folder, yaml_files(j).name); %#ok<AGROW>
        end
    end
end


function scenario_config_paths = dedupe_preserve_order(paths_in)
    scenario_config_paths = {};
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for i = 1:length(paths_in)
        key = to_char(paths_in{i});
        if ~isKey(seen, key)
            seen(key) = true;
            scenario_config_paths{end+1, 1} = key; %#ok<AGROW>
        end
    end
end


function scenario_config_paths = force_status_quo_first(paths_in)
    scenario_config_paths = paths_in;
    status_quo_idx = [];
    for i = 1:length(paths_in)
        [~, name, ~] = fileparts(paths_in{i});
        if strcmp(name, 'status_quo')
            status_quo_idx = [status_quo_idx, i]; %#ok<AGROW>
        end
    end

    if isempty(status_quo_idx)
        error('Resolved scenario list must include status_quo.yaml.');
    end

    first_status_quo = status_quo_idx(1);
    status_quo_path = scenario_config_paths{first_status_quo};
    scenario_config_paths(first_status_quo) = [];
    scenario_config_paths = [{status_quo_path}; scenario_config_paths];
end


function out = normalize_dir_path(input_path)
    out = normalize_path(input_path);
    if ~isfolder(out)
        error('Scenario root directory not found: %s', out);
    end
end


function out = normalize_file_path(input_path)
    out = normalize_path(input_path);
end


function out = normalize_path(input_path)
    path_char = to_char(input_path);
    if is_absolute_path(path_char)
        out = path_char;
    else
        out = fullfile(pwd, path_char);
    end
end


function tf = is_absolute_path(input_path)
    if ispc
        tf = ~isempty(regexp(input_path, '^[A-Za-z]:[\\/]', 'once')) || startsWith(input_path, '\\');
    else
        tf = startsWith(input_path, filesep);
    end
end


function value = to_char(input_value)
    if isstring(input_value)
        value = char(input_value);
    else
        value = input_value;
    end
end
