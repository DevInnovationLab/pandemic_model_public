function plot_baseline_program_exceedances(varargin)
% Plot Figure 5 exceedance comparison for the baseline vaccine program.
%
% This function writes the simulations-only exceedance comparison used in
% Figure 5 for the baseline vaccine program setting. It compares:
%   - No mitigation
%   - Status quo response
%   - Vaccines always work
%
% Args:
%   sensitivity_dir: Path to output/sensitivity_runs/baseline_vaccine_program.
%
% Name-value args:
%   plot_response_threshold: Logical; overlay pandemic response threshold marker.

    p = inputParser;
    addParameter(p, "plot_response_threshold", true, @islogical);
    parse(p, varargin{:});
    plot_response_threshold = p.Results.plot_response_threshold;

    sensitivity_dir = fullfile("output", "sensitivity_runs", "baseline_vaccine_program");
    baseline_dir = fullfile(sensitivity_dir, "baseline");
    value1_dir = fullfile(sensitivity_dir, "ptrs_pathogen_gamma1");

    run_config = yaml.loadFile(fullfile(baseline_dir, "run_config.yaml"));
    sim_periods = run_config.sim_periods;
    num_simulations = run_config.num_simulations;
    config_min_grid = load_arrival_y_min(run_config);

    raw_baseline = fullfile(baseline_dir, "raw");
    raw_value1 = fullfile(value1_dir, "raw");

    base_vars = {'sim_num', 'yr_start', 'eff_severity', 'is_false'};
    pandemic_vars = {'sim_num', 'yr_start', 'ex_post_severity', 'is_false'};

    [chunk_dirs_b, ~] = list_chunk_dirs(raw_baseline);
    num_chunks = length(chunk_dirs_b);

    all_base = cell(num_chunks, 1);
    all_pandemic_baseline = cell(num_chunks, 1);
    all_pandemic_value1 = cell(num_chunks, 1);
    n_base = 0;
    n_pan_b = 0;
    n_pan_v1 = 0;

    for i = 1:num_chunks
        ch_name = chunk_dirs_b(i).name;
        chunk_b = fullfile(raw_baseline, ch_name);
        chunk_v1 = fullfile(raw_value1, ch_name);

        base_path = fullfile(chunk_b, "base_simulation_table.mat");
        S = load(base_path, "base_simulation_table");
        base_t = S.base_simulation_table(:, base_vars);
        base_t = base_t(~base_t.is_false & ~isnan(base_t.yr_start), :);
        base_t.is_false = [];
        n_base = n_base + 1;
        all_base{n_base} = base_t;

        pan_b_path = fullfile(chunk_b, "baseline_pandemic_table.mat");
        S = load(pan_b_path, "pandemic_table");
        pan_t = S.pandemic_table(:, pandemic_vars);
        pan_t = pan_t(~pan_t.is_false & ~isnan(pan_t.yr_start), :);
        pan_t.is_false = [];
        n_pan_b = n_pan_b + 1;
        all_pandemic_baseline{n_pan_b} = pan_t;

        pan_v1_path = fullfile(chunk_v1, "baseline_pandemic_table.mat");
        S = load(pan_v1_path, "pandemic_table");
        pan_t = S.pandemic_table(:, pandemic_vars);
        pan_t = pan_t(~pan_t.is_false & ~isnan(pan_t.yr_start), :);
        pan_t.is_false = [];
        n_pan_v1 = n_pan_v1 + 1;
        all_pandemic_value1{n_pan_v1} = pan_t;
    end

    base_merged = vertcat(all_base{1:n_base});
    pandemic_baseline = vertcat(all_pandemic_baseline{1:n_pan_b});
    pandemic_value1 = vertcat(all_pandemic_value1{1:n_pan_v1});
    clear all_base all_pandemic_baseline all_pandemic_value1 S base_t pan_t

    no_mitigation_matrix = zeros(num_simulations, sim_periods);
    realized_matrix = zeros(num_simulations, sim_periods);
    always_work_matrix = zeros(num_simulations, sim_periods);

    idx = sub2ind([num_simulations, sim_periods], base_merged.sim_num, base_merged.yr_start);
    no_mitigation_matrix(idx) = base_merged.eff_severity;

    keys_b = pandemic_baseline(:, {'sim_num', 'yr_start', 'ex_post_severity'});
    merged_b = outerjoin(base_merged, keys_b, "Keys", {'sim_num', 'yr_start'}, "Type", "left", "MergeKeys", true);
    missing_b = isnan(merged_b.ex_post_severity);
    merged_b.ex_post_severity(missing_b) = merged_b.eff_severity(missing_b);
    realized_matrix(idx) = merged_b.ex_post_severity;

    keys_v1 = pandemic_value1(:, {'sim_num', 'yr_start', 'ex_post_severity'});
    merged_v1 = outerjoin(base_merged, keys_v1, "Keys", {'sim_num', 'yr_start'}, "Type", "left", "MergeKeys", true);
    missing_v1 = isnan(merged_v1.ex_post_severity);
    merged_v1.ex_post_severity(missing_v1) = merged_v1.eff_severity(missing_v1);
    always_work_matrix(idx) = merged_v1.ex_post_severity;
    clear base_merged pandemic_baseline pandemic_value1 keys_b keys_v1 merged_b merged_v1 missing_b missing_v1

    sev_all = [no_mitigation_matrix(:); realized_matrix(:); always_work_matrix(:)];
    sev_all = sev_all(isfinite(sev_all) & sev_all > 0);

    min_grid = config_min_grid;
    max_grid = max(sev_all);
    x_plot = logspace(log10(min_grid), log10(max_grid), 5000)';

    exceed_no = empirical_exceedance(no_mitigation_matrix(:), x_plot);
    exceed_rel = empirical_exceedance(realized_matrix(:), x_plot);
    exceed_alw = empirical_exceedance(always_work_matrix(:), x_plot);

    recur_no = 1 ./ exceed_no(:);
    recur_rel = 1 ./ exceed_rel(:);
    recur_alw = 1 ./ exceed_alw(:);
    T = table(x_plot, recur_no, recur_rel, recur_alw, ...
        'VariableNames', {'severity', 'mean_no_mitigation_recurrence', ...
                          'mean_realized_recurrence', 'mean_always_work_recurrence'});
    writetable(T, fullfile(sensitivity_dir, "mean_annual_recurrence_rates.csv"));

    target_severities = [min_grid; 0.01; 6.15; 12.3; 50; 100; 150; 171];
    small_T = table( ...
        target_severities(:), ...
        interp1(T.severity, T.mean_no_mitigation_recurrence, target_severities, "linear", NaN), ...
        interp1(T.severity, T.mean_realized_recurrence, target_severities, "linear", NaN), ...
        interp1(T.severity, T.mean_always_work_recurrence, target_severities, "linear", NaN), ...
        'VariableNames', {'severity', 'mean_no_mitigation_recurrence', ...
                          'mean_realized_recurrence', 'mean_always_work_recurrence'});
    writetable(small_T, fullfile(sensitivity_dir, "mean_annual_recurrence_rates_selected.csv"));

    color_no = [0.12 0.20 0.48];
    color_rel = [0.35 0.55 0.88];
    color_alw = [0.18 0.72 0.48];

    thr_x = [];
    thr_y = [];
    if plot_response_threshold
        [thr_x, thr_y] = load_response_threshold_marker(run_config, x_plot, exceed_no);
    end

    fig = plot_simulations_only_curve(x_plot, exceed_no, exceed_rel, exceed_alw, ...
        color_no, color_rel, color_alw, thr_x, thr_y);

    fig_dir = fullfile(sensitivity_dir, "figures");
    if ~isfolder(fig_dir)
        mkdir(fig_dir);
    end
    [~, dirname] = fileparts(sensitivity_dir);
    out = fullfile(fig_dir, "baseline_program_exceedance_curves.pdf");
    export_figure(fig, out);
    close(fig);
    fprintf("Figure 5 exceedance plot saved to %s\n", out);
end

function [thr_x, thr_y] = load_response_threshold_marker(run_config, x_plot, exceed_no)
% Load pandemic response threshold marker from run config.
    thr_x = [];
    thr_y = [];

    thr_val = [];
    thr_type = "";
    if isfield(run_config, "response_threshold") && ~isempty(run_config.response_threshold)
        thr_val = double(run_config.response_threshold);
        if isfield(run_config, "response_threshold_type")
            thr_type = string(run_config.response_threshold_type);
        end
    elseif isfield(run_config, "response_threshold_path") && strlength(string(run_config.response_threshold_path)) > 0
        pth = char(string(run_config.response_threshold_path));
        if isfile(pth)
            d = yaml.loadFile(pth);
            thr_val = double(d.response_threshold);
            thr_type = string(d.response_threshold_type);
        end
    end

    if ~isempty(thr_val) && strcmp(thr_type, "severity")
        thr_x = thr_val;
        thr_y = interp1(x_plot, exceed_no, thr_x, "linear", "extrap");
    end
end

function y_min = load_arrival_y_min(run_config)
% Load y_min from arrival distribution hyperparameters.
    arrival_dir = char(string(run_config.arrival_dist_config));
    hyper = yaml.loadFile(fullfile(arrival_dir, "hyperparams.yaml"));
    y_min = double(hyper.y_min);
end

function p = empirical_exceedance(sample, severity_grid)
% Return empirical exceedance P(S > x) on the supplied severity grid.
    sample = sample(:);
    severity_grid = severity_grid(:);
    n = numel(sample);
    edges = [-inf; severity_grid; inf];
    N = histcounts(sample, edges);
    tail = flip(cumsum(flip(N(:))));
    p = tail(2:end) ./ (n + 1);
end

function fig = plot_simulations_only_curve(x_plot, exceed_no, exceed_rel, exceed_alw, color_no, color_rel, color_alw, thr_x, thr_y)
% Plot the simulations-only exceedance comparison for Figure 5.
    color_thr = [0.72 0.12 0.12];
    spec = get_paper_figure_spec("double_col_standard");
    fig = figure("Units", "inches", "Position", [1 1 spec.width_in spec.height_in]);
    ax = axes("Parent", fig, "Position", [0.14 0.14 0.82 0.82]);
    hold(ax, "on");

    plot(ax, x_plot, exceed_no, "LineWidth", spec.stroke.primary, "Color", color_no);
    plot(ax, x_plot, exceed_rel, "LineWidth", spec.stroke.primary, "Color", color_rel);
    plot(ax, x_plot, exceed_alw, "LineWidth", spec.stroke.primary, "Color", color_alw);

    set(ax, "XScale", "log", "YScale", "log");
    apply_paper_axis_style(ax, spec);
    ax.XMinorGrid = "off";
    ax.YMinorGrid = "off";
    xlabel(ax, "Severity (deaths per 10,000)", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    ylabel(ax, "Annual exceedance risk", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);

    min_x = min(x_plot);
    max_x = max(x_plot);
    xlim(ax, [min_x, max_x]);
    set_log_axis_tick_labels(ax);

    if ~isempty(thr_x) && isfinite(thr_y)
        yl = get(ax, "YLim");
        plot(ax, thr_x, thr_y, "s", "Color", color_thr, "MarkerFaceColor", color_thr, "MarkerSize", 6);
        plot(ax, [thr_x thr_x], [yl(1) thr_y], "--", "Color", color_thr, "LineWidth", spec.stroke.reference);
        plot(ax, [min_x thr_x], [thr_y thr_y], "--", "Color", color_thr, "LineWidth", spec.stroke.reference);
        text(ax, thr_x * 0.95, thr_y * 0.95, sprintf("Pandemic response\nthreshold: %.2f", thr_x), ...
            "VerticalAlignment", "top", "HorizontalAlignment", "right", ...
            "FontSize", spec.typography.legend, "FontName", spec.font_name, "Color", color_thr);
    end

    x_no = max(min_x, min(max_x, 20));
    x_rel = max(min_x, min(max_x, 110));
    x_alw = max(min_x, min(max_x, 120));
    y_no = interp1(x_plot, exceed_no, x_no, "linear", "extrap");
    y_rel = interp1(x_plot, exceed_rel, x_rel, "linear", "extrap");
    y_alw = interp1(x_plot, exceed_alw, x_alw, "linear", "extrap");

    text(ax, x_no, y_no, " No mitigation", ...
        "Color", color_no, "FontName", spec.font_name, "FontSize", spec.typography.legend, "VerticalAlignment", "bottom");
    text(ax, x_rel, y_rel, {"Status quo", "response"}, ...
        "Color", color_rel, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "top", "HorizontalAlignment", "right");
    text(ax, x_alw, y_alw, {"Vaccines", "always work"}, ...
        "Color", color_alw, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "top", "HorizontalAlignment", "right");
end

function set_log_axis_tick_labels(ax)
% Set readable tick labels on log-scaled x-axis.
    xt = get(ax, "XTick");
    labs = arrayfun(@(v) sprintf("%.3g", v), xt, "UniformOutput", false);
    set(ax, "XTickLabel", labs);
end
