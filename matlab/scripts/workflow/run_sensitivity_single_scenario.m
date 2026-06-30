function run_sensitivity_single_scenario(run_config, run_type, num_chunks, array_task_id, varargin)
    % Run a single sensitivity scenario or baseline-only job using a staging directory.
    %
    % Staging avoids concurrent movefile races when multiple SLURM tasks write different
    % chunks into the same final scenario directory.
    %
    % Args:
    %   run_config (struct): Configuration (outdir is the final output root).
    %   run_type (string): 'response' or 'unmitigated'.
    %   num_chunks (numeric): Number of simulation chunks.
    %   array_task_id (numeric): Chunk index for SLURM, or nan for all chunks in process.
    %
    % Name-value pairs:
    %   baseline_mode, baseline_reference_raw — passed through to run_model when run_type is response.

    p = inputParser;
    addParameter(p, 'baseline_mode', 'full', @(x) ischar(x) || isStringScalar(x));
    addParameter(p, 'baseline_reference_raw', '', @(x) ischar(x) || isStringScalar(x));
    parse(p, varargin{:});

    baseline_mode = char(string(p.Results.baseline_mode));
    baseline_reference_raw = char(string(p.Results.baseline_reference_raw));

    raw_outdir = char(string(run_config.outdir));
    final_outdir = normalize_sensitivity_final_outdir(raw_outdir);
    is_chunk_worker = ~isnan(array_task_id);
    if is_chunk_worker
        staging_id = sprintf('.run_staging_chunk_%d', array_task_id);
    else
        staging_id = '.run_staging_all';
    end
    stage_root = fullfile(final_outdir, staging_id);
    create_folders_recursively(stage_root);

    rc = run_config;
    rc.outdir = stage_root;
    staging_yaml = fullfile(stage_root, 'run_config.yaml');
    yaml.dumpFile(staging_yaml, rc);

    if strcmp(run_type, "response")
        run_model(staging_yaml, 'num_chunks', num_chunks, 'array_task_id', array_task_id, ...
            'baseline_mode', baseline_mode, 'baseline_reference_raw', baseline_reference_raw);
    elseif strcmp(run_type, "unmitigated")
        estimate_unmitigated_losses(staging_yaml, 'num_chunks', num_chunks, 'array_task_id', array_task_id);
    else
        error('run_type must be response or unmitigated, got: %s', string(run_type));
    end

    promote_staging_outputs(stage_root, final_outdir, num_chunks, array_task_id, run_type);

    if exist(stage_root, 'dir')
        rmdir(stage_root, 's');
    end
end


function promote_staging_outputs(stage_root, final_outdir, num_chunks, array_task_id, run_type)
    % Move staging outputs from run_model / estimate_unmitigated_losses into final_outdir.

    is_chunk_worker = ~isnan(array_task_id);
    % run_model writes under <outdir>/<run_config_name>; staging_yaml is run_config.yaml,
    % so chunk outputs live under <stage_root>/run_config.
    sim_staging = fullfile(stage_root, 'run_config');

    if strcmp(run_type, "unmitigated") && num_chunks == 1
        ufile = fullfile(sim_staging, 'unmitigated_losses.mat');
        if isfile(ufile)
            copyfile(ufile, fullfile(final_outdir, 'unmitigated_losses.mat'));
            delete(ufile);
        end
        cfg_src = fullfile(sim_staging, 'run_config.yaml');
        if isfile(cfg_src)
            copyfile(cfg_src, fullfile(final_outdir, 'run_config.yaml'));
            delete(cfg_src);
        end
        return;
    end

    if ~exist(sim_staging, 'dir')
        error('Expected staging directory missing: %s', sim_staging);
    end

    raw_staging = fullfile(sim_staging, 'raw');
    raw_final = fullfile(final_outdir, 'raw');
    create_folders_recursively(raw_final);

    if is_chunk_worker
        k = array_task_id;
        src_chunk = fullfile(raw_staging, sprintf('chunk_%d', k));
        dst_chunk = fullfile(raw_final, sprintf('chunk_%d', k));
        if exist(src_chunk, 'dir')
            if exist(dst_chunk, 'dir')
                rmdir(dst_chunk, 's');
            end
            movefile(src_chunk, dst_chunk);
        end
        cfg_src = fullfile(sim_staging, 'run_config.yaml');
        if isfile(cfg_src)
            copyfile(cfg_src, fullfile(final_outdir, 'run_config.yaml'));
        end
    else
        if exist(raw_staging, 'dir')
            d = dir(raw_staging);
            for ii = 1:numel(d)
                if strcmp(d(ii).name, '.') || strcmp(d(ii).name, '..')
                    continue;
                end
                srcp = fullfile(raw_staging, d(ii).name);
                dstp = fullfile(raw_final, d(ii).name);
                if exist(dstp, 'dir') || isfile(dstp)
                    if isfolder(srcp)
                        rmdir(dstp, 's');
                    else
                        delete(dstp);
                    end
                end
                movefile(srcp, dstp);
            end
            try
                rmdir(raw_staging, 's');
            catch
            end
        end
        cfg_src = fullfile(sim_staging, 'run_config.yaml');
        if isfile(cfg_src)
            copyfile(cfg_src, fullfile(final_outdir, 'run_config.yaml'));
        end
        uagg = fullfile(sim_staging, 'unmitigated_losses.mat');
        if strcmp(run_type, "unmitigated") && isfile(uagg)
            copyfile(uagg, fullfile(final_outdir, 'unmitigated_losses.mat'));
            delete(uagg);
        end
    end

    fig_staging = fullfile(sim_staging, 'figures');
    if exist(fig_staging, 'dir')
        fig_final = fullfile(final_outdir, 'figures');
        create_folders_recursively(fig_final);
        d = dir(fig_staging);
        for ii = 1:numel(d)
            if strcmp(d(ii).name, '.') || strcmp(d(ii).name, '..')
                continue;
            end
            movefile(fullfile(fig_staging, d(ii).name), fullfile(fig_final, d(ii).name));
        end
        try
            rmdir(fig_staging, 's');
        catch
        end
    end

    cfg_root = fullfile(sim_staging, 'run_config.yaml');
    if isfile(cfg_root)
        copyfile(cfg_root, fullfile(final_outdir, 'run_config.yaml'));
        delete(cfg_root);
    end

    if exist(sim_staging, 'dir')
        try
            rmdir(sim_staging, 's');
        catch
        end
    end
end


function p = normalize_sensitivity_final_outdir(p)
    % Remove trailing .run_staging_all / .run_staging_chunk_* path segments.
    %
    % Promoted run_config.yaml can still list outdir under staging; the next run would
    % otherwise nest .run_staging_all again.
    %
    % Do not use fileparts for repeated ".run_staging_all": MATLAB can parse
    % "...\.run_staging_all\.run_staging_all" as name/extension instead of two folders.

    p = char(string(p));
    tok = '.run_staging_all';
    lt = length(tok);
    while length(p) >= lt && strcmp(p(end-lt+1:end), tok)
        p = p(1:end-lt);
        p = strip_trailing_filesep_local(p);
    end

    chunk_pat = '[/\\]\.run_staging_chunk_\d+$';
    while true
        q = regexprep(p, chunk_pat, '');
        if strcmp(q, p)
            break;
        end
        p = strip_trailing_filesep_local(q);
    end
end


function p = strip_trailing_filesep_local(p)
    while ~isempty(p) && (p(end) == '/' || p(end) == '\')
        p = p(1:end-1);
    end
end
