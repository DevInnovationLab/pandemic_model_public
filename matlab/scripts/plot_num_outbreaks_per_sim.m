function plot_num_outbreaks_per_sim(job_dir)
    % Plot a histogram of the number of outbreaks per simulation for the baseline
    % scenario and save as CSV. Supports chunked raw results (raw/chunk_1, chunk_2, ...)
    % or a single raw/baseline_pandemic_table.mat.
    %
    % Args:
    %   job_dir (char/string): Directory containing job configuration and raw results.

    raw_dir = fullfile(job_dir, "raw");

    figure_dir = fullfile(job_dir, "figures");
    if ~exist(figure_dir, 'dir')
        mkdir(figure_dir);
    end

    scenario = 'baseline';
    pandemic_table = load_baseline_pandemic_table(raw_dir, scenario);

    % Count number of outbreaks per simulation (only rows with valid yr_start)
    valid_rows = ~isnan(pandemic_table.yr_start);
    sim_nums = pandemic_table.sim_num(valid_rows);
    num_sims = max(pandemic_table.sim_num);
    num_outbreaks = accumarray(sim_nums, 1, [num_sims, 1], @sum, 0);

    % Plot histogram (probability normalization)
    fig = figure('Color', 'w', 'Position', [200 200 700 500]);
    histogram(num_outbreaks, 'Normalization', 'probability', ...
        'FaceColor', [0.2 0.5 0.8], 'EdgeColor', 'k', 'LineWidth', 1.2);
    xlabel('Number of outbreaks per simulation', 'FontSize', 14, 'FontWeight', 'normal');
    ylabel('Probability', 'FontSize', 14, 'FontWeight', 'normal');
    title('Distribution of outbreaks per simulation: Baseline', ...
        'FontSize', 16, 'FontWeight', 'normal');
    grid on;
    ax = gca;
    ax.GridAlpha = 0.3;
    ax.GridColor = [0.6 0.6 0.6];

    % Save figure
    fig_name = 'num_outbreaks_per_sim_baseline';
    print(fig, fullfile(figure_dir, fig_name), '-dpng', '-r600');
    close(fig);

    % Save histogram data as CSV
    [counts, edges] = histcounts(num_outbreaks, 'Normalization', 'probability');
    bin_centers = edges(1:end-1) + diff(edges)/2;
    T = table(bin_centers(:), counts(:), 'VariableNames', {'num_outbreaks', 'probability'});
    writetable(T, fullfile(job_dir, 'baseline_num_outbreaks_per_sim.csv'));
end

function pandemic_table = load_baseline_pandemic_table(raw_dir, scenario)
    % Load baseline pandemic table from chunked (raw/chunk_1, ...) or single file.
    chunk_dirs = dir(fullfile(raw_dir, 'chunk_*'));
    chunk_dirs = chunk_dirs([chunk_dirs.isdir]);

    if ~isempty(chunk_dirs)
        chunk_numbers = cellfun(@(x) sscanf(x, 'chunk_%d'), {chunk_dirs.name});
        [~, sort_idx] = sort(chunk_numbers);
        chunk_dirs = chunk_dirs(sort_idx);
        pandemic_tables = cell(length(chunk_dirs), 1);
        n_loaded = 0;
        for i = 1:length(chunk_dirs)
            chunk_path = fullfile(raw_dir, chunk_dirs(i).name, sprintf('%s_pandemic_table.mat', scenario));
            if isfile(chunk_path)
                S = load(chunk_path);
                n_loaded = n_loaded + 1;
                pandemic_tables{n_loaded} = S.pandemic_table;
            end
        end
        pandemic_tables = pandemic_tables(1:n_loaded);
        if isempty(pandemic_tables)
            error('plot_num_outbreaks_per_sim: no baseline pandemic table found in any chunk under %s', raw_dir);
        end
        pandemic_table = vertcat(pandemic_tables{:});
    else
        single_path = fullfile(raw_dir, sprintf('%s_pandemic_table.mat', scenario));
        if ~isfile(single_path)
            error('plot_num_outbreaks_per_sim: no baseline pandemic table at %s and no chunk_* dirs in %s', single_path, raw_dir);
        end
        S = load(single_path);
        pandemic_table = S.pandemic_table;
    end
end