function plot_baseline_program_exceedances(plot_mode, varargin)
% Plot exceedance risk comparison for the status-quo vaccine program.
%
% Three simulation curves (plot_mode simulations_only or both):
%   - No mitigation and status quo response: default sensitivity run (base config).
%   - Vaccines always work: shared status-quo baseline for ptrs_pathogen_gamma1
%     (ptrs always succeed, gamma = 1), under baselines/<slug>/raw.
%
% Args (Name-Value pairs):
%   plot_mode: 'simulations_only', 'status_quo_madhav', or 'both'
%   plot_response_threshold: logical, whether to show response threshold (default: true)
%
    % --- Parse inputs
    p = inputParser;
    addParameter(p, "plot_response_threshold", true, @islogical);
    parse(p, varargin{:});
    plot_response_threshold = p.Results.plot_response_threshold;

    % --- Setup directories and config (repo-relative paths, not manifest absolutes)
    sensitivity_dir = fullfile("output", "sensitivity_runs", "baseline_vaccine_program");
    program_dir = fullfile(sensitivity_dir, "vaccine_program");
    always_work_scenario_id = "ptrs_pathogen_gamma1";
    default_dir = fullfile(program_dir, "default");
    default_run_config_path = fullfile(default_dir, "run_config.yaml");

    manifest = load(fullfile(sensitivity_dir, "sensitivity_chunk_manifest.mat"), "chunk_manifest_rows");
    rows = manifest.chunk_manifest_rows;
    always_work_slug = "";
    for i = 1:numel(rows)
        if strcmp(rows{i}.scenario_id, always_work_scenario_id)
            always_work_slug = char(string(rows{i}.status_quo_slug));
            break;
        end
    end
    if strlength(always_work_slug) == 0
        error("Manifest has no row for scenario '%s'.", always_work_scenario_id);
    end
    always_work_dir = fullfile(program_dir, "baselines", always_work_slug);

    run_config = yaml.loadFile(default_run_config_path);
    sim_periods = run_config.sim_periods;
    num_simulations = run_config.num_simulations;
    min_grid = load_arrival_y_min(run_config);
    severity_cap = load_arrival_y_max(run_config);

    % --- Colors
    color_no = [0.12 0.20 0.48]; % What color? 
    color_rel = [0.35 0.55 0.88]; 
    color_alw = [0.18 0.72 0.48];

    % --- Determine which datasets are needed
    is_simulations = any(strcmp(plot_mode, ["simulations_only", "both"]));
    is_baseline = any(strcmp(plot_mode, ["status_quo_madhav", "both"]));

    % --- Load only what is needed, without repeated work ---
    base_merged = [];
    pandemic_baseline = [];
    pandemic_value1 = [];

    if is_simulations || is_baseline
        base_merged = load_base_table(default_dir);
        base_merged.eff_severity = cap_severity(base_merged.eff_severity, severity_cap);
    end
    if is_baseline || is_simulations
        pandemic_baseline = load_pandemic_table(default_dir);
    end
    if is_simulations
        pandemic_always_work = load_pandemic_table(always_work_dir);
    end

    % ------ Plot: simulations_only or both ------
    if is_simulations
        % --- Matrices
        no_mitigation_matrix   = zeros(num_simulations, sim_periods);
        realized_matrix        = zeros(num_simulations, sim_periods);
        always_work_matrix     = zeros(num_simulations, sim_periods);

        idx = sub2ind([num_simulations, sim_periods], base_merged.sim_num, base_merged.yr_start);
        no_mitigation_matrix(idx) = base_merged.eff_severity;

        keys_b = pandemic_baseline(:, {'sim_num', 'yr_start', 'ex_post_severity'});
        merged_b = outerjoin(base_merged, keys_b, "Keys", {'sim_num', 'yr_start'}, "Type", "left", "MergeKeys", true);
        missing_b = isnan(merged_b.ex_post_severity);
        merged_b.ex_post_severity(missing_b) = merged_b.eff_severity(missing_b);
        merged_b.ex_post_severity = cap_severity(merged_b.ex_post_severity, severity_cap);
        realized_matrix(idx) = merged_b.ex_post_severity;

        keys_alw = pandemic_always_work(:, {'sim_num', 'yr_start', 'ex_post_severity'});
        merged_alw = outerjoin(base_merged, keys_alw, "Keys", {'sim_num', 'yr_start'}, "Type", "left", "MergeKeys", true);
        missing_alw = isnan(merged_alw.ex_post_severity);
        merged_alw.ex_post_severity(missing_alw) = merged_alw.eff_severity(missing_alw);
        merged_alw.ex_post_severity = cap_severity(merged_alw.ex_post_severity, severity_cap);
        always_work_matrix(idx) = merged_alw.ex_post_severity;
        clear keys_b merged_b missing_b keys_alw merged_alw missing_alw

        % Define grid for calculating exceedances
        max_no = max(no_mitigation_matrix, [], 'all');
        max_rel = max(realized_matrix, [], 'all');
        max_alw = max(always_work_matrix, [], 'all');
        max_grid = max([max_no, max_rel, max_alw]);
        x_plot = logspace(log10(min_grid), log10(max_grid), 2000)';

        % Exceedance
        exceed_no  = empirical_exceedance(no_mitigation_matrix(:), x_plot);
        exceed_rel = empirical_exceedance(realized_matrix(:), x_plot);
        exceed_alw = empirical_exceedance(always_work_matrix(:), x_plot);

        % Save table outputs as before
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

        % --- Threshold marker location
        thr_x = []; thr_y = [];
        if plot_response_threshold
            [thr_x, thr_y] = load_response_threshold_marker(run_config, x_plot, exceed_no);
        end

        % --- Plot and save
        fig = plot_simulations_only_curve(x_plot, exceed_no, exceed_rel, exceed_alw, ...
            color_no, color_rel, color_alw, thr_x, thr_y);
        out = fullfile(sensitivity_dir, "figures", "status_quo_program_exceedance_curves.pdf");
        if ~isfolder(fileparts(out))
            mkdir(fileparts(out));
        end
        export_figure(fig, out);
        close(fig);
        fprintf("Exceedance plot saved to %s\n", out);
        clear no_mitigation_matrix realized_matrix always_work_matrix idx sev_all x_plot exceed_no exceed_rel exceed_alw recur_no recur_rel recur_alw T small_T target_severities thr_x thr_y fig out
    end

    % ------ Plot: status_quo_madhav (baseline only) ------
    if is_baseline
        realized_matrix = zeros(num_simulations, sim_periods);
        idx = sub2ind([num_simulations, sim_periods], base_merged.sim_num, base_merged.yr_start);
        keys_b = pandemic_baseline(:, {'sim_num', 'yr_start', 'ex_post_severity'});
        merged_b = outerjoin(base_merged, keys_b, "Keys", {'sim_num', 'yr_start'}, "Type", "left", "MergeKeys", true);
        missing_b = isnan(merged_b.ex_post_severity);
        merged_b.ex_post_severity(missing_b) = merged_b.eff_severity(missing_b);
        merged_b.ex_post_severity = cap_severity(merged_b.ex_post_severity, severity_cap);
        realized_matrix(idx) = merged_b.ex_post_severity;
        clear keys_b merged_b missing_b
        sev_all = realized_matrix(:);
        sev_all = sev_all(isfinite(sev_all) & sev_all > 0);
        x_plot = logspace(log10(min_grid), log10(max(sev_all)), 5000)';
        exceed_rel = empirical_exceedance(realized_matrix(:), x_plot);

        recur_rel = 1 ./ exceed_rel(:);
        T_rel = table(x_plot, recur_rel, ...
            'VariableNames', {'severity', 'mean_realized_recurrence'});
        writetable(T_rel, fullfile(sensitivity_dir, "mean_annual_recurrence_rates_status_quo_baseline.csv"));

        madhav_path = fullfile("data", "clean", "madhav_et_al_severity_exceedance.csv");
        madhav_exceedances = readtable(madhav_path);
        [madhav_severity, sort_idx] = sort(madhav_exceedances.severity_central);
        madhav_exceedance = madhav_exceedances.exceedance_central(sort_idx);
        valid_madhav = madhav_severity > 0 & isfinite(madhav_exceedance);
        madhav_severity = madhav_severity(valid_madhav);
        madhav_exceedance = madhav_exceedance(valid_madhav);
        clear madhav_exceedances sort_idx valid_madhav

        % Plot status quo against Madhav reference
        fig = plot_status_quo_madhav_curve(x_plot, exceed_rel, madhav_severity, madhav_exceedance);

        out = fullfile(sensitivity_dir, "figures", "status_quo_madhav_exceedance_comparison.pdf");
        if ~isfolder(fileparts(out))
            mkdir(fileparts(out)); 
        end
        export_figure(fig, out);
        close(fig);
        fprintf("Exceedance plot comparison saved to %s\n", out);
    end

end

function base_tab = load_base_table(dir_name)
% Load all base simulation chunks for one sensitivity directory.
    base_vars = {'sim_num', 'yr_start', 'eff_severity', 'is_false'};
    raw_dir = fullfile(dir_name, "raw");
    [chunk_dirs, ~] = list_chunk_dirs(raw_dir);
    n_chunks = length(chunk_dirs);
    base_cells = cell(n_chunks,1);
    n_base = 0;
    for i = 1:n_chunks
        ch_name = chunk_dirs(i).name;
        chunk = fullfile(raw_dir, ch_name);
        S = load(fullfile(chunk, "base_simulation_table.mat"), "base_simulation_table");
        base_t = S.base_simulation_table(:, base_vars);
        base_t = base_t(~base_t.is_false, :);
        base_t.is_false = [];
        n_base = n_base + 1;
        base_cells{n_base} = base_t;
    end
    base_tab = vertcat(base_cells{1:n_base});
end

function pandemic_tab = load_pandemic_table(dir_name)
% Load all baseline pandemic chunks for one sensitivity directory.
    pandemic_vars = {'sim_num', 'yr_start', 'ex_post_severity', 'is_false'};
    raw_dir = fullfile(dir_name, "raw");
    [chunk_dirs, ~] = list_chunk_dirs(raw_dir);
    n_chunks = length(chunk_dirs);
    pan_cells = cell(n_chunks,1);
    n_pan = 0;
    for i = 1:n_chunks
        ch_name = chunk_dirs(i).name;
        chunk = fullfile(raw_dir, ch_name);
        S = load(fullfile(chunk, "status_quo_pandemic_table.mat"), "pandemic_table");
        pan_t = S.pandemic_table(:, pandemic_vars);
        pan_t = pan_t(~pan_t.is_false, :);
        pan_t.is_false = [];
        n_pan = n_pan + 1; pan_cells{n_pan} = pan_t;
    end
    pandemic_tab = vertcat(pan_cells{1:n_pan});
end

function [thr_x, thr_y] = load_response_threshold_marker(run_config, x_plot, exceed_no)
% Load and place a severity-threshold marker on the exceedance curve.
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
        d = yaml.loadFile(pth);
        thr_val = double(d.response_threshold);
        thr_type = string(d.response_threshold_type);
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

function y_max = load_arrival_y_max(run_config)
% Load y_max (severity ceiling) from arrival distribution hyperparameters.
    arrival_dir = char(string(run_config.arrival_dist_config));
    hyper = yaml.loadFile(fullfile(arrival_dir, "hyperparams.yaml"));
    y_max = double(hyper.y_max);
end

function v = cap_severity(v, severity_cap)
% Clip severity samples to the arrival distribution ceiling (removes fp overshoot).
    v = min(v, severity_cap);
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
% Plot no-mitigation, status-quo, and always-work exceedance curves.
    color_thr = [0.72 0.12 0.12];
    spec = get_paper_figure_spec("double_col_standard");
    fig = figure("Units", "inches", "Position", [1 1 spec.width_in spec.height_in]);
 
    ax = axes("Parent", fig, "Position", [0.14 0.14 0.82 0.82]);
    hold(ax, "on");

    % Only use strictly positive exceedance values for each curve for correct line-to-bottom
    pos_no_idx = exceed_no > 0;
    x_plot_no_pos = x_plot(pos_no_idx);
    exceed_no_pos = exceed_no(pos_no_idx);

    pos_rel_idx = exceed_rel > 0;
    x_plot_rel_pos = x_plot(pos_rel_idx);
    exceed_rel_pos = exceed_rel(pos_rel_idx);

    pos_alw_idx = exceed_alw > 0;
    x_plot_alw_pos = x_plot(pos_alw_idx);
    exceed_alw_pos = exceed_alw(pos_alw_idx);

    % Truncation floor and y-axis lower limit from right-end exceedance
    last_y_no = exceed_no_pos(end);
    last_y_rel = exceed_rel_pos(end);
    last_y_alw = exceed_alw_pos(end);
    min_last_y = min([last_y_no; last_y_rel; last_y_alw]);
    min_y_rounded = 10^floor(log10(min_last_y));

    % Extend each curve with a point at their max x just above the rounded floor so we get a truncation line
    last_x_no = max(x_plot_no_pos);
    x_plot_no_ext = [x_plot_no_pos(:); last_x_no];
    exceed_no_ext = [exceed_no_pos(:); min_y_rounded];

    last_x_rel = max(x_plot_rel_pos);
    x_plot_rel_ext = [x_plot_rel_pos(:); last_x_rel];
    exceed_rel_ext = [exceed_rel_pos(:); min_y_rounded];

    last_x_alw = max(x_plot_alw_pos);
    x_plot_alw_ext = [x_plot_alw_pos(:); last_x_alw];
    exceed_alw_ext = [exceed_alw_pos(:); min_y_rounded];

    plot(ax, x_plot_no_ext, exceed_no_ext, "LineWidth", spec.stroke.primary, "Color", color_no);
    plot(ax, x_plot_rel_ext, exceed_rel_ext, "LineWidth", spec.stroke.primary, "Color", color_rel);
    plot(ax, x_plot_alw_ext, exceed_alw_ext, "LineWidth", spec.stroke.primary, "Color", color_alw);

    set(ax, "XScale", "log", "YScale", "log");
    apply_paper_axis_style(ax, spec);
    ax.XMinorGrid = "off";
    ax.YMinorGrid = "off";
    xlabel(ax, "Severity (deaths per 10,000)", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    ylabel(ax, "Annual exceedance risk", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);

    xlim(ax, [min(x_plot), max(x_plot_no_pos)]);

    % y-limits: set lower to the nearest tick below min, at the same decimal place
    all_vals = [exceed_no(:); exceed_rel(:); exceed_alw(:)];
    max_y_val = max(all_vals);

    % Find minimum positive value
    min_y_val = min(all_vals(all_vals > 0));
    order_of_mag = floor(log10(min_y_val));
    step = 10^order_of_mag;
    num_steps = 2;

    % Set y axis limits
    min_y_below = floor((min_y_val / step - num_steps)) * step;  % Few steps below on same order of magnitude as min_y_val
    max_y_rounded = 10^ceil(log10(max_y_val)); % Upper y-limit rounded up to next order of magnitude
    ylim(ax, [min_y_below, max_y_rounded]);

    if ~isempty(thr_x)
        yl = get(ax, "YLim");
        plot(ax, [thr_x thr_x], yl, "--", "Color", color_thr, "LineWidth", spec.stroke.reference);
        label_y = 0.075;
        text(ax, thr_x * 0.9, label_y, sprintf("Response\nthreshold: %.2f", thr_x), ...
            "VerticalAlignment", "top", "HorizontalAlignment", "right", ...
            "FontSize", spec.typography.legend, "FontName", spec.font_name, "Color", color_thr);
    end

    x_lab_no = 30;
    x_lab_rel = 60;
    x_lab_alw = 90;
    y_no = interp1(x_plot_no_pos, exceed_no_pos, x_lab_no, "linear", "extrap");
    y_rel = interp1(x_plot_rel_pos, exceed_rel_pos, x_lab_rel, "linear", "extrap");
    y_alw = interp1(x_plot_alw_pos, exceed_alw_pos, x_lab_alw, "linear", "extrap");

    text(ax, x_lab_no, y_no, {"No", "mitigation"}, ...
        "Color", color_no, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "bottom", "HorizontalAlignment", "left");
    text(ax, x_lab_rel, y_rel, {"Status quo", "response"}, ...
        "Color", color_rel, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "top", "HorizontalAlignment", "right");
    text(ax, x_lab_alw, y_alw, {"Vaccines", "always work"}, ...
        "Color", color_alw, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "top", "HorizontalAlignment", "right");

    % Round x-axis tick labels
    xt = get(ax, "XTick");
    labs = arrayfun(@(v) sprintf("%.3g", v), xt, "UniformOutput", false);
    set(ax, "XTickLabel", labs);
end

function fig = plot_status_quo_madhav_curve(x_plot, exceed_rel, x_mad, exceed_mad)
% Plot status quo response against Madhav et al. exceedance reference.

    spec = get_paper_figure_spec("double_col_standard");
    color_status = [0.35 0.55 0.88];
    color_madhav = [0.72 0.12 0.12];

    fig = figure("Units", "inches", "Position", [1 1 spec.width_in spec.height_in]);
    ax = axes("Parent", fig, "Position", [0.14 0.14 0.82 0.82]);

    hold(ax, "on");

    % Only use strictly positive exceed_rel values for min calculation/plotting
    pos_rel_idx = exceed_rel > 0;
    x_plot_pos = x_plot(pos_rel_idx);
    exceed_rel_pos = exceed_rel(pos_rel_idx);

    min_rel = min(exceed_rel_pos);
    min_mad = min(exceed_mad(exceed_mad > 0));
    min_y_val = min([10^floor(log10(min_rel)); min_mad]);

    % Add a very small point at last x just above the rounded floor so we get a truncation line.
    last_x_rel = max(x_plot_pos);
    x_plot_ext = [x_plot_pos(:); last_x_rel];
    exceed_rel_ext = [exceed_rel_pos(:); min_y_val];

    plot(ax, x_plot_ext, exceed_rel_ext, "LineWidth", spec.stroke.primary, "LineStyle", "-", "Color", color_status);
    plot(ax, x_mad, exceed_mad, "LineWidth", spec.stroke.primary, "LineStyle", "-", "Color", color_madhav);

    set(ax, "XScale", "log", "YScale", "log");
    apply_paper_axis_style(ax, spec);
    ax.XMinorGrid = "off";
    ax.YMinorGrid = "off";
    xlabel(ax, "Severity (deaths per 10,000)", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    ylabel(ax, "Annual exceedance risk", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);

    % y-limits: keep lower at min_y_rounded, upper as before
    max_y_val = max([exceed_rel(:); exceed_mad(:)]);
    max_y_rounded = 10^ceil(log10(max_y_val) - 1); % Hacky way to get to appropriate point as we screen off some Madhav data.
    max_x = 10^ceil(log10(max(x_plot)));

    xlim(ax, [min(x_plot), max_x]);
    ylim(ax, [min_y_val, max_y_rounded]);

    % Add line labels
    x_rel_lab = 0.015;
    x_mad_lab = 0.015;
    y_rel = interp1(x_plot, exceed_rel, x_rel_lab, "linear", "extrap");
    y_mad = interp1(x_mad, exceed_mad, x_mad_lab, "linear", "extrap");

    text(ax, x_rel_lab, y_rel - 0.005, {"Status quo", "response"}, ...
        "Color", color_status, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "top", "HorizontalAlignment", "left", "Rotation", 0);
    text(ax, x_mad_lab, y_mad - 0.033, "Madhav et al. (2023)", ...
        "Color", color_madhav, "FontName", spec.font_name, "FontSize", spec.typography.legend, ...
        "VerticalAlignment", "top", "HorizontalAlignment", "left", "Rotation", 0);

    % Round x-axis tick labels
    xt = get(ax, "XTick");
    labs = arrayfun(@(v) sprintf("%.3g", v), xt, "UniformOutput", false);
    set(ax, "XTickLabel", labs);
end