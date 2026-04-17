function aggregate_unmitigated_losses(sim_results_path)
    % Combine chunk simulation-wide sum vectors into a single unmitigated_losses.mat.
    %
    %   aggregate_unmitigated_losses(sim_results_path)
    %
    %   Call this after all SLURM array tasks have finished for a scenario to
    %   merge raw/chunk_*/unmitigated_losses.mat (total_* vectors) into
    %   sim_results_path/unmitigated_losses.mat.
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
        error('aggregate_unmitigated_losses:NoChunks', 'No chunk_* directories found under %s', raw_path);
    end

    sim_total_deaths = [];
    sim_mortality_loss = [];
    sim_output_loss = [];
    sim_learning_loss = [];
    sim_total_loss = [];
    sim_total_loss_undiscounted = [];
    outbreak_is_false_positive = [];
    outbreak_total_loss = [];

    for k = 1:numel(chunk_dirs)
        chunk_mat = fullfile(chunk_dirs(k).folder, chunk_dirs(k).name, 'unmitigated_losses.mat');
        if ~isfile(chunk_mat)
            error('aggregate_unmitigated_losses:MissingChunk', 'Missing %s', chunk_mat);
        end
        data = load(chunk_mat, 'sim_total_deaths', 'sim_mortality_loss', 'sim_output_loss', ...
            'sim_learning_loss', 'sim_total_loss', 'sim_total_loss_undiscounted', 'outbreak_is_false_positive', 'outbreak_total_loss');
        sim_total_deaths = [sim_total_deaths; data.sim_total_deaths];
        sim_mortality_loss = [sim_mortality_loss; data.sim_mortality_loss];
        sim_output_loss = [sim_output_loss; data.sim_output_loss];
        sim_learning_loss = [sim_learning_loss; data.sim_learning_loss];
        sim_total_loss = [sim_total_loss; data.sim_total_loss];
        sim_total_loss_undiscounted = [sim_total_loss_undiscounted; data.sim_total_loss_undiscounted];
        if isfield(data, 'outbreak_is_false_positive') && isfield(data, 'outbreak_total_loss')
            outbreak_is_false_positive = [outbreak_is_false_positive; data.outbreak_is_false_positive(:)];
            outbreak_total_loss = [outbreak_total_loss; data.outbreak_total_loss(:)];
        end
    end

    out_path = fullfile(sim_results_path, 'unmitigated_losses.mat');
    if ~isempty(outbreak_total_loss)
        save(out_path, ...
            'sim_total_deaths', ...
            'sim_mortality_loss', ...
            'sim_output_loss', ...
            'sim_learning_loss', ...
            'sim_total_loss', ...
            'sim_total_loss_undiscounted', ...
            'outbreak_is_false_positive', ...
            'outbreak_total_loss', ...
            '-v7.3');
    else
        save(out_path, ...
            'sim_total_deaths', ...
            'sim_mortality_loss', ...
            'sim_output_loss', ...
            'sim_learning_loss', ...
            'sim_total_loss', ...
            'sim_total_loss_undiscounted', ...
            '-v7.3');
    end
    fprintf('Aggregated unmitigated losses to %s\n', out_path);
end
