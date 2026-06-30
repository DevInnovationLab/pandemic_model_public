function run_sensitivity(config_path, run_type, varargin)
    % Run a sensitivity analysis defined by a sensitivity config file.
    %
    % Expects a program-scoped config with a program_sensitivities block,
    % where each program defines its own fix_params and sensitivities.
    %
    % Outputs are written under outdir/<run_name>/<program_name>/...
    %
    % Orchestration:
    %   - Local full run: optionally deletes run root (overwrite true), writes manifest if
    %     needed, then runs all chunks (array_task_id = nan). With overwrite false, skips
    %     rows whose outputs already exist for those chunks.
    %   - SLURM chunk worker: set array_task_id = chunk index; expects manifest on disk.
    %     With overwrite false, skips work for that chunk when outputs already exist.
    %
    % Args:
    %   config_path  Path to the sensitivity YAML config file.
    %   run_type     'response' (full model via run_model) or 'unmitigated'
    %                (no-intervention model via estimate_unmitigated_losses).
    %
    % Name-value parameters:
    %   overwrite       If true (default), delete the sensitivity run root and rewrite the
    %                   manifest before running. If false, keep existing outputs and skip
    %                   manifest rows whose chunk outputs already exist (resume).
    %   num_chunks      Chunks to split simulations across (default: 1).
    %   array_task_id   SLURM chunk index 1..num_chunks, or nan for all chunks locally.

    p = inputParser;
    addParameter(p, 'overwrite', true, @islogical);
    addParameter(p, 'num_chunks', 1, @isnumeric);
    addParameter(p, 'array_task_id', nan, @isnumeric);
    parse(p, varargin{:});

    overwrite = p.Results.overwrite;
    num_chunks = p.Results.num_chunks;
    array_task_id = p.Results.array_task_id;
    skip_completed = ~overwrite;

    fprintf('Loading configuration files...\n');
    sensitivity_config = yaml.loadFile(config_path);
    [~, run_name, ~] = fileparts(config_path);
    sensitivity_config.run_name = run_name;

    root_dir = fullfile(sensitivity_config.outdir, sensitivity_config.run_name);
    is_chunk_worker = ~isnan(array_task_id);
    manifest_path = fullfile(root_dir, 'sensitivity_chunk_manifest.mat');

    if ~is_chunk_worker
        if overwrite && exist(root_dir, 'dir')
            rmdir(root_dir, 's');
        end
        create_folders_recursively(root_dir);
        if overwrite || ~isfile(manifest_path)
            write_sensitivity_manifest(config_path, run_type);
        end
    else
        if ~isfile(manifest_path)
            error('Chunk worker requires manifest: %s', manifest_path);
        end
    end

    run_sensitivity_chunk_job(config_path, run_type, num_chunks, array_task_id, ...
        'skip_completed', skip_completed);
end
