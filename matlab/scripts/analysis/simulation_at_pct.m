function [out_tbl, info] = simulation_at_pct(job_dir, scenario_name, percentile)
    % Return pandemic table rows for the simulation nearest a target NPV percentile.
    %
    % Invest-style NPV matches write_invest_scenario_table / load_scenario_means:
    %   - Baseline: benefits_vaccine_full - costs_inp_pv_full (absolute).
    %   - Preparedness: tot_benefits_pv_full - costs_adv_invest_pv_full from relative_sums
    %     (incremental vs baseline; advance investment cost only).
    %
    % Simulation index is chosen so NPV is closest to prctile(npv, percentile).
    % The target chunk is discovered by checking chunk files directly, rather than
    % inferring chunk ranges from chunk counts.
    %
    % Args:
    %   job_dir (char/string): Completed job directory (job_config.yaml, raw/, processed/).
    %   scenario_name (char/string): "baseline" or a scenario name.
    %   percentile (double): Value in [0, 100].
    %
    % Returns:
    %   out_tbl (table): Rows for the selected sim_num (real outbreaks: finite yr_start).
    %   info (struct): sim_num, invest_npv, scenario_name, percentile, csv_path, chunk_idx,
    %     pandemic_mat_path, num_simulations.

    job_dir = char(string(job_dir));
    is_baseline = strcmpi(scenario_name, 'baseline');

    processed_dir = fullfile(job_dir, 'processed');
    if is_baseline
        S = load(fullfile(processed_dir, 'baseline_annual_sums.mat'), 'all_baseline_sums');
        r = S.all_baseline_sums;
        npv = r.benefits_vaccine_full - r.costs_inp_pv_full;
    else
        S = load(fullfile(processed_dir, sprintf('%s_relative_sums.mat', scenario_name)), 'all_relative_sums');
        r = S.all_relative_sums;
        npv = r.tot_benefits_pv_full - r.costs_adv_invest_pv_full;
    end

    N = height(r);
    target = prctile(npv, percentile);
    [~, sim_num] = min(abs(npv - target));
    npv_sel = npv(sim_num);

    [out_tbl, pan_path, chunk_idx] = load_rows_for_sim(job_dir, scenario_name, sim_num);

    csv_path = fullfile(processed_dir, sprintf('%s_pandemic_p%.0f.csv', scenario_name, percentile));
    writetable(out_tbl, csv_path);

    info = struct();
    info.scenario_name = scenario_name;
    info.percentile = percentile;
    info.sim_num = sim_num;
    info.invest_npv = npv_sel;
    info.csv_path = csv_path;
    info.chunk_idx = chunk_idx;
    info.pandemic_mat_path = pan_path;
    info.num_simulations = N;
end


function [out_tbl, pan_path, chunk_idx] = load_rows_for_sim(job_dir, scenario_name, sim_num)
    % Locate the correct chunk by searching for the selected global sim_num.
    raw_dir = fullfile(job_dir, 'raw');
    chunk_dirs = dir(fullfile(raw_dir, 'chunk_*'));
    chunk_dirs = chunk_dirs([chunk_dirs.isdir]);
    if isempty(chunk_dirs)
        error('simulation_at_pct:NoChunks', 'No raw/chunk_* directories under %s.', raw_dir);
    end

    parsed_idx = nan(size(chunk_dirs));
    for i = 1:numel(chunk_dirs)
        parsed_idx(i) = sscanf(chunk_dirs(i).name, 'chunk_%d');
    end
    [~, order] = sort(parsed_idx);
    chunk_dirs = chunk_dirs(order);

    for i = 1:numel(chunk_dirs)
        chunk_name = chunk_dirs(i).name;
        cand_path = fullfile(raw_dir, chunk_name, sprintf('%s_pandemic_table.mat', scenario_name));
        if ~isfile(cand_path)
            continue;
        end

        Pan = load(cand_path, 'pandemic_table');
        full_tbl = Pan.pandemic_table;
        cand_tbl = full_tbl(full_tbl.sim_num == sim_num, :);
        cand_tbl = cand_tbl(~isnan(cand_tbl.yr_start), :);
        if ~isempty(cand_tbl)
            out_tbl = cand_tbl;
            pan_path = cand_path;
            chunk_idx = sscanf(chunk_name, 'chunk_%d');
            return;
        end
    end

    error('simulation_at_pct:SimNotFound', ...
        'No rows with sim_num=%d found in any chunk for scenario "%s" under %s.', ...
        sim_num, scenario_name, raw_dir);
end
