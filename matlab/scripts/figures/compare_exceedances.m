function compare_exceedances(sensitivity_dir, figure_export)
% Compare exceedance curves from airborne sensitivity run (no mitigation, realized mitigation, vaccines always work).
%
% Uses output from run_sensitivity(..., 'response') with
% config/sensitivity_configs/baseline_vaccine_program_airborne.yaml:
%   - sensitivity_dir/baseline/  : baseline run (vaccines can fail)
%   - sensitivity_dir/ptrs_pathogen_gamma1/ : run with vaccines-always-succeed PTRs and gamma=1 (multi-parameter config)
%   - or sensitivity_dir/ptrs_pathogen/value_1/ : same run from one-parameter config
%
% Figure export options (second argument):
%   'both' (default): write two PDFs — (1) three simulation curves only (no Madhav et al.),
%     (2) baseline vaccine response (realized mitigation) and Madhav et al. only.
%   'simulations_only': PDF (1) only.
%   'baseline_madhav': PDF (2) only.
%
% Args:
%   sensitivity_dir (char): Path to sensitivity run root (e.g. output/sensitivity/baseline_vaccine_program_airborne)
%   figure_export (char, optional): 'both' | 'simulations_only' | 'baseline_madhav'. Default 'both'.

    if nargin < 2 || isempty(figure_export)
        figure_export = 'both';
    end
    valid_export = {'both', 'simulations_only', 'baseline_madhav'};
    if ~any(strcmp(figure_export, valid_export))
        error('compare_exceedances:BadFigureExport', ...
            'figure_export must be one of: %s', strjoin(valid_export, ', '));
    end
    baseline_dir = fullfile(sensitivity_dir, 'baseline');
    % Support both multi-parameter (ptrs_pathogen_gamma1) and one-parameter (ptrs_pathogen/value_1) layouts.
    value1_dir = fullfile(sensitivity_dir, 'ptrs_pathogen_gamma1');
    if ~isfolder(value1_dir)
        value1_dir = fullfile(sensitivity_dir, 'ptrs_pathogen', 'value_1');
    end

    if ~isfolder(baseline_dir)
        error('compare_exceedances:NoBaseline', 'Baseline directory not found: %s', baseline_dir);
    end
    if ~isfolder(value1_dir)
        error('compare_exceedances:NoVariant', ...
            'Vaccines-always-work scenario not found. Looked for ptrs_pathogen_gamma1 and ptrs_pathogen/value_1 under: %s', sensitivity_dir);
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

    % Use column vectors so table variables have matching row counts
    x_plot   = direct_edges(2:end);
    recur_no = 1 ./ exceed_no(:);
    recur_rel = 1 ./ exceed_rel(:);
    recur_alw = 1 ./ exceed_alw(:);

    T = table(x_plot, recur_no, recur_rel, recur_alw, ...
        'VariableNames', {'severity', 'mean_no_mitigation_recurrence', ...
                          'mean_realized_recurrence', 'mean_always_work_recurrence'});

    writetable(T, fullfile(sensitivity_dir, 'mean_annual_recurrence_rates.csv'));

    % Smaller table with interpolated values at specific severities
    target_severities = [min(x_plot); 22.3; 44.6; 50; 100; 150; 171];

    severity = T.severity;
    mean_no_mitigation_recurrence = T.mean_no_mitigation_recurrence;
    mean_realized_recurrence = T.mean_realized_recurrence;
    mean_always_work_recurrence = T.mean_always_work_recurrence;

    interp_no  = interp1(severity, mean_no_mitigation_recurrence, target_severities, 'linear', 'extrap');
    interp_rel = interp1(severity, mean_realized_recurrence,       target_severities, 'linear', 'extrap');
    interp_alw = interp1(severity, mean_always_work_recurrence,    target_severities, 'linear', 'extrap');

    small_T = table(target_severities(:), interp_no(:), interp_rel(:), interp_alw(:), ...
        'VariableNames', {'severity', 'mean_no_mitigation_recurrence', ...
                          'mean_realized_recurrence', 'mean_always_work_recurrence'});

    writetable(small_T, fullfile(sensitivity_dir, 'mean_annual_recurrence_rates_selected.csv'));

    % Coherent palette: distinct colors for scenario progression (no mitigation → realized → vaccines work), red for Madhav et al.
    color_no   = [0.12 0.20 0.48];   % dark navy – no mitigation
    color_rel  = [0.35 0.55 0.88];   % sky blue – vaccines can fail (clearly lighter and distinct from navy)
    color_alw  = [0.18 0.72 0.48];   % green–teal – vaccines always work
    color_mad  = [0.72 0.12 0.12];   % red – Madhav et al. (reference)

    fig_dir = fullfile(sensitivity_dir, 'figures');
    if ~isfolder(fig_dir)
        mkdir(fig_dir);
    end
    [~, dirname] = fileparts(sensitivity_dir);

    if strcmp(figure_export, 'both') || strcmp(figure_export, 'simulations_only')
        fig1 = compare_exceedances_plot_simulations_only(x_plot, exceed_no, exceed_rel, exceed_alw, ...
            color_no, color_rel, color_alw);
        out1 = fullfile(fig_dir, sprintf('%s_exceedance_curves_simulations_only.pdf', dirname));
        exportgraphics(fig1, out1, "ContentType", "vector", "Resolution", 600, "BackgroundColor", "none");
        close(fig1);
        fprintf('Exceedance figure (simulations only) saved to %s\n', out1);
    end

    if strcmp(figure_export, 'both') || strcmp(figure_export, 'baseline_madhav')
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

        fig2 = compare_exceedances_plot_baseline_madhav(x_plot, exceed_rel, madhav_severity_plot, madhav_exceedance_plot, ...
            color_rel, color_mad);
        out2 = fullfile(fig_dir, sprintf('%s_exceedance_curves_baseline_response_madhav.pdf', dirname));
        exportgraphics(fig2, out2, "ContentType", "vector", "Resolution", 600, "BackgroundColor", "none");
        close(fig2);
        fprintf('Exceedance figure (baseline response and Madhav et al.) saved to %s\n', out2);
    end
end

function fig = compare_exceedances_plot_simulations_only(x_plot, exceed_no, exceed_rel, exceed_alw, ...
        color_no, color_rel, color_alw)
% Build figure with three simulation exceedance curves (no Madhav et al.).
%
% Args:
%   x_plot (double): Severity grid (column vector).
%   exceed_no, exceed_rel, exceed_alw (double): Annual exceedance risk per scenario, same length as x_plot.
%   color_no, color_rel, color_alw (double): RGB row vectors for the three lines.
%
% Returns:
%   fig: Figure handle.

    fig = figure('Position', [100 100 900 650]);
    ax = axes('Parent', fig, 'Position', [0.14 0.14 0.82 0.82]);
    set(ax, 'FontName', 'Arial', 'FontSize', 11);
    hold(ax, 'on');

    plot(ax, x_plot, exceed_no,  'LineWidth', 2, 'Color', color_no);
    plot(ax, x_plot, exceed_rel, 'LineWidth', 2, 'Color', color_rel);
    plot(ax, x_plot, exceed_alw, 'LineWidth', 2, 'Color', color_alw);

    set(ax, 'XScale', 'log', 'YScale', 'log');
    grid(ax, 'on');
    box(ax, 'off');
    xlabel(ax, 'Severity (deaths per 10,000)', 'FontName', 'Arial', 'FontSize', 14);
    ylabel(ax, 'Annual exceedance risk', 'FontName', 'Arial', 'FontSize', 14);

    min_x = min(x_plot);
    max_x = max(x_plot);
    xlim(ax, [min_x, max_x]);
    xt = get(ax, 'XTick');
    set(ax, 'XTickLabel', arrayfun(@(x) num2str(round(x), '%.0f'), xt, 'UniformOutput', false));

    x_no  = max(min_x, min(max_x, 20));
    x_rel = max(min_x, min(max_x, 110));
    x_alw = max(min_x, min(max_x, 120));
    y_no  = interp1(x_plot, exceed_no, x_no, 'linear', 'extrap');
    y_rel = interp1(x_plot, exceed_rel, x_rel, 'linear', 'extrap');
    y_alw = interp1(x_plot, exceed_alw, x_alw, 'linear', 'extrap');

    text(ax, x_no, y_no, ' No mitigation', ...
        'Color', color_no, 'FontName', 'Arial', 'FontSize', 12, ...
        'VerticalAlignment', 'bottom');

    text(ax, x_rel, y_rel, {'Status quo', 'response'}, ...
        'Color', color_rel, 'FontName', 'Arial', 'FontSize', 12, ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');

    text(ax, x_alw, y_alw, {'Vaccines', 'always work'}, ...
        'Color', color_alw, 'FontName', 'Arial', 'FontSize', 12, ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
end

function fig = compare_exceedances_plot_baseline_madhav(x_plot, exceed_rel, madhav_severity_plot, madhav_exceedance_plot, ...
        color_rel, color_mad)
% Build figure with baseline vaccine response (realized mitigation) and Madhav et al. only.
%
% Args:
%   x_plot (double): Simulation severity grid for the baseline response curve.
%   exceed_rel (double): Annual exceedance risk for baseline response, same length as x_plot.
%   madhav_severity_plot, madhav_exceedance_plot (double): Madhav et al. reference series.
%   color_rel, color_mad (double): RGB row vectors for baseline response and reference lines.
%
% Returns:
%   fig: Figure handle.

    fig = figure('Position', [100 100 900 650]);
    ax = axes('Parent', fig, 'Position', [0.14 0.14 0.82 0.82]);
    set(ax, 'FontName', 'Arial', 'FontSize', 11);
    hold(ax, 'on');

    plot(ax, x_plot, exceed_rel, 'LineWidth', 2, 'Color', color_rel);
    plot(ax, madhav_severity_plot, madhav_exceedance_plot, 'LineWidth', 2, 'Color', color_mad);

    set(ax, 'XScale', 'log', 'YScale', 'log');
    grid(ax, 'on');
    box(ax, 'off');
    xlabel(ax, 'Severity (deaths per 10,000)', 'FontName', 'Arial', 'FontSize', 14);
    ylabel(ax, 'Annual exceedance risk', 'FontName', 'Arial', 'FontSize', 14);

    min_x = max(min(x_plot), min(madhav_severity_plot));
    max_x = min(max(x_plot), max(madhav_severity_plot));
    xlim(ax, [min_x, max_x]);
    xt = get(ax, 'XTick');
    set(ax, 'XTickLabel', arrayfun(@(x) num2str(round(x), '%.0f'), xt, 'UniformOutput', false));

    x_rel = max(min_x, min(max_x, 110));
    x_mad = max(min_x, min(max_x, 10));
    y_rel = interp1(x_plot, exceed_rel, x_rel, 'linear', 'extrap');
    y_mad = interp1(madhav_severity_plot, madhav_exceedance_plot, x_mad, 'linear', 'extrap');

    text(ax, x_rel, y_rel, {'Status quo', 'response'}, ...
        'Color', color_rel, 'FontName', 'Arial', 'FontSize', 12, ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');

    text(ax, x_mad, y_mad, ' Madhav et al. (2023)', ...
        'Color', color_mad, 'FontName', 'Arial', 'FontSize', 12, ...
        'VerticalAlignment', 'bottom');
end
