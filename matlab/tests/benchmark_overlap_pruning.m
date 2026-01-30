%% Benchmark: single-pass vs splitapply overlap pruning
% Paste this into a script and run. Requires a table with sim_num, yr_start, yr_end, intensity.

function benchmark_overlap_pruning()
    rng(42);
    % Test sizes: [num_rows]. Tune for your machine.
    n_rows_list = round([1e4, 5e4, 1e5, 2e5, 5e5, 5e6]);
    n_warmup = 1;
    n_trials = 3;

    fprintf('%-12s %-12s %-12s %-10s\n', 'N_rows', 'SplitApply(s)', 'SinglePass(s)', 'Speedup');
    fprintf('%s\n', repmat('-', 1, 50));

    for n_rows = n_rows_list
        tbl = make_synthetic_table(n_rows);
        % Warmup
        [~, ~, ~] = prune_splitapply(tbl);
        [~, ~, ~] = prune_singlepass(tbl);
        for w = 1:n_warmup
            [~, ~, ~] = prune_splitapply(tbl);
            [~, ~, ~] = prune_singlepass(tbl);
        end
        % Time splitapply
        t_split = inf;
        for t = 1:n_trials
            tic;
            [~, ~, ~] = prune_splitapply(tbl);
            t_split = min(t_split, toc);
        end
        % Time single-pass
        t_single = inf;
        for t = 1:n_trials
            tic;
            [~, ~, ~] = prune_singlepass(tbl);
            t_single = min(t_single, toc);
        end
        speedup = t_split / t_single;
        fprintf('%-12d %-12.4f %-12.4f %-10.2fx\n', n_rows, t_split, t_single, speedup);
    end
end

function tbl = make_synthetic_table(n_rows)
    % Produce overlapping intervals per sim: many sims, few rows per sim on average.
    n_sims = max(2, round(n_rows / 50));
    sim_num = randi(n_sims, n_rows, 1);
    yr_start = randi(180, n_rows, 1);
    dur = randi(15, n_rows, 1);
    yr_end = min(yr_start + dur - 1, 200);
    intensity = rand(n_rows, 1) * 100;
    tbl = table(sim_num, yr_start, yr_end, intensity);
    tbl = sortrows(tbl, {'sim_num', 'yr_start'});
end

%% Splitapply + trim_overlaps (mirrors get_base_simulation_table)
function [tbl_out, num_removed, num_trimmed] = prune_splitapply(tbl)
    [sim_groups, ~] = findgroups(tbl.sim_num);
    idx = (1:height(tbl))';
    payloads = splitapply(@(I) local_trim(I, tbl), idx, sim_groups);
    tbl_out = vertcat(payloads.tbl);
    num_removed = sum([payloads.num_removed]);
    num_trimmed = sum([payloads.num_trimmed]);
end

function S = local_trim(I, simulation_table)
    [tbl_i, num_removed, num_trimmed] = trim_overlaps(simulation_table(I,:));
    S = struct('tbl', {tbl_i}, 'num_removed', num_removed, 'num_trimmed', num_trimmed);
end

function [tbl, num_removed, num_trimmed] = trim_overlaps(tbl)
    tbl = sortrows(tbl, 'yr_start');
    n = height(tbl);
    keep = true(n,1);
    removed = false(n,1);
    trimmed = false(n,1);
    active_idx = 1;
    yr_start = tbl.yr_start;
    yr_end = tbl.yr_end;
    intensity = tbl.intensity;
    for k = 2:n
        if tbl.yr_start(k) > yr_end(active_idx)
            active_idx = k;
            continue;
        end
        if intensity(k) > intensity(active_idx)
            trimmed(active_idx) = true;
            yr_end(active_idx) = tbl.yr_start(k) - 1;
            active_idx = k;
        else
            keep(k) = false;
            removed(k) = true;
        end
    end
    tbl.yr_end = yr_end;
    tbl = tbl(keep,:);
    num_removed = sum(removed);
    num_trimmed = sum(trimmed);
end

%% Single-pass over full table (no splitapply)
function [tbl_out, num_removed, num_trimmed] = prune_singlepass(tbl)
    tbl = sortrows(tbl, {'sim_num', 'yr_start'});
    n = height(tbl);
    sim_num = tbl.sim_num;
    yr_start = tbl.yr_start;
    yr_end = tbl.yr_end;
    intensity = tbl.intensity;
    keep = true(n,1);
    removed = false(n,1);
    trimmed = false(n,1);
    active_idx = 1;

    for k = 2:n
        if sim_num(k) ~= sim_num(active_idx) || yr_start(k) > yr_end(active_idx)
            active_idx = k;
            continue;
        end
        if intensity(k) > intensity(active_idx)
            trimmed(active_idx) = true;
            yr_end(active_idx) = yr_start(k) - 1;
            active_idx = k;
        else
            keep(k) = false;
            removed(k) = true;
        end
    end

    tbl.yr_end = yr_end;
    tbl_out = tbl(keep,:);
    num_removed = sum(removed);
    num_trimmed = sum(trimmed);
end