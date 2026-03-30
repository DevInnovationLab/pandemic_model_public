function aggregate_results(sim_results_path)
    % Aggregate chunk results from a completed job run into processed outputs.
    %
    % Vertcats per-scenario relative_sums and baseline_sums tables across chunks
    % (same pattern for both). Downstream scripts take means when needed.

    raw_results_path = fullfile(sim_results_path, "raw");
    processed_dir = fullfile(sim_results_path, "processed");
    create_folders_recursively(processed_dir);

    % Load config to get scenario info
    config = yaml.loadFile(fullfile(sim_results_path, "job_config.yaml"));
    scenario_names = fieldnames(config.scenarios);

    chunk_dirs = dir(fullfile(raw_results_path, 'chunk_*'));
    chunk_numbers = cellfun(@(x) sscanf(x, 'chunk_%d'), {chunk_dirs.name});
    [~, sort_idx] = sort(chunk_numbers);
    chunk_dirs = chunk_dirs(sort_idx);

    for i = 1:length(scenario_names)
        scenario_name = scenario_names{i};
        if strcmp(scenario_name, 'baseline')
            continue;
        end
        fprintf('Processing scenario %s\n', scenario_name);

        scenario_sum_tables = cell(length(chunk_dirs), 1);
        for j = 1:length(chunk_dirs)
            chunk_dir = fullfile(raw_results_path, chunk_dirs(j).name);
            result_file = fullfile(chunk_dir, sprintf('%s_relative_sums.mat', scenario_name));
            scenario_sum_table = load(result_file).scenario_sum_table;
            scenario_sum_tables{j} = scenario_sum_table;
        end

        all_relative_sums = vertcat(scenario_sum_tables{:});
        save(fullfile(processed_dir, sprintf('%s_relative_sums.mat', scenario_name)), 'all_relative_sums', '-v7.3');
    end

    % Vertcat baseline_sums across chunks (same as relative_sums)
    baseline_tables = cell(length(chunk_dirs), 1);
    for j = 1:length(chunk_dirs)
        chunk_dir = fullfile(raw_results_path, chunk_dirs(j).name);
        sums_file = fullfile(chunk_dir, 'baseline_sums.mat');
        if ~exist(sums_file, 'file')
            error('aggregate_results:MissingBaseline', 'Missing %s. All chunk baseline_sums.mat files must exist before aggregation.', sums_file);
        end
        baseline_tables{j} = load(sums_file).baseline_sums;
    end
    if ~isempty(baseline_tables)
        all_baseline_sums = vertcat(baseline_tables{:});
        save(fullfile(processed_dir, 'baseline_annual_sums.mat'), 'all_baseline_sums', '-v7.3');
    end

    fprintf('Aggregation complete!\n');
end
