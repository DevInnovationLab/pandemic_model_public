function compare_exceedances(sensitivity_dir)
% Compare exceedance curves from airborne sensitivity run (no mitigation, realized mitigation, vaccines always work).
%
% Uses output from run_sensitivity(..., 'response') with
% config/sensitivity_configs/baseline_vaccine_program_airborne.yaml:
%   - sensitivity_dir/baseline/  : baseline run (vaccines can fail)
%   - sensitivity_dir/ptrs_pathogen/value_1/ : run with vaccines-always-succeed PTRs
%
% Plots three curves: no mitigation (eff_severity), realized mitigation (baseline ex_post),
% vaccines always work (value_1 ex_post), plus Madhav et al. reference.
%
% Args:
%   sensitivity_dir (char): Path to sensitivity run root (e.g. output/sensitivity/baseline_vaccine_program_airborne)

    baseline_dir = fullfile(sensitivity_dir, 'baseline');
    value1_dir   = fullfile(sensitivity_dir, 'ptrs_pathogen', 'value_1');

    if ~isfolder(baseline_dir)
        error('compare_exceedances:NoBaseline', 'Baseline directory not found: %s', baseline_dir);
    end
    if ~isfolder(value1_dir)
        error('compare_exceedances:NoValue1', 'ptrs_pathogen/value_1 not found: %s', value1_dir);
    end

    % Load job config from baseline (chunk layout and sizes)
    job_config = yaml.loadFile(fullfile(baseline_dir, 'job_config.yaml'));
    sim_periods = job_config.sim_periods;
    num_simulations = job_config.num_simulations;

    raw_baseline = fullfile(baseline_dir, 'raw');
    raw_value1   = fullfile(value1_dir, 'raw');

    base_vars = {'sim_num', 'yr_start', 'eff_severity', 'is_false'};
    pandemic_vars = {'sim_num', 'yr_start', 'ex_post_severity', 'is_false'};

    chunk_dirs_b = dir(fullfile(raw_baseline, 'chunk_*'));
    chunk_dirs_b = chunk_dirs_b([chunk_dirs_b.isdir]);
    chunk_nums   = cellfun(@(x) sscanf(x, 'chunk_%d'), {chunk_dirs_b.name});
    [~, sort_idx] = sort(chunk_nums);
    chunk_dirs_b = chunk_dirs_b(sort_idx);
    num_chunks   = length(chunk_dirs_b);

    all_base = cell(num_chunks, 1);
    all_pandemic_baseline = cell(num_chunks, 1);
    all_pandemic_value1   = cell(num_chunks, 1);
    n_base = 0;
    n_pan_b = 0;
    n_pan_v1 = 0;

    for i = 1:num_chunks
        ch_name = chunk_dirs_b(i).name;
        chunk_b = fullfile(raw_baseline, ch_name);
        chunk_v1 = fullfile(raw_value1, ch_name);

        % Base table (same for both runs)
        base_path = fullfile(chunk_b, 'base_simulation_table.mat');
        S = load(base_path, 'base_simulation_table');
        base_t = S.base_simulation_table(:, base_vars);
        base_t = base_t(~base_t.is_false & ~isnan(base_t.yr_start), :);
        base_t.is_false = [];
        n_base = n_base + 1;
        all_base{n_base} = base_t;

        % Baseline pandemic table (vaccines can fail)
        pan_b_path = fullfile(chunk_b, 'baseline_pandemic_table.mat');
        if isfile(pan_b_path)
            S = load(pan_b_path, 'pandemic_table');
            pan_t = S.pandemic_table(:, pandemic_vars);
            pan_t = pan_t(~pan_t.is_false & ~isnan(pan_t.yr_start), :);
            pan_t.is_false = [];
            n_pan_b = n_pan_b + 1;
            all_pandemic_baseline{n_pan_b} = pan_t;
        end

        % Value_1 pandemic table (vaccines always work)
        pan_v1_path = fullfile(chunk_v1, 'baseline_pandemic_table.mat');
        if isfile(pan_v1_path)
            S = load(pan_v1_path, 'pandemic_table');
            pan_t = S.pandemic_table(:, pandemic_vars);
            pan_t = pan_t(~pan_t.is_false & ~isnan(pan_t.yr_start), :);
            pan_t.is_false = [];
            n_pan_v1 = n_pan_v1 + 1;
            all_pandemic_value1{n_pan_v1} = pan_t;
        end
    end

    base_merged = vertcat(all_base{1:n_base});
    pandemic_baseline = vertcat(all_pandemic_baseline{1:n_pan_b});
    pandemic_value1   = vertcat(all_pandemic_value1{1:n_pan_v1});
    clear all_base all_pandemic_baseline all_pandemic_value1 S base_t pan_t;

    % Severity matrices: (sim_num, yr_start) -> severity
    no_mitigation_matrix = zeros(num_simulations, sim_periods);
    realized_matrix      = zeros(num_simulations, sim_periods);
    always_work_matrix   = zeros(num_simulations, sim_periods);

    idx = sub2ind([num_simulations, sim_periods], base_merged.sim_num, base_merged.yr_start);
    no_mitigation_matrix(idx) = base_merged.eff_severity;

    keys_b = pandemic_baseline(:, {'sim_num', 'yr_start', 'ex_post_severity'});
    merged_b = outerjoin(base_merged, keys_b, 'Keys', {'sim_num', 'yr_start'}, 'Type', 'left', 'MergeKeys', true);
    missing_b = isnan(merged_b.ex_post_severity);
    merged_b.ex_post_severity(missing_b) = merged_b.eff_severity(missing_b);
    realized_matrix(idx) = merged_b.ex_post_severity;

    keys_v1 = pandemic_value1(:, {'sim_num', 'yr_start', 'ex_post_severity'});
    merged_v1 = outerjoin(base_merged, keys_v1, 'Keys', {'sim_num', 'yr_start'}, 'Type', 'left', 'MergeKeys', true);
    missing_v1 = isnan(merged_v1.ex_post_severity);
    merged_v1.ex_post_severity(missing_v1) = merged_v1.eff_severity(missing_v1);
    always_work_matrix(idx) = merged_v1.ex_post_severity;

    clear base_merged pandemic_baseline pandemic_value1 keys_b keys_v1 merged_b merged_v1 missing_b missing_v1;

    % Common grid for exceedance (log-spaced, include zero for histcounts)
    sev_all = [no_mitigation_matrix(:); realized_matrix(:); always_work_matrix(:)];
    sev_all = sev_all(isfinite(sev_all) & isreal(sev_all) & sev_all > 0);
    if isempty(sev_all)
        error('compare_exceedances:NoSeverity', 'No finite positive severity values found.');
    end
    min_grid = min(sev_all);
    max_grid = max(sev_all);
    num_pts  = 5000;
    direct_edges = [0; logspace(log10(min_grid), log10(max_grid), num_pts - 1)'];

    n_no  = numel(no_mitigation_matrix);
    n_rel = numel(realized_matrix);
    n_alw = numel(always_work_matrix);
    vec_no = no_mitigation_matrix(:);
    vec_rel = realized_matrix(:);
    vec_alw = always_work_matrix(:);

    exceed_no  = (n_no - histcounts(vec_no, direct_edges, 'Normalization', 'cumcount')) ./ (n_no + 1);
    exceed_rel = (n_rel - histcounts(vec_rel, direct_edges, 'Normalization', 'cumcount')) ./ (n_rel + 1);
    exceed_alw = (n_alw - histcounts(vec_alw, direct_edges, 'Normalization', 'cumcount')) ./ (n_alw + 1);

    x_plot = direct_edges(2:end)';

    % Madhav et al. reference
    madhav_path = fullfile('data', 'clean', 'madhav_et_al_severity_exceedance.csv');
    if ~isfile(madhav_path)
        madhav_path = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'clean', 'madhav_et_al_severity_exceedance.csv');
    end
    madhav_exceedances = readtable(madhav_path);
    [madhav_severity_central, central_idx] = sort(madhav_exceedances.severity_central);
    madhav_exceedance_central = madhav_exceedances.exceedance_central(central_idx);
    mad_valid = madhav_severity_central > 0;
    madhav_severity_plot = madhav_severity_central(mad_valid);
    madhav_exceedance_plot = madhav_exceedance_central(mad_valid) / 100;

    % Plot: sequential blue grade for our estimates (no mitigation → realized → vaccines work), darker red for Madhav.
    color_no   = [0.20 0.40 0.72];
    color_rel  = [0.35 0.52 0.78];
    color_alw  = [0.45 0.68 0.88];
    color_mad  = [0.62 0.08 0.08];

    fig = figure('Position', [100 100 900 650]);
    ax = axes('Parent', fig, 'Position', [0.14 0.14 0.82 0.82]);
    set(ax, 'FontName', 'Arial', 'FontSize', 11);
    hold(ax, 'on');

    plot(ax, x_plot, exceed_no,  'LineWidth', 2, 'Color', color_no);
    plot(ax, x_plot, exceed_rel, 'LineWidth', 2, 'Color', color_rel);
    plot(ax, x_plot, exceed_alw, 'LineWidth', 2, 'Color', color_alw);
    plot(ax, madhav_severity_plot, madhav_exceedance_plot, 'LineWidth', 2, 'Color', color_mad);

    set(ax, 'XScale', 'log', 'YScale', 'log');
    grid(ax, 'on');
    box(ax, 'off');
    xlabel(ax, 'Severity (deaths per 10,000)', 'FontName', 'Arial', 'FontSize', 12);
    ylabel(ax, 'Annual exceedance risk', 'FontName', 'Arial', 'FontSize', 12);

    min_x = max(min(x_plot), min(madhav_severity_plot));
    max_x = min(max(x_plot), max(madhav_severity_plot));
    xlim(ax, [min_x, max_x]);
    xt = get(ax, 'XTick');
    set(ax, 'XTickLabel', arrayfun(@(x) num2str(round(x), '%.0f'), xt, 'UniformOutput', false));

    % Labels near curves at fixed severity (x) positions.
    x_no  = max(min_x, min(max_x, 30));
    x_mad = max(min_x, min(max_x, 20));
    x_rel = max(min_x, min(max_x, 130));
    x_alw = max(min_x, min(max_x, 150));
    y_no  = interp1(x_plot, exceed_no, x_no, 'linear', 'extrap');
    y_mad = interp1(madhav_severity_plot, madhav_exceedance_plot, x_mad, 'linear', 'extrap');
    y_rel = interp1(x_plot, exceed_rel, x_rel, 'linear', 'extrap');
    y_alw = interp1(x_plot, exceed_alw, x_alw, 'linear', 'extrap');
    text(ax, x_no, y_no, ' No mitigation', 'Color', color_no, 'FontName', 'Arial', 'FontSize', 10, 'VerticalAlignment', 'bottom');
    text(ax, x_mad, y_mad, ' Madhav et al. (2023)', 'Color', color_mad, 'FontName', 'Arial', 'FontSize', 10, 'VerticalAlignment', 'bottom');
    text(ax, x_rel, y_rel, 'Realized mitigation (vaccines can fail) ', 'Color', color_rel, 'FontName', 'Arial', 'FontSize', 10, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
    text(ax, x_alw, y_alw, ' Vaccines always work', 'Color', color_alw, 'FontName', 'Arial', 'FontSize', 10, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');

    fig_dir = fullfile(sensitivity_dir, 'figures');
    if ~isfolder(fig_dir)
        mkdir(fig_dir);
    end
    [~, dirname] = fileparts(sensitivity_dir);
    print(fig, fullfile(fig_dir, sprintf('%s_exceedance_curves.png', dirname)), '-dpng', '-r600');
    fprintf('Exceedance figure saved to %s\n', fullfile(fig_dir, sprintf('%s_exceedance_curves.png', dirname)));
end
