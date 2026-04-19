function compare_exceedances(sensitivity_dir, figure_export, varargin)
% Compare exceedance curves from an airborne sensitivity run (no mitigation, realized mitigation, vaccines always work).
%
% Uses output from run_sensitivity(..., 'response') with e.g.
% config/sensitivity_runs_configs/baseline_vaccine_program_airborne.yaml:
%   sensitivity_dir/baseline/                    — baseline run (vaccines can fail)
%   sensitivity_dir/ptrs_pathogen_gamma1/        — vaccines-always-succeed PTRs and gamma=1 (multi-parameter)
%   or sensitivity_dir/ptrs_pathogen/value_1/   — same scenario, one-parameter layout
%
% Figures: (1) three simulation curves without Madhav et al.; (2) baseline vaccine response + Madhav et al. only.
%
% figure_export — 'both' (default), 'simulations_only', or 'baseline_madhav'.
%
% When plot_response_threshold is true (default when figure_export is 'simulations_only'), the
% simulations plot overlays the pandemic response severity threshold from the baseline run_config
% (if present and type is severity).
%
% Args:
%   sensitivity_dir        — path to sensitivity run root (e.g. output/sensitivity_runs/baseline_vaccine_program_airborne)
%   figure_export          — optional; which PDF(s) to write
%   plot_response_threshold — optional name-value; overlay response threshold marker (default: true when simulations_only)

    p = inputParser;
    addOptional(p, 'figure_export', 'both');
    addParameter(p, 'plot_response_threshold', strcmp(figure_export, 'simulations_only'));
    parse(p, figure_export, varargin{:});

    figure_export = p.Results.figure_export;
    plot_response_threshold = p.Results.plot_response_threshold;

    valid = {'both', 'simulations_only', 'baseline_madhav'};
    if ~any(strcmp(figure_export, valid))
        error('compare_exceedances:BadFigureExport', 'figure_export must be one of: %s', strjoin(valid, ', '));
    end

    baseline_dir = fullfile(sensitivity_dir, 'baseline');
    % Multi-parameter folder ptrs_pathogen_gamma1, or one-parameter ptrs_pathogen/value_1.
    value1_dir = fullfile(sensitivity_dir, 'ptrs_pathogen_gamma1');
    if ~isfolder(value1_dir)
        value1_dir = fullfile(sensitivity_dir, 'ptrs_pathogen', 'value_1');
    end

    if ~isfolder(baseline_dir)
        error('compare_exceedances:NoBaseline', 'Baseline directory not found: %s', baseline_dir);
    end
    if ~isfolder(value1_dir)
        error('compare_exceedances:NoVariant', ...
            'Expected ptrs_pathogen_gamma1 or ptrs_pathogen/value_1 under %s', sensitivity_dir);
    end

    % Chunk layout and table sizes from baseline job config
    run_config = yaml.loadFile(fullfile(baseline_dir, 'run_config.yaml'));
    sim_periods = run_config.sim_periods;
    num_simulations = run_config.num_simulations;
    config_min_grid = load_arrival_y_min(run_config);

    raw_baseline = fullfile(baseline_dir, 'raw');
    raw_value1   = fullfile(value1_dir, 'raw');

    base_vars = {'sim_num', 'yr_start', 'eff_severity', 'is_false'};
    pandemic_vars = {'sim_num', 'yr_start', 'ex_post_severity', 'is_false'};

    [chunk_dirs_b, ~] = list_chunk_dirs(raw_baseline);
    num_chunks = length(chunk_dirs_b);

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

        % Base table (shared across sensitivity variants)
        base_path = fullfile(chunk_b, 'base_simulation_table.mat');
        S = load(base_path, 'base_simulation_table');
        base_t = S.base_simulation_table(:, base_vars);
        base_t = base_t(~base_t.is_false & ~isnan(base_t.yr_start), :);
        base_t.is_false = [];
        n_base = n_base + 1;
        all_base{n_base} = base_t;

        pan_b_path = fullfile(chunk_b, 'baseline_pandemic_table.mat');
        if isfile(pan_b_path)
            S = load(pan_b_path, 'pandemic_table');
            pan_t = S.pandemic_table(:, pandemic_vars);
            pan_t = pan_t(~pan_t.is_false & ~isnan(pan_t.yr_start), :);
            pan_t.is_false = [];
            n_pan_b = n_pan_b + 1;
            all_pandemic_baseline{n_pan_b} = pan_t;
        end

        % Variant: PTRs imply vaccines always work (same chunk index as baseline)
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
    clear all_base all_pandemic_baseline all_pandemic_value1 S base_t pan_t

    % Severity per (sim_num, yr_start); empty cells stay 0
    no_mitigation_matrix = zeros(num_simulations, sim_periods);
    realized_matrix      = zeros(num_simulations, sim_periods);
    always_work_matrix   = zeros(num_simulations, sim_periods);

    idx = sub2ind([num_simulations, sim_periods], base_merged.sim_num, base_merged.yr_start);
    no_mitigation_matrix(idx) = base_merged.eff_severity;

    % Realized mitigation: ex_post from pandemic table; missing rows use eff_severity
    keys_b = pandemic_baseline(:, {'sim_num', 'yr_start', 'ex_post_severity'});
    merged_b = outerjoin(base_merged, keys_b, 'Keys', {'sim_num', 'yr_start'}, 'Type', 'left', 'MergeKeys', true);
    missing_b = isnan(merged_b.ex_post_severity);
    merged_b.ex_post_severity(missing_b) = merged_b.eff_severity(missing_b);
    realized_matrix(idx) = merged_b.ex_post_severity;

    % Vaccines-always-work variant
    keys_v1 = pandemic_value1(:, {'sim_num', 'yr_start', 'ex_post_severity'});
    merged_v1 = outerjoin(base_merged, keys_v1, 'Keys', {'sim_num', 'yr_start'}, 'Type', 'left', 'MergeKeys', true);
    missing_v1 = isnan(merged_v1.ex_post_severity);
    merged_v1.ex_post_severity(missing_v1) = merged_v1.eff_severity(missing_v1);
    always_work_matrix(idx) = merged_v1.ex_post_severity;

    clear base_merged pandemic_baseline pandemic_value1 keys_b keys_v1 merged_b merged_v1 missing_b missing_v1

    % Log-spaced severity grid; P(S>x) from direct counts over the full vector (avoids histogram-bin artifacts)
    sev_all = [no_mitigation_matrix(:); realized_matrix(:); always_work_matrix(:)];
    sev_all = sev_all(isfinite(sev_all) & sev_all > 0);
    if isempty(sev_all)
        error('compare_exceedances:NoSeverity', 'No finite positive severity values found.');
    end
    min_grid = config_min_grid;
    max_grid = max(sev_all);
    num_pts  = 5000;
    x_plot = logspace(log10(min_grid), log10(max_grid), num_pts)';

    vec_no = no_mitigation_matrix(:);
    vec_rel = realized_matrix(:);
    vec_alw = always_work_matrix(:);

    exceed_no  = empirical_exceedance(vec_no, x_plot);
    exceed_rel = empirical_exceedance(vec_rel, x_plot);
    exceed_alw = empirical_exceedance(vec_alw, x_plot);

    recur_no  = 1 ./ exceed_no(:);
    recur_rel = 1 ./ exceed_rel(:);
    recur_alw = 1 ./ exceed_alw(:);

    % Mean annual recurrence = 1 / exceedance probability
    T = table(x_plot, recur_no, recur_rel, recur_alw, ...
        'VariableNames', {'severity', 'mean_no_mitigation_recurrence', ...
                          'mean_realized_recurrence', 'mean_always_work_recurrence'});

    writetable(T, fullfile(sensitivity_dir, 'mean_annual_recurrence_rates.csv'));

    % Debug export: severity grid and exceedance curves for all three series.
    debug_tbl = table( ...
        round(x_plot(:), 4), ...
        round(exceed_no(:), 4), ...
        round(exceed_rel(:), 4), ...
        round(exceed_alw(:), 4), ...
        'VariableNames', {'x_plot', 'exceed_no', 'exceed_rel', 'exceed_alw'});
    writetable(debug_tbl, fullfile(sensitivity_dir, 'exceedance_debug_all_curves.csv'));

    % Interpolated recurrence at reference severities.
    target_severities = [min_grid; 0.01; 6.15; 12.3; 50; 100; 150; 171];
    interp_no  = interp1(T.severity, T.mean_no_mitigation_recurrence, target_severities, 'linear', NaN);
    interp_rel = interp1(T.severity, T.mean_realized_recurrence,       target_severities, 'linear', NaN);
    interp_alw = interp1(T.severity, T.mean_always_work_recurrence,    target_severities, 'linear', NaN);

    small_T = table(target_severities(:), interp_no(:), interp_rel(:), interp_alw(:), ...
        'VariableNames', {'severity', 'mean_no_mitigation_recurrence', ...
                          'mean_realized_recurrence', 'mean_always_work_recurrence'});
    writetable(small_T, fullfile(sensitivity_dir, 'mean_annual_recurrence_rates_selected.csv'));

    % Navy — no mitigation; sky blue — status quo; teal — vaccines always work; red — Madhav reference
    color_no  = [0.12 0.20 0.48];
    color_rel = [0.35 0.55 0.88];
    color_alw = [0.18 0.72 0.48];
    color_mad = [0.72 0.12 0.12];

    fig_dir = fullfile(sensitivity_dir, 'figures');
    if ~isfolder(fig_dir)
        mkdir(fig_dir);
    end
    [~, dirname] = fileparts(sensitivity_dir);

    thr_x = [];
    thr_y = [];
    if plot_response_threshold
        thr_val = [];
        thr_type = '';
        if isfield(run_config, 'response_threshold') && ~isempty(run_config.response_threshold)
            thr_val = double(run_config.response_threshold);
            if isfield(run_config, 'response_threshold_type')
                thr_type = char(string(run_config.response_threshold_type));
            end
        elseif isfield(run_config, 'response_threshold_path') && strlength(string(run_config.response_threshold_path)) > 0
            pth = char(string(run_config.response_threshold_path));
            if isfile(pth)
                d = yaml.loadFile(pth);
                thr_val = double(d.response_threshold);
                thr_type = char(string(d.response_threshold_type));
            end
        end
        if ~isempty(thr_val) && strcmp(thr_type, 'severity')
            thr_x = thr_val;
            thr_y = interp1(x_plot, exceed_no, thr_x, 'linear', 'extrap');
        end
    end

    if strcmp(figure_export, 'both') || strcmp(figure_export, 'simulations_only')
        fig1 = compare_exceedances_plot_simulations_only(x_plot, exceed_no, exceed_rel, exceed_alw, ...
            color_no, color_rel, color_alw, thr_x, thr_y);
        out1 = fullfile(fig_dir, sprintf('%s_exceedance_curves_simulations_only.pdf', dirname));
        export_figure(fig1, out1);
        close(fig1);
        fprintf('Exceedance figure (simulations only) saved to %s\n', out1);
    end

    if strcmp(figure_export, 'both') || strcmp(figure_export, 'baseline_madhav')
        % Madhav et al. reference; file exceedance is in percent
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
        export_figure(fig2, out2);
        close(fig2);
        fprintf('Exceedance figure (baseline response and Madhav et al.) saved to %s\n', out2);
    end
end

function y_min = load_arrival_y_min(run_config)
    % Load y_min from the arrival distribution hyperparams in job config.
    arrival_dir = char(string(run_config.arrival_dist_config));
    hyper = yaml.loadFile(fullfile(arrival_dir, 'hyperparams.yaml'));
    y_min = double(hyper.y_min);
end

function p = empirical_exceedance(sample, severity_grid)
    % Empirical exceedance P(S > x) evaluated on a severity grid.
    sample = sample(:);
    severity_grid = severity_grid(:);
    n = numel(sample);
    edges = [-inf; severity_grid; inf];
    N = histcounts(sample, edges);
    tail = flip(cumsum(flip(N(:))));
    % For threshold severity_grid(i), this gives counts strictly greater than x_i.
    p = tail(2:end) ./ (n + 1);
end

function fig = compare_exceedances_plot_simulations_only(x_plot, exceed_no, exceed_rel, exceed_alw, color_no, color_rel, color_alw, thr_x, thr_y)
% Three simulation curves only (no Madhav et al.). Pass thr_x = [] to omit response threshold.
    color_thr = [0.72 0.12 0.12];
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
    set_log_axis_tick_labels(ax);  % avoid rounding 0.01 and 0.1 both to "0"

    if ~isempty(thr_x) && isfinite(thr_y)
        yl = get(ax, 'YLim');
        plot(ax, thr_x, thr_y, 's', 'Color', color_thr, 'MarkerFaceColor', color_thr, 'MarkerSize', 6);
        plot(ax, [thr_x thr_x], [yl(1) thr_y], '--', 'Color', color_thr, 'LineWidth', 1);
        plot(ax, [min_x thr_x], [thr_y thr_y], '--', 'Color', color_thr, 'LineWidth', 1);
        text(ax, thr_x * 0.95, thr_y * 0.95, sprintf('Pandemic response\nthreshold: %.2f', thr_x), ...
            'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', 'FontSize', 10, ...
            'FontName', 'Arial', 'Color', color_thr);
    end

    % Line labels at fixed severities
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

function fig = compare_exceedances_plot_baseline_madhav(x_plot, exceed_rel, madhav_severity_plot, madhav_exceedance_plot, color_rel, color_mad)
% Baseline realized mitigation vs Madhav et al. reference only.
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
    set_log_axis_tick_labels(ax);

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

function set_log_axis_tick_labels(ax)
% Log-scale x ticks: %.0f rounds 0.01 and 0.1 to 0; use %.3g instead.
    xt = get(ax, 'XTick');
    labs = arrayfun(@(v) sprintf('%.3g', v), xt, 'UniformOutput', false);
    set(ax, 'XTickLabel', labs);
end
