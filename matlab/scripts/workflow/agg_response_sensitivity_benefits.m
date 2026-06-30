function agg_response_sensitivity_benefits(sensitivity_dir)
    % Aggregate baseline and relative PV benefits for a response-type sensitivity run.
    %
    % Requires sensitivity_chunk_manifest.mat with manifest_run_type == "response".
    %
    % If sensitivity_dir contains program_sensitivity_config.yaml (top-level multi-program run),
    % aggregates each program subdirectory. Otherwise aggregates that directory only.

    sensitivity_dir = char(sensitivity_dir);
    assert_response_sensitivity_manifest(sensitivity_dir);

    prog_cfg = fullfile(sensitivity_dir, 'program_sensitivity_config.yaml');
    if isfile(prog_cfg)
        cfg = yaml.loadFile(prog_cfg);
        program_names = fieldnames(cfg.program_sensitivities);
        for i = 1:numel(program_names)
            agg_response_sensitivity_benefits_single(fullfile(sensitivity_dir, program_names{i}));
        end
        return;
    end
    agg_response_sensitivity_benefits_single(sensitivity_dir);
end


function assert_response_sensitivity_manifest(sensitivity_dir)
    % Require a chunk manifest and response run type for sensitivity benefit aggregation.

    manifest_path = fullfile(sensitivity_dir, 'sensitivity_chunk_manifest.mat');
    if ~isfile(manifest_path)
        manifest_path = fullfile(fileparts(sensitivity_dir), 'sensitivity_chunk_manifest.mat');
    end
    if ~isfile(manifest_path)
        error('Missing sensitivity_chunk_manifest.mat (expected here or under the parent directory).');
    end
    S = load(manifest_path, 'manifest_run_type');
    rt = strtrim(char(string(S.manifest_run_type)));
    if strlength(string(rt)) == 0
        error('Manifest has empty manifest_run_type.');
    end
    if ~strcmpi(rt, 'response')
        error('This aggregation is for response runs only (manifest_run_type is not response).');
    end
end


function agg_response_sensitivity_benefits_single(sensitivity_dir)
    aggregate_response_reference_run_metrics(sensitivity_dir);
    aggregate_response_sensitivity_metrics(sensitivity_dir);
end


function aggregate_response_reference_run_metrics(sensitivity_dir)
    % Aggregate status-quo absolute and reference-scenario relative net values.
    %
    % Writes status_quo_benefits_summary.mat with:
    %   - status_quo_absolute_mean_net_value
    %   - status_quo_absolute_net_values
    %   - reference_scenario_relative_mean_net_value (only when present in run_config)
    %   - reference_scenario_relative_net_values (only when present in run_config)
    %   - reference_scenario_name (only when present in run_config)

    top_processed_dir = fullfile(sensitivity_dir, 'processed');
    create_folders_recursively(top_processed_dir);

    manifest_rows = load_manifest_rows_for_sensitivity_dir(sensitivity_dir);
    reference_run_dir = resolve_default_run_dir_from_manifest(manifest_rows);
    raw_dir = fullfile(reference_run_dir, 'raw');
    if ~isfolder(raw_dir)
        error('Reference run raw directory not found: %s', raw_dir);
    end

    run_config_path = fullfile(reference_run_dir, 'run_config.yaml');
    run_config = yaml.loadFile(run_config_path);

    status_quo_absolute_net_values = load_status_quo_net_values(raw_dir);
    status_quo_absolute_mean_net_value = mean(status_quo_absolute_net_values);

    reference_scenario_name = resolve_single_non_status_quo_scenario_name(run_config, run_config_path);
    summary_payload = struct();
    summary_payload.status_quo_absolute_mean_net_value = status_quo_absolute_mean_net_value;
    summary_payload.status_quo_absolute_net_values = status_quo_absolute_net_values;
    summary_payload.run_config = run_config;

    if ~isempty(reference_scenario_name)
        reference_scenario_relative_net_values = load_relative_net_values(raw_dir, reference_scenario_name);
        summary_payload.reference_scenario_relative_mean_net_value = mean(reference_scenario_relative_net_values);
        summary_payload.reference_scenario_relative_net_values = reference_scenario_relative_net_values;
        summary_payload.reference_scenario_name = reference_scenario_name;
    end

    output_path = fullfile(top_processed_dir, 'status_quo_benefits_summary.mat');
    save(output_path, '-struct', 'summary_payload');
end


function default_run_dir = resolve_default_run_dir_from_manifest(manifest_rows)
    % Resolve the program default run directory from manifest rows.
    for i = 1:numel(manifest_rows)
        row = manifest_rows{i};
        if ~isfield(row, 'is_default')
            error('Manifest row is missing required is_default field.');
        end
        is_default = logical(row.is_default);
        if is_default
            default_run_dir = char(string(row.scenario_dir));
            return;
        end
    end
    error('Could not resolve default/full run row from manifest.');
end


function [chunk_mat_paths, n_sims_per_chunk] = resolve_status_quo_sums_chunks(raw_dir)
    % Resolve status-quo sums paths in raw/chunk_* folders.

    [chunk_dirs, chunk_numbers] = list_chunk_dirs(raw_dir);

    if ~isempty(chunk_dirs)
        expected = 1:length(chunk_dirs);
        if ~isequal(chunk_numbers, expected)
            error('Chunk folders not contiguous in %s.', raw_dir);
        end
        chunk_mat_paths = arrayfun(@(c) fullfile(raw_dir, c.name, 'status_quo_sums.mat'), chunk_dirs, 'UniformOutput', false);
    else
        single_path = fullfile(raw_dir, 'status_quo_sums.mat');
        if isfile(single_path)
            chunk_mat_paths = {single_path};
        else
            error('No chunk_* dirs and no status_quo_sums.mat in %s.', raw_dir);
        end
    end

    T0 = load(chunk_mat_paths{1}, 'baseline_sums').baseline_sums;
    n_sims_per_chunk = length(T0.net_value_pv_full);
end


function aggregate_response_sensitivity_metrics(sensitivity_dir)
    % Aggregate scenario-relative net values for each sensitivity variant.
    %
    % Writes each <scenario_id>_benefits_summary.mat with:
    %   - scenario_relative_mean_net_value (only when non-status-quo comparator exists)
    %   - scenario_relative_net_values (only when non-status-quo comparator exists)
    %   - scenario_absolute_mean_net_value
    %   - status_quo_absolute_mean_net_value

    top_processed_dir = fullfile(sensitivity_dir, 'processed');
    create_folders_recursively(top_processed_dir);

    [scenario_ids, scenario_paths] = get_sensitivity_scenarios(sensitivity_dir);
    manifest_rows = load_manifest_rows_for_sensitivity_dir(sensitivity_dir);
    status_quo_mean_cache = containers.Map('KeyType', 'char', 'ValueType', 'double');

    for idx = 1:length(scenario_ids)
        scenario_id = scenario_ids{idx};
        value_dir = scenario_paths{idx};
        raw_dir = fullfile(value_dir, 'raw');
        run_config_path = fullfile(value_dir, 'run_config.yaml');
        run_config = yaml.loadFile(run_config_path);
        if ~isfield(run_config, 'scenarios')
            error('Missing scenarios in %s', run_config_path);
        end
        perturbed_scenario_name = resolve_single_non_status_quo_scenario_name(run_config, run_config_path);

        if ~isfolder(raw_dir)
            error('Missing raw directory for scenario %s: %s', scenario_id, raw_dir);
        end

        status_quo_slug = resolve_status_quo_slug_for_scenario(manifest_rows, scenario_id, value_dir);
        status_quo_absolute_mean_net_value = get_status_quo_mean_for_slug( ...
            sensitivity_dir, status_quo_slug, status_quo_mean_cache);

        scenario_summary = struct();
        scenario_summary.scenario_absolute_mean_net_value = status_quo_absolute_mean_net_value;
        scenario_summary.status_quo_absolute_mean_net_value = status_quo_absolute_mean_net_value;
        scenario_summary.scenario_id = scenario_id;
        scenario_summary.run_config = run_config;

        if ~isempty(perturbed_scenario_name)
            scenario_relative_net_values = load_relative_net_values(raw_dir, perturbed_scenario_name);
            scenario_relative_mean_net_value = mean(scenario_relative_net_values);
            scenario_summary.scenario_relative_mean_net_value = scenario_relative_mean_net_value;
            scenario_summary.scenario_relative_net_values = scenario_relative_net_values;
            scenario_summary.scenario_absolute_mean_net_value = ...
                status_quo_absolute_mean_net_value + scenario_relative_mean_net_value;
            scenario_summary.perturbed_scenario_name = perturbed_scenario_name;
        end

        output_filename = sprintf('%s_benefits_summary.mat', scenario_id);
        output_path = fullfile(top_processed_dir, output_filename);
        save(output_path, '-struct', 'scenario_summary');
    end
end


function [chunk_mat_paths, n_sims_per_chunk] = resolve_relative_sums_chunks(raw_dir, relative_sums_name)
    % Resolve <scenario>_relative_sums.mat paths in contiguous chunk_* folders.

    [chunk_dirs, chunk_numbers] = list_chunk_dirs(raw_dir);
    if isempty(chunk_dirs)
        error('No chunk_* directories in %s.', raw_dir);
    end

    expected = 1:length(chunk_dirs);
    if ~isequal(chunk_numbers, expected)
        error('Chunk folders not contiguous in %s.', raw_dir);
    end

    chunk_mat_paths = cell(length(chunk_dirs), 1);
    for i = 1:length(chunk_dirs)
        chunk_dir = fullfile(raw_dir, chunk_dirs(i).name);
        fp = fullfile(chunk_dir, sprintf('%s_relative_sums.mat', relative_sums_name));
        if ~isfile(fp)
            error('Missing file: %s', fp);
        end
        chunk_mat_paths{i} = fp;
    end

    T0 = load(chunk_mat_paths{1}, 'scenario_sum_table').scenario_sum_table;
    n_sims_per_chunk = length(T0.net_value_pv_full);
end


function vals = load_status_quo_net_values(raw_dir)
    % Load status-quo net values from chunked baseline_sums outputs.

    [chunk_mat_paths, ~] = resolve_status_quo_sums_chunks(raw_dir);
    vals = load_net_values_from_chunks(chunk_mat_paths, 'baseline_sums');
end


function vals = load_relative_net_values(raw_dir, scenario_name)
    % Load scenario-relative net values from chunked scenario_sum_table outputs.

    [chunk_mat_paths, ~] = resolve_relative_sums_chunks(raw_dir, scenario_name);
    vals = load_net_values_from_chunks(chunk_mat_paths, 'scenario_sum_table');
end


function vals = load_net_values_from_chunks(chunk_mat_paths, table_var_name)
    % Stack net_value_pv_full from chunk files into one column vector.

    first_table = load(chunk_mat_paths{1}, table_var_name).(table_var_name);
    n_sims_per_chunk = length(first_table.net_value_pv_full);
    n_chunks = length(chunk_mat_paths);
    vals = zeros(n_sims_per_chunk * n_chunks, 1);

    for k = 1:n_chunks
        T = load(chunk_mat_paths{k}, table_var_name).(table_var_name);
        col = T.net_value_pv_full;
        start_idx = (k - 1) * n_sims_per_chunk + 1;
        end_idx = k * n_sims_per_chunk;
        vals(start_idx:end_idx) = col;
    end
end


function scenario_name = resolve_single_non_status_quo_scenario_name(run_config, run_config_path)
    % Return the unique non-status-quo scenario name, or '' if none exists.

    if ~isfield(run_config, 'scenarios')
        error('Missing scenarios in %s', run_config_path);
    end
    scenario_names = fieldnames(run_config.scenarios);
    non_status_quo_names = scenario_names(~strcmp(scenario_names, 'status_quo'));
    if isempty(non_status_quo_names)
        scenario_name = '';
        return;
    end
    if numel(non_status_quo_names) > 1
        error('Expected at most one non-status-quo scenario in %s.', run_config_path);
    end
    scenario_name = non_status_quo_names{1};
end


function manifest_rows = load_manifest_rows_for_sensitivity_dir(sensitivity_dir)
    % Load manifest rows relevant to one program sensitivity directory.

    candidates = { ...
        fullfile(sensitivity_dir, 'sensitivity_chunk_manifest.mat'), ...
        fullfile(fileparts(sensitivity_dir), 'sensitivity_chunk_manifest.mat') ...
    };
    for i = 1:length(candidates)
        mp = candidates{i};
        if ~isfile(mp)
            continue;
        end
        S = load(mp, 'chunk_manifest_rows');
        rows = S.chunk_manifest_rows;
        if isempty(rows)
            continue;
        end
        keep = false(numel(rows), 1);
        canon_sens = resolve_dir_absolute(sensitivity_dir);
        for k = 1:numel(rows)
            row_base = char(string(rows{k}.program_base_dir));
            keep(k) = strcmp(canon_sens, resolve_dir_absolute(row_base));
        end
        rows_for_dir = rows(keep);
        if ~isempty(rows_for_dir)
            manifest_rows = rows_for_dir;
            return;
        end
    end
    error('Could not resolve manifest rows for sensitivity directory: %s', sensitivity_dir);
end


function slug = resolve_status_quo_slug_for_scenario(manifest_rows, scenario_id, scenario_dir)
    % Resolve status-quo baseline slug for one scenario from manifest rows.

    scenario_dir = char(string(scenario_dir));
    for i = 1:numel(manifest_rows)
        row = manifest_rows{i};
        if strcmp(char(string(row.scenario_dir)), scenario_dir)
            slug = char(string(row.status_quo_slug));
            return;
        end
    end
    for i = 1:numel(manifest_rows)
        row = manifest_rows{i};
        if strcmp(char(string(row.scenario_id)), char(string(scenario_id)))
            slug = char(string(row.status_quo_slug));
            return;
        end
    end
    error('Could not resolve status-quo slug for scenario %s.', char(string(scenario_id)));
end


function m = get_status_quo_mean_for_slug(sensitivity_dir, slug, cache_map)
    % Mean absolute status-quo net value for one baseline slug.

    if isKey(cache_map, slug)
        m = cache_map(slug);
        return;
    end

    raw_dir = fullfile(sensitivity_dir, 'baselines', slug, 'raw');
    [chunk_mat_paths, n_sims_per_chunk] = resolve_status_quo_sums_chunks(raw_dir);
    n_chunks = length(chunk_mat_paths);
    all_vals = zeros(n_sims_per_chunk * n_chunks, 1);
    for k = 1:n_chunks
        T = load(chunk_mat_paths{k}, 'baseline_sums').baseline_sums;
        start_idx = (k - 1) * n_sims_per_chunk + 1;
        end_idx = k * n_sims_per_chunk;
        all_vals(start_idx:end_idx) = T.net_value_pv_full;
    end
    m = mean(all_vals);
    cache_map(slug) = m; %#ok<NASGU>
end
