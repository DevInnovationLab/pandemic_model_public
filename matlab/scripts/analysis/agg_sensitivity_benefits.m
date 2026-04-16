function agg_sensitivity_results(sensitivity_dir)
    % Aggregate the sensitivity results from the sensitivity directory
    % Args:
    %   sensitivity_dir (string): Path to sensitivity directory
    % Returns:
    %   None
    
    % Create top-level processed directory
    top_processed_dir = fullfile(sensitivity_dir, 'processed');
    create_folders_recursively(top_processed_dir);
    
    % First, process baseline results
    baseline_dir = fullfile(sensitivity_dir, 'baseline');
    raw_dir = fullfile(baseline_dir, 'raw');

    if ~isfolder(raw_dir)
        error('agg_sensitivity_benefits:NoRaw', ...
            'Baseline raw directory not found: %s. Run sensitivity response first.', raw_dir);
    end

    [chunk_mat_paths, n_sims_per_chunk, n_periods] = resolve_baseline_annual_chunks(raw_dir);
    n_chunks = length(chunk_mat_paths);

    % Load run_config from baseline
    run_config_path = fullfile(baseline_dir, 'run_config.yaml');
    run_config = yaml.loadFile(run_config_path);

    % Preallocate array for sum of net values per simulation
    sum_net_values = zeros(n_sims_per_chunk * n_chunks, 1);
    % Preallocate arrays for net values over time
    net_value_pv_all = zeros(n_sims_per_chunk * n_chunks, n_periods);
    net_value_nom_all = zeros(n_sims_per_chunk * n_chunks, n_periods);

    % Load net_value from all chunks and calculate sums
    for k = 1:n_chunks
        S = load(chunk_mat_paths{k}, 'annual_results_baseline');
        start_idx = (k-1) * n_sims_per_chunk + 1;
        end_idx = k * n_sims_per_chunk;
        sum_net_values(start_idx:end_idx) = sum(S.annual_results_baseline.net_value_pv, 2);
        net_value_pv_all(start_idx:end_idx, :) = S.annual_results_baseline.net_value_pv;
        net_value_nom_all(start_idx:end_idx, :) = S.annual_results_baseline.net_value_nom;
    end
    
    % Calculate mean of sums
    mean_benefits = mean(sum_net_values);
    
    % Calculate mean net values over time
    mean_net_value_pv_over_time = mean(net_value_pv_all, 1);
    mean_net_value_nom_over_time = mean(net_value_nom_all, 1);
    
    % Save baseline results to top-level processed directory
    output_filename = 'baseline_benefits_summary.mat';
    output_path = fullfile(top_processed_dir, output_filename);
    save(output_path, 'mean_benefits', 'sum_net_values', 'run_config', ...
            'mean_net_value_pv_over_time', 'mean_net_value_nom_over_time');
    
    fprintf('Processed baseline: mean benefits = %.2f\n', mean_benefits);
    
    % Get scenario list from config (supports both one-parameter and multi-parameter layouts).
    [scenario_ids, scenario_paths] = get_sensitivity_scenarios(sensitivity_dir);
    
    for idx = 1:length(scenario_ids)
        scenario_id = scenario_ids{idx};
        value_dir = scenario_paths{idx};
        raw_dir = fullfile(value_dir, 'raw');
        
        if ~isfolder(raw_dir)
            warning('agg_sensitivity_results:NoRaw', 'Skipping %s: no raw dir at %s', scenario_id, raw_dir);
            continue;
        end

        try
            [chunk_mat_paths, n_sims_per_chunk, ~] = resolve_baseline_annual_chunks(raw_dir);
        catch me
            warning('agg_sensitivity_results:ChunkResolve', 'Skipping %s: %s', scenario_id, me.message);
            continue;
        end
        n_chunks = length(chunk_mat_paths);

        % Load run_config from scenario directory
        run_config_path = fullfile(value_dir, 'run_config.yaml');
        run_config = yaml.loadFile(run_config_path);

        % Preallocate array for sum of net values per simulation
        sum_net_values = zeros(n_sims_per_chunk * n_chunks, 1);

        % Load net_value from all chunks and calculate sums
        for k = 1:n_chunks
            S = load(chunk_mat_paths{k}, 'annual_results_baseline');
            start_idx = (k-1) * n_sims_per_chunk + 1;
            end_idx = k * n_sims_per_chunk;
            sum_net_values(start_idx:end_idx) = sum(S.annual_results_baseline.net_value_pv, 2);
        end
        
        % Calculate mean of sums
        mean_benefits = mean(sum_net_values);
        
        % Save to top-level processed directory with scenario_id in filename
        output_filename = sprintf('%s_benefits_summary.mat', scenario_id);
        output_path = fullfile(top_processed_dir, output_filename);
        save(output_path, 'mean_benefits', 'sum_net_values', 'scenario_id', 'run_config');
        
        fprintf('Processed %s: mean benefits = %.2f\n', scenario_id, mean_benefits);
    end
    
    fprintf('All sensitivity results aggregated and saved to %s\n', top_processed_dir);
end


function [chunk_mat_paths, n_sims_per_chunk, n_periods] = resolve_baseline_annual_chunks(raw_dir)
    % Resolve baseline_annual.mat locations: either raw/chunk_1, chunk_2, ... or raw/baseline_annual.mat.
    %
    % Returns:
    %   chunk_mat_paths (cell of char): Full paths to each baseline_annual.mat.
    %   n_sims_per_chunk (numeric): Sims in first chunk (used for prealloc).
    %   n_periods (numeric): Number of periods from first chunk.

    chunk_dirs = dir(fullfile(raw_dir, 'chunk_*'));
    chunk_dirs = chunk_dirs([chunk_dirs.isdir]);

    if ~isempty(chunk_dirs)
        chunk_numbers = zeros(length(chunk_dirs), 1);
        for k = 1:length(chunk_dirs)
            tokens = regexp(chunk_dirs(k).name, 'chunk_(\d+)', 'tokens');
            chunk_numbers(k) = str2double(tokens{1}{1});
        end
        [chunk_numbers, sort_idx] = sort(chunk_numbers);
        chunk_dirs = chunk_dirs(sort_idx);
        expected = 1:length(chunk_dirs);
        if ~isequal(chunk_numbers', expected)
            error('agg_sensitivity_benefits:ChunksNotContiguous', ...
                'Chunk numbers are not contiguous in %s. Found: %s.', raw_dir, mat2str(chunk_numbers'));
        end
        chunk_mat_paths = arrayfun(@(c) fullfile(raw_dir, c.name, 'baseline_annual.mat'), chunk_dirs, 'UniformOutput', false);
    else
        single_path = fullfile(raw_dir, 'baseline_annual.mat');
        if isfile(single_path)
            chunk_mat_paths = {single_path};
        else
            error('agg_sensitivity_benefits:NoChunks', ...
                'No chunk_* directories and no baseline_annual.mat in %s. Run sensitivity response first.', raw_dir);
        end
    end

    S_first = load(chunk_mat_paths{1}, 'annual_results_baseline');
    [n_sims_per_chunk, n_periods] = size(S_first.annual_results_baseline.net_value_pv);
end