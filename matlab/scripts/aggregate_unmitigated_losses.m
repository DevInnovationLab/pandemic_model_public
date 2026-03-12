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
    chunk_dirs = dir(fullfile(raw_path, 'chunk_*'));
    chunk_dirs = chunk_dirs([chunk_dirs.isdir]);
    if isempty(chunk_dirs)
        error('aggregate_unmitigated_losses:NoChunks', 'No chunk_* directories found under %s', raw_path);
    end
    % Sort by chunk index (chunk_1, chunk_2, ...)
    [~, order] = sort(cellfun(@(name) str2double(regexp(char(name), '\d+', 'match', 'once')), {chunk_dirs.name}));
    chunk_dirs = chunk_dirs(order);

    total_deaths = [];
    total_mortality_losses = [];
    total_output_losses = [];
    total_learning_losses = [];
    total_total_losses = [];

    for k = 1:numel(chunk_dirs)
        chunk_mat = fullfile(chunk_dirs(k).folder, chunk_dirs(k).name, 'unmitigated_losses.mat');
        if ~isfile(chunk_mat)
            error('aggregate_unmitigated_losses:MissingChunk', 'Missing %s', chunk_mat);
        end
        data = load(chunk_mat, 'total_deaths', 'total_mortality_losses', 'total_output_losses', ...
            'total_learning_losses', 'total_total_losses');
        total_deaths = [total_deaths; data.total_deaths];
        total_mortality_losses = [total_mortality_losses; data.total_mortality_losses];
        total_output_losses = [total_output_losses; data.total_output_losses];
        total_learning_losses = [total_learning_losses; data.total_learning_losses];
        total_total_losses = [total_total_losses; data.total_total_losses];
    end

    save(fullfile(sim_results_path, 'unmitigated_losses.mat'), ...
        'total_deaths', ...
        'total_mortality_losses', ...
        'total_output_losses', ...
        'total_learning_losses', ...
        'total_total_losses', ...
        '-v7.3');
    fprintf('Aggregated unmitigated losses to %s\n', fullfile(sim_results_path, 'unmitigated_losses.mat'));
end
