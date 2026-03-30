function [out_tbl, info] = pandemic_at_pct(job_dir, scenario_name, percentile)
    % Pandemic table rows for the simulation closest to a given invest-NPV percentile.
    %
    % Invest-style NPV matches write_invest_scenario_table / load_scenario_means:
    %   - Baseline: benefits_vaccine_full - costs_inp_pv_full (absolute).
    %   - Preparedness: tot_benefits_pv_full - costs_adv_invest_pv_full from relative_sums
    %     (incremental vs baseline; advance investment cost only).
    %
    % Simulation index is chosen so NPV is closest to prctile(npv, percentile).
    %
    % Args:
    %   job_dir (char/string): Completed job directory (job_config.yaml, raw/, processed/).
    %   scenario_name (char/string): "baseline" or a scenario name.
    %   percentile (double): Value in [0, 100].
    %
    % Name-value:
    %   OutputCsvPath (char/string): Override CSV path. Default:
    %     processed/pandemic_p{percentile}_{scenario}.csv
    %
    % Returns:
    %   out_tbl (table): Rows for the selected sim_num (real outbreaks: finite yr_start).
    %   info (struct): sim_num, invest_npv, scenario_name, percentile, csv_path, chunk_idx,
    %     pandemic_mat_path, num_simulations.

    job_dir = char(string(job_dir));
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
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

    raw_dir = fullfile(job_dir, 'raw');
    chunk_idx = chunk_index_for_sim(sim_num, config.num_simulations, raw_dir);
    if isempty(chunk_idx)
        error('pandemic_at_pct:ChunkMap', 'Could not map sim_num=%d to a chunk under %s.', sim_num, raw_dir);
    end
    pan_path = fullfile(raw_dir, sprintf('chunk_%d', chunk_idx), sprintf('%s_pandemic_table.mat', scenario_name));

    Pan = load(pan_path, 'pandemic_table');
    full_tbl = Pan.pandemic_table;
    out_tbl = full_tbl(full_tbl.sim_num == sim_num, :);
    out_tbl = out_tbl(~isnan(out_tbl.yr_start), :);

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


function chunk_idx = chunk_index_for_sim(sim_num, num_simulations, raw_dir)
    chunk_dirs = dir(fullfile(raw_dir, 'chunk_*'));
    chunk_dirs = chunk_dirs([chunk_dirs.isdir]);
    if isempty(chunk_dirs)
        error('pandemic_at_pct:NoChunks', 'No raw/chunk_* directories under %s.', raw_dir);
    end
    chunk_numbers = cellfun(@(x) sscanf(x, 'chunk_%d'), {chunk_dirs.name});
    num_chunks = max(chunk_numbers);

    chunk_size = ceil(num_simulations / num_chunks);
    chunk_starts = 1:chunk_size:num_simulations;
    chunk_ends = [chunk_starts(2:end) - 1, num_simulations];
    chunk_idx = find(sim_num >= chunk_starts & sim_num <= chunk_ends, 1);
end
