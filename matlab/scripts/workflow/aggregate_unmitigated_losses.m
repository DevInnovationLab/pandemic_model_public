function aggregate_unmitigated_losses(sim_results_path)
    % Combine per-chunk unmitigated_losses.mat vectors into one file.
    %
    %   aggregate_unmitigated_losses(sim_results_path)
    %
    %   Call this after all SLURM array tasks have finished for a scenario to
    %   merge raw/chunk_*/unmitigated_losses.mat into sim_results_path/unmitigated_losses.mat.
    %
    %   Parameters
    %   ----------
    %   sim_results_path : char | string
    %       Path to the simulation results directory (contains raw/chunk_1, raw/chunk_2, ...).
    arguments
        sim_results_path (1,:) {mustBeText}
    end
    sim_results_path = char(sim_results_path);

    raw_path = fullfile(sim_results_path, 'raw');
    chunk_dirs = list_chunk_dirs(raw_path);
    if isempty(chunk_dirs)
        error('aggregate_unmitigated_losses:NoChunks', 'No chunk_* directories under %s', raw_path);
    end

    sim_total_deaths = [];
    sim_horizon_mortality_usd_social_pv = [];
    sim_horizon_output_usd_social_pv = [];
    sim_horizon_learning_usd_social_pv = [];
    sim_horizon_total_usd_social_pv = [];
    sim_horizon_total_usd_growth_path = [];
    sim_horizon_total_usd_flat_weights = [];
    outbreak_total_usd_social_pv = [];
    outbreak_total_usd_flat_weights = [];

    sim_fields = {'sim_total_deaths', ...
        'sim_horizon_mortality_usd_social_pv', 'sim_horizon_output_usd_social_pv', ...
        'sim_horizon_learning_usd_social_pv', 'sim_horizon_total_usd_social_pv', ...
        'sim_horizon_total_usd_growth_path', 'sim_horizon_total_usd_flat_weights'};
    outbreak_fields = {'outbreak_total_usd_social_pv', 'outbreak_total_usd_flat_weights'};
    chunk_fields = [sim_fields, outbreak_fields];

    for k = 1:numel(chunk_dirs)
        chunk_name = chunk_dirs(k).name;
        chunk_mat = fullfile(chunk_dirs(k).folder, chunk_name, 'unmitigated_losses.mat');
        if ~isfile(chunk_mat)
            error('aggregate_unmitigated_losses:MissingChunkMat', 'Missing %s', chunk_mat);
        end
        data = load(chunk_mat, chunk_fields{:});
        assert_chunk_has_fields(data, chunk_name, chunk_fields);

        sim_total_deaths = [sim_total_deaths; data.sim_total_deaths];
        sim_horizon_mortality_usd_social_pv = [sim_horizon_mortality_usd_social_pv; data.sim_horizon_mortality_usd_social_pv];
        sim_horizon_output_usd_social_pv = [sim_horizon_output_usd_social_pv; data.sim_horizon_output_usd_social_pv];
        sim_horizon_learning_usd_social_pv = [sim_horizon_learning_usd_social_pv; data.sim_horizon_learning_usd_social_pv];
        sim_horizon_total_usd_social_pv = [sim_horizon_total_usd_social_pv; data.sim_horizon_total_usd_social_pv];
        sim_horizon_total_usd_growth_path = [sim_horizon_total_usd_growth_path; data.sim_horizon_total_usd_growth_path];
        sim_horizon_total_usd_flat_weights = [sim_horizon_total_usd_flat_weights; data.sim_horizon_total_usd_flat_weights];
        outbreak_total_usd_social_pv = [outbreak_total_usd_social_pv; data.outbreak_total_usd_social_pv(:)];
        outbreak_total_usd_flat_weights = [outbreak_total_usd_flat_weights; data.outbreak_total_usd_flat_weights(:)];
    end

    out_path = fullfile(sim_results_path, 'unmitigated_losses.mat');
    save(out_path, ...
        'sim_total_deaths', ...
        'sim_horizon_mortality_usd_social_pv', ...
        'sim_horizon_output_usd_social_pv', ...
        'sim_horizon_learning_usd_social_pv', ...
        'sim_horizon_total_usd_social_pv', ...
        'sim_horizon_total_usd_growth_path', ...
        'sim_horizon_total_usd_flat_weights', ...
        'outbreak_total_usd_social_pv', ...
        'outbreak_total_usd_flat_weights', ...
        '-v7.3');
    fprintf('Aggregated unmitigated losses to %s\n', out_path);
end

function assert_chunk_has_fields(data, chunk_name, required_fields)
    % Error if a chunk mat file is missing any required variable.
    missing = required_fields(~arrayfun(@(f) isfield(data, f), required_fields));
    if ~isempty(missing)
        error('aggregate_unmitigated_losses:MissingChunkFields', ...
            'Chunk %s is missing: %s. Re-run estimate_unmitigated_losses for this chunk.', ...
            chunk_name, strjoin(missing, ', '));
    end
end
