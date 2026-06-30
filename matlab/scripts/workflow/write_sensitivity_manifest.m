function write_sensitivity_manifest(config_path, run_type)
    % Expand a program-scoped sensitivity YAML and write chunk manifest plus per-scenario run configs.
    %
    % Writes under outdir/<run_name>/:
    %   - sensitivity_chunk_manifest.mat (variable chunk_manifest_rows)
    %   - Per-program sensitivity_config.yaml
    %   - Per-status-quo-run baseline_run_config.yaml under baselines/<slug>/
    %   - Per-scenario run_config.yaml (merged base + overrides, outdir = scenario_dir)
    %
    % Call once from the SLURM driver before submitting the chunk array, or from
    % run_sensitivity for a local full run.
    %
    % Args:
    %   config_path  Path to top-level sensitivity YAML (program_sensitivities).
    %   run_type     'response' or 'unmitigated' (stored in manifest for post-processing).

    config_path = char(config_path);
    if nargin < 2 || isempty(run_type)
        run_type = 'response';
    end
    run_type = char(string(run_type));
    sensitivity_config = yaml.loadFile(config_path);
    [~, run_name, ~] = fileparts(config_path);
    sensitivity_config.run_name = run_name;

    root_dir = fullfile(sensitivity_config.outdir, run_name);
    create_folders_recursively(root_dir);

    chunk_manifest_rows = {};
    program_names = fieldnames(sensitivity_config.program_sensitivities);

    for pi = 1:length(program_names)
        program_name = program_names{pi};
        program_entry = sensitivity_config.program_sensitivities.(program_name);

        if ~isfield(program_entry, 'sensitivities') || isempty(program_entry.sensitivities)
            error('Program "%s" must include a non-empty sensitivities field.', program_name);
        end

        program_config = struct();
        program_config.base_run_config = sensitivity_config.base_run_config;
        program_config.outdir = sensitivity_config.outdir;
        program_config.run_name = fullfile(sensitivity_config.run_name, program_name);
        program_config.sensitivities = program_entry.sensitivities;

        merged_fix_params = struct();
        if isfield(sensitivity_config, 'fix_params') && ~isempty(sensitivity_config.fix_params)
            merged_fix_params = sensitivity_config.fix_params;
        end
        if isfield(program_entry, 'fix_params') && ~isempty(program_entry.fix_params)
            merged_fix_params = merge_struct_fields_local(merged_fix_params, program_entry.fix_params);
        end
        if ~isempty(fieldnames(merged_fix_params))
            program_config.fix_params = merged_fix_params;
        end

        base_dir = fullfile(sensitivity_config.outdir, program_config.run_name);
        create_folders_recursively(base_dir);
        base_dir = resolve_dir_absolute(base_dir);
        yaml.dumpFile(fullfile(base_dir, "sensitivity_config.yaml"), program_config);

        base_config = yaml.loadFile(program_config.base_run_config);
        if isfield(program_config, 'fix_params') && ~isempty(program_config.fix_params)
            fix_params = program_config.fix_params;
            fn = fieldnames(fix_params);
            for k = 1:length(fn)
                base_config.(fn{k}) = fix_params.(fn{k});
            end
        end

        default_dir = fullfile(base_dir, 'default');
        create_folders_recursively(default_dir);
        default_run_config = base_config;
        default_run_config.outdir = default_dir;
        default_run_config_path = fullfile(default_dir, 'run_config.yaml');
        yaml.dumpFile(default_run_config_path, default_run_config);
        chunk_manifest_rows{end + 1} = struct( ...
            'program', program_name, ...
            'scenario_id', 'default', ...
            'rel_path', 'default', ...
            'program_base_dir', base_dir, ...
            'scenario_dir', default_dir, ...
            'run_config_path', default_run_config_path, ...
            'run_type', run_type, ...
            'is_default', true);

        non_baseline_only_fields = get_non_baseline_fields();
        [scenario_ids, rel_paths, overrides] = expand_sensitivities(program_config.sensitivities);

        for j = 1:length(scenario_ids)
            scenario_id = scenario_ids{j};
            scenario_dir = fullfile(base_dir, rel_paths{j});
            create_folders_recursively(scenario_dir);

            of = overrides{j};
            run_config = base_config;
            of_names = fieldnames(of);
            for k = 1:length(of_names)
                run_config.(of_names{k}) = of.(of_names{k});
            end
            run_config.outdir = scenario_dir;
            yaml.dumpFile(fullfile(scenario_dir, 'run_config.yaml'), run_config);

            status_quo_run_config = resolve_status_quo_run_config(base_config, of, non_baseline_only_fields);
            status_quo_key = canonicalize_config_value(status_quo_run_config);
            slug = sensitivity_baseline_slug(status_quo_key);
            status_quo_outdir = fullfile(base_dir, 'baselines', slug);
            status_quo_raw_dir = fullfile(base_dir, 'baselines', slug, 'raw');
            baseline_run_config_path = fullfile(status_quo_outdir, 'baseline_run_config.yaml');

            % Save status-quo run config used for this row's comparator baseline.
            create_folders_recursively(status_quo_outdir);
            status_quo_run_config.outdir = status_quo_outdir;
            yaml.dumpFile(baseline_run_config_path, status_quo_run_config);

            chunk_manifest_rows{end + 1} = struct( ...
                'program', program_name, ...
                'scenario_id', scenario_id, ...
                'rel_path', rel_paths{j}, ...
                'program_base_dir', base_dir, ...
                'scenario_dir', scenario_dir, ...
                'status_quo_key', status_quo_key, ...
                'status_quo_slug', slug, ...
                'status_quo_raw_dir', status_quo_raw_dir, ...
                'baseline_run_config_path', baseline_run_config_path, ...
                'run_config_path', fullfile(scenario_dir, 'run_config.yaml'), ...
                'run_type', run_type, ...
                'is_default', false);
        end
    end

    manifest_path = fullfile(root_dir, 'sensitivity_chunk_manifest.mat');
    chunk_manifest_rows = chunk_manifest_rows(:);
    manifest_run_type = run_type;
    save(manifest_path, 'chunk_manifest_rows', 'manifest_run_type', '-v7.3');
    fprintf('Wrote sensitivity manifest (%d rows): %s\n', numel(chunk_manifest_rows), manifest_path);

    sc_top = yaml.loadFile(config_path);
    sc_top.run_name = run_name;
    yaml.dumpFile(fullfile(root_dir, 'program_sensitivity_config.yaml'), sc_top);
end


function merged_struct = merge_struct_fields_local(base_struct, override_struct)
    merged_struct = base_struct;
    override_names = fieldnames(override_struct);
    for i = 1:length(override_names)
        fn = override_names{i};
        merged_struct.(fn) = override_struct.(fn);
    end
end


function status_quo_run_config = resolve_status_quo_run_config(base_config, override_fields, non_baseline_only_fields)
    status_quo_run_config = base_config;
    override_names = fieldnames(override_fields);
    for i = 1:length(override_names)
        fn = override_names{i};
        if ~any(strcmp(fn, non_baseline_only_fields))
            status_quo_run_config.(fn) = override_fields.(fn);
        end
    end
end
