function run_sensitivity_chunk_job(config_path, run_type, num_chunks, chunk_id, varargin)
    % Execute one chunk (or all chunks) of every sensitivity scenario from a saved manifest.
    %
    % Loads sensitivity_chunk_manifest.mat under outdir/<run_name>/ and, for each row in
    % order, runs the scenario. For manifest_run_type response, ensures the shared baseline
    % for that row exists for this chunk, then runs with skip_baseline. For unmitigated,
    % skips separate baselines/<slug> jobs (estimate_unmitigated_losses does not reuse
    % baseline MAT files). Reads frozen run_config.yaml files from write_sensitivity_manifest.
    %
    % Args:
    %   config_path  Path to top-level sensitivity YAML (used for outdir and run_name only
    %                  if manifest path is derived; must match manifest).
    %   run_type       'response' or 'unmitigated' (overridden by manifest_run_type if present).
    %   num_chunks     Number of simulation chunks.
    %   chunk_id       SLURM chunk index 1..num_chunks, or nan to run all chunks in process.
    %
    % Name-value:
    %   skip_completed  If true, skip baseline and scenario steps when expected output files
    %                   already exist for the requested chunk(s) (resume).

    p = inputParser;
    addParameter(p, 'skip_completed', false, @islogical);
    parse(p, varargin{:});
    skip_completed = p.Results.skip_completed;

    config_path = char(config_path);
    sensitivity_config = yaml.loadFile(config_path);
    [~, run_name, ~] = fileparts(config_path);
    sensitivity_config.run_name = run_name;

    root_dir = fullfile(sensitivity_config.outdir, sensitivity_config.run_name);
    manifest_path = fullfile(root_dir, 'sensitivity_chunk_manifest.mat');
    if ~isfile(manifest_path)
        error('Manifest not found: %s', manifest_path);
    end

    S = load(manifest_path);
    rows = S.chunk_manifest_rows;
    if isfield(S, 'manifest_run_type') && ~isempty(strtrim(char(string(S.manifest_run_type))))
        run_type = char(string(S.manifest_run_type));
    else
        run_type = char(string(run_type));
    end
    if isempty(rows)
        error('Manifest has no rows: %s', manifest_path);
    end

    status_quo_raw_dir_by_key = containers.Map('KeyType', 'char', 'ValueType', 'char');

    for i = 1:numel(rows)
        row = rows{i};
        fprintf('Manifest row %d/%d: program=%s scenario=%s\n', i, numel(rows), row.program, row.scenario_id);

        row_run_type = run_type;
        if isfield(row, 'run_type') && strlength(string(row.run_type)) > 0
            row_run_type = char(string(row.run_type));
        end
        is_default = logical(row.is_default);

        run_config = yaml.loadFile(row.run_config_path);
        scenario_dir = sensitivity_row_scenario_dir(row, run_config);

        if is_default
            if skip_completed
                if strcmp(row_run_type, 'response') && ...
                        sensitivity_status_quo_response_complete(scenario_dir, num_chunks, chunk_id) && ...
                        sensitivity_scenario_response_complete(scenario_dir, run_config, num_chunks, chunk_id)
                    fprintf('Skipping completed default run %s / %s\n', row.program, row.scenario_id);
                    continue;
                elseif strcmp(row_run_type, 'unmitigated') && sensitivity_unmitigated_outputs_complete(scenario_dir, num_chunks, chunk_id)
                    fprintf('Skipping completed default run %s / %s\n', row.program, row.scenario_id);
                    continue;
                end
            end
            run_sensitivity_single_scenario(run_config, row_run_type, num_chunks, chunk_id, ...
                'baseline_mode', 'full');
            continue;
        end

        if strcmp(row_run_type, 'unmitigated')
            % estimate_unmitigated_losses ignores baseline_reference_raw; separate baselines/<slug>
            % runs would only duplicate simulations for each sensitivity value.
            if skip_completed && sensitivity_unmitigated_outputs_complete(scenario_dir, num_chunks, chunk_id)
                fprintf('Skipping completed scenario %s / %s\n', row.program, row.scenario_id);
                continue;
            end
            run_sensitivity_single_scenario(run_config, row_run_type, num_chunks, chunk_id, ...
                'baseline_mode', 'skip_baseline', 'baseline_reference_raw', '');
            continue;
        end

        status_quo_key = char(row.status_quo_key);

        if isKey(status_quo_raw_dir_by_key, status_quo_key)
            status_quo_raw_dir = status_quo_raw_dir_by_key(status_quo_key);
        else
            status_quo_run_config = yaml.loadFile(row.baseline_run_config_path);
            status_quo_outdir = fullfile(row.program_base_dir, 'baselines', char(row.status_quo_slug));
            create_folders_recursively(status_quo_outdir);
            status_quo_job_config = status_quo_run_config;
            status_quo_job_config.outdir = status_quo_outdir;

            status_quo_outputs_exist = false;
            if skip_completed && sensitivity_status_quo_response_complete(status_quo_outdir, num_chunks, chunk_id)
                status_quo_outputs_exist = true;
            end

            if status_quo_outputs_exist
                status_quo_raw_dir = fullfile(status_quo_outdir, 'raw');
                status_quo_raw_dir_by_key(status_quo_key) = status_quo_raw_dir;
                fprintf('Skipping status quo (outputs exist) slug %s (program %s)\n', row.status_quo_slug, row.program);
            else
                fprintf('Running status quo baseline-only for slug %s (program %s)...\n', row.status_quo_slug, row.program);
                run_sensitivity_single_scenario(status_quo_job_config, row_run_type, num_chunks, chunk_id, 'baseline_mode', 'baseline_only');
                status_quo_raw_dir = fullfile(status_quo_outdir, 'raw');
                status_quo_raw_dir_by_key(status_quo_key) = status_quo_raw_dir;
            end
        end

        if skip_completed && sensitivity_scenario_response_complete(scenario_dir, run_config, num_chunks, chunk_id)
            fprintf('Skipping completed scenario %s / %s\n', row.program, row.scenario_id);
            continue;
        end

        run_sensitivity_single_scenario(run_config, row_run_type, num_chunks, chunk_id, ...
            'baseline_mode', 'skip_baseline', 'baseline_reference_raw', status_quo_raw_dir);
    end
end


function scenario_dir = sensitivity_row_scenario_dir(row, run_config)
    % Prefer scenario_dir from the manifest; fall back to outdir in the frozen run_config.

    if isfield(row, 'scenario_dir') && strlength(string(row.scenario_dir)) > 0
        scenario_dir = char(string(row.scenario_dir));
    else
        scenario_dir = char(string(run_config.outdir));
    end
end


function idx = sensitivity_chunk_indices(num_chunks, array_task_id)
    % Chunk indices to verify for resume (all chunks locally, or one SLURM chunk).

    if isnan(array_task_id)
        idx = 1:num_chunks;
    else
        idx = array_task_id;
    end
end


function tf = sensitivity_status_quo_response_complete(status_quo_outdir, num_chunks, array_task_id)
    % Status-quo artifacts required for skip_baseline reuse (response runs).

    idx = sensitivity_chunk_indices(num_chunks, array_task_id);
    for ii = 1:numel(idx)
        k = idx(ii);
        chunk_dir = fullfile(status_quo_outdir, 'raw', sprintf('chunk_%d', k));
        if ~isfile(fullfile(chunk_dir, 'status_quo_sums.mat')) || ~isfile(fullfile(chunk_dir, 'status_quo_annual.mat'))
            tf = false;
            return;
        end
    end
    tf = true;
end


function tf = sensitivity_scenario_response_complete(scenario_dir, run_config, num_chunks, array_task_id)
    % Non-baseline relative_sums present for each chunk.

    scenario_config_paths = resolve_scenario_config_paths(run_config.scenario_configs);
    idx = sensitivity_chunk_indices(num_chunks, array_task_id);
    for ii = 1:numel(idx)
        k = idx(ii);
        for s = 1:numel(scenario_config_paths)
            [~, scenario_name, ~] = fileparts(scenario_config_paths{s});
            if strcmp(scenario_name, 'status_quo')
                continue;
            end
            fp = fullfile(scenario_dir, 'raw', sprintf('chunk_%d', k), sprintf('%s_relative_sums.mat', scenario_name));
            if ~isfile(fp)
                tf = false;
                return;
            end
        end
    end
    tf = true;
end


function tf = sensitivity_unmitigated_outputs_complete(scenario_dir, num_chunks, array_task_id)
    % Unmitigated per-chunk mats and aggregated file when running all chunks locally.

    if num_chunks == 1
        tf = isfile(fullfile(scenario_dir, 'unmitigated_losses.mat'));
        return;
    end

    idx = sensitivity_chunk_indices(num_chunks, array_task_id);
    for ii = 1:numel(idx)
        k = idx(ii);
        fp = fullfile(scenario_dir, 'raw', sprintf('chunk_%d', k), 'unmitigated_losses.mat');
        if ~isfile(fp)
            tf = false;
            return;
        end
    end

    if isnan(array_task_id) && ~isfile(fullfile(scenario_dir, 'unmitigated_losses.mat'))
        tf = false;
        return;
    end

    tf = true;
end
