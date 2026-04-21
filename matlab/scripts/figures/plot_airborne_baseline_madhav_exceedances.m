function plot_airborne_baseline_madhav_exceedances()
% Plot Figure S5 with airborne, preferred-status-quo, and Madhav curves.
%
% Figure walk sequence:
%   1) Preferred dataset status quo response (Figure 5 reference).
%   2) Airborne status quo response (baseline_madhav context).
%   3) Madhav et al. reference.
%
% Both model status quo curves use the same medium blue family, while
% Madhav et al. is red, per project guidance.
%
% Args:
%   airborne_sensitivity_dir: Path to baseline_vaccine_program_airborne run output.
%   baseline_program_sensitivity_dir: Path to baseline_vaccine_program run output.

    airborne_sensitivity_dir = fullfile("output", "sensitivity_runs", "baseline_vaccine_program_airborne");
    baseline_program_sensitivity_dir = fullfile("output", "sensitivity_runs", "baseline_vaccine_program");
    [x_air, exceed_air] = load_status_quo_exceedance_curve(airborne_sensitivity_dir);
    [x_pref, exceed_pref] = load_status_quo_exceedance_curve(baseline_program_sensitivity_dir);

    madhav_path = fullfile("data", "clean", "madhav_et_al_severity_exceedance.csv");
    if ~isfile(madhav_path)
        madhav_path = fullfile(fileparts(mfilename("fullpath")), "..", "..", "data", "clean", "madhav_et_al_severity_exceedance.csv");
    end
    madhav_exceedances = readtable(madhav_path);
    [madhav_severity, idx] = sort(madhav_exceedances.severity_central);
    madhav_exceedance = madhav_exceedances.exceedance_central(idx) / 100;
    valid = madhav_severity > 0 & isfinite(madhav_exceedance);
    madhav_severity = madhav_severity(valid);
    madhav_exceedance = madhav_exceedance(valid);

    fig = plot_s5_curve_set(x_pref, exceed_pref, x_air, exceed_air, madhav_severity, madhav_exceedance);

    fig_dir = fullfile(airborne_sensitivity_dir, "figures");
    if ~isfolder(fig_dir)
        mkdir(fig_dir);
    end
    out = fullfile(fig_dir, "exceedance_curves_madhav_comparison.pdf");
    export_figure(fig, out);
    close(fig);
    fprintf("Figure S5 exceedance plot saved to %s\n", out);
end

function [x_plot, exceed_rel] = load_status_quo_exceedance_curve(sensitivity_dir)
% Build status quo response exceedance curve from a sensitivity run.
    baseline_dir = fullfile(sensitivity_dir, "baseline");
    if ~isfolder(baseline_dir)
        error("plot_airborne_baseline_madhav_exceedances:NoBaseline", ...
            "Baseline directory not found: %s", baseline_dir);
    end

    run_config = yaml.loadFile(fullfile(baseline_dir, "run_config.yaml"));
    sim_periods = run_config.sim_periods;
    num_simulations = run_config.num_simulations;
    min_grid = load_arrival_y_min(run_config);

    raw_baseline = fullfile(baseline_dir, "raw");
    [chunk_dirs, ~] = list_chunk_dirs(raw_baseline);
    num_chunks = length(chunk_dirs);

    base_vars = {'sim_num', 'yr_start', 'eff_severity', 'is_false'};
    pandemic_vars = {'sim_num', 'yr_start', 'ex_post_severity', 'is_false'};

    all_base = cell(num_chunks, 1);
    all_pan = cell(num_chunks, 1);
    n_base = 0;
    n_pan = 0;

    for i = 1:num_chunks
        chunk_path = fullfile(raw_baseline, chunk_dirs(i).name);

        S = load(fullfile(chunk_path, "base_simulation_table.mat"), "base_simulation_table");
        base_t = S.base_simulation_table(:, base_vars);
        base_t = base_t(~base_t.is_false & ~isnan(base_t.yr_start), :);
        base_t.is_false = [];
        n_base = n_base + 1;
        all_base{n_base} = base_t;

        pan_path = fullfile(chunk_path, "baseline_pandemic_table.mat");
        S = load(pan_path, "pandemic_table");
        pan_t = S.pandemic_table(:, pandemic_vars);
        pan_t = pan_t(~pan_t.is_false & ~isnan(pan_t.yr_start), :);
        pan_t.is_false = [];
        n_pan = n_pan + 1;
        all_pan{n_pan} = pan_t;
    end

    base_merged = vertcat(all_base{1:n_base});
    pandemic_baseline = vertcat(all_pan{1:n_pan});
    clear all_base all_pan S base_t pan_t

    base_matrix = zeros(num_simulations, sim_periods);
    rel_matrix = zeros(num_simulations, sim_periods);
    idx = sub2ind([num_simulations, sim_periods], base_merged.sim_num, base_merged.yr_start);
    base_matrix(idx) = base_merged.eff_severity;

    keys_b = pandemic_baseline(:, {'sim_num', 'yr_start', 'ex_post_severity'});
    merged_b = outerjoin(base_merged, keys_b, "Keys", {'sim_num', 'yr_start'}, "Type", "left", "MergeKeys", true);
    miss_b = isnan(merged_b.ex_post_severity);
    merged_b.ex_post_severity(miss_b) = merged_b.eff_severity(miss_b);
    rel_matrix(idx) = merged_b.ex_post_severity;
    clear base_merged pandemic_baseline keys_b merged_b miss_b

    sev_all = [base_matrix(:); rel_matrix(:)];
    sev_all = sev_all(isfinite(sev_all) & sev_all > 0);

    x_plot = logspace(log10(min_grid), log10(max(sev_all)), 5000)';
    exceed_rel = empirical_exceedance(rel_matrix(:), x_plot);
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

function fig = plot_s5_curve_set(x_pref, exceed_pref, x_air, exceed_air, x_mad, exceed_mad)
% Plot Figure S5 comparison with three labeled curves.
    color_status = [0.35 0.55 0.88];
    color_madhav = [0.72 0.12 0.12];

    spec = get_paper_figure_spec("double_col_standard");
    fig = figure("Units", "inches", "Position", [1 1 spec.width_in spec.height_in]);
    ax = axes("Parent", fig, "Position", [0.14 0.14 0.82 0.82]);
    hold(ax, "on");

    plot(ax, x_pref, exceed_pref, "LineWidth", spec.stroke.primary, "LineStyle", "-", "Color", color_status);
    plot(ax, x_air, exceed_air, "LineWidth", spec.stroke.primary, "LineStyle", "--", "Color", color_status);
    plot(ax, x_mad, exceed_mad, "LineWidth", spec.stroke.primary, "LineStyle", "-", "Color", color_madhav);

    set(ax, "XScale", "log", "YScale", "log");
    apply_paper_axis_style(ax, spec);
    ax.XMinorGrid = "off";
    ax.YMinorGrid = "off";
    xlabel(ax, "Severity (deaths per 10,000)", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    ylabel(ax, "Annual exceedance risk", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);

    min_x = max([min(x_pref), min(x_air), min(x_mad)]);
    max_x = min([max(x_pref), max(x_air), max(x_mad)]);
    xlim(ax, [min_x, max_x]);
    set_log_axis_tick_labels(ax);

    x_pref_lab = max(min_x, min(max_x, 12));
    x_air_lab = max(min_x, min(max_x, 50));
    x_mad_lab = max(min_x, min(max_x, 11));

    y_pref = interp1(x_pref, exceed_pref, x_pref_lab, "linear", "extrap");
    y_air = interp1(x_air, exceed_air, x_air_lab, "linear", "extrap");
    y_mad = interp1(x_mad, exceed_mad, x_mad_lab, "linear", "extrap");

    text(ax, x_pref_lab, y_pref, {"Status quo response", "(Preferred dataset)"}, ...
        "Color", color_status, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "bottom", "HorizontalAlignment", "left");
    text(ax, x_air_lab, y_air, {"Status quo response", "(Airborne subset)"}, ...
        "Color", color_status, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "top", "HorizontalAlignment", "right");
    text(ax, x_mad_lab, y_mad, "Madhav et al. (2023)", ...
        "Color", color_madhav, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "bottom", "HorizontalAlignment", "left");
end

function set_log_axis_tick_labels(ax)
% Set readable tick labels on log-scaled x-axis.
    xt = get(ax, "XTick");
    labs = arrayfun(@(v) sprintf("%.3g", v), xt, "UniformOutput", false);
    set(ax, "XTickLabel", labs);
end
