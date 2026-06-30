function write_advance_invest_sensitivity_figures(sensitivity_root_dir)
    % Plot advance-investment sensitivity NPV as grouped horizontal bars.
    %
    % Reads processed benefits summaries under each program folder (same layout as
    % write_adv_invest_sensitivity_table). Bars show reference-scenario net present
    % value relative to status quo vaccine response, in billions of 2024 USD.
    %
    % Writes one PDF per program plus two wide one-row/two-column pair PDFs.
    %
    % Args:
    %   sensitivity_root_dir  Top-level sensitivity run directory containing
    %                         program_sensitivity_config.yaml and program subfolders.

    sensitivity_root_dir = char(sensitivity_root_dir);
    fig_dir = fullfile(sensitivity_root_dir, 'figures');
    if ~isfolder(fig_dir)
        mkdir(fig_dir);
    end

    cfg = yaml.loadFile(fullfile(sensitivity_root_dir, 'program_sensitivity_config.yaml'));
    program_names = get_adv_invest_program_order(fieldnames(cfg.program_sensitivities));
    shared_panel = adv_invest_shared_single_panel_spec(sensitivity_root_dir, program_names);

    for p = 1:numel(program_names)
        program_name = program_names{p};
        outpath = fullfile(fig_dir, sprintf('advance_investment_sensitivity_npv_%s.pdf', program_name));
        plot_advance_invest_npv_program(sensitivity_root_dir, outpath, program_name, shared_panel);
        fprintf('Advance investment sensitivity NPV figure saved to %s\n', outpath);
    end

    pair_specs = {
        {'advance_capacity', 'prototype_rd'}, ...
        'advance_investment_sensitivity_npv_capacity_prototype_pair.pdf'
        {'universal_flu_vaccine', 'improved_early_warning'}, ...
        'advance_investment_sensitivity_npv_ufv_early_warning_pair.pdf'
    };
    for i = 1:size(pair_specs, 1)
        outpath = fullfile(fig_dir, pair_specs{i, 2});
        plot_advance_invest_npv_panel_pair(sensitivity_root_dir, outpath, pair_specs{i, 1});
        fprintf('Advance investment sensitivity NPV pair figure saved to %s\n', outpath);
    end
end


function panel_data = collect_program_panel_data(sensitivity_root_dir, program_name)
    % Collect bar-chart rows for one advance-investment program panel.

    program_dir = fullfile(sensitivity_root_dir, program_name);
    program_cfg = yaml.loadFile(fullfile(program_dir, 'sensitivity_config.yaml'));
    program_label = format_program_name(program_name);

    reference_path = fullfile(program_dir, 'processed', 'status_quo_benefits_summary.mat');
    reference_data = load(reference_path, 'reference_scenario_relative_mean_net_value');
    reference_npv_billion = reference_data.reference_scenario_relative_mean_net_value / 1e9;

    labels = strings(0, 1);
    npv_billion = [];
    layout_group_keys = strings(0, 1);

    labels(end + 1, 1) = "";
    npv_billion(end + 1, 1) = reference_npv_billion;
    layout_group_keys(end + 1, 1) = "__reference__";

    eligible_params = filter_eligible_adv_invest_params( ...
        program_cfg, fieldnames(program_cfg.sensitivities), program_name);
    table_layout = get_adv_invest_figure_program_layout(program_name, eligible_params);

    for i = 1:numel(table_layout)
        entry = table_layout{i};
        if ~strcmp(entry.kind, 'parameter')
            continue;
        end
        param_name = entry.param_name;
        param_entry = program_cfg.sensitivities.(param_name);
        layout_key = adv_invest_figure_layout_group_key(param_name, program_name);
        rows = load_advance_invest_parameter_chart_rows( ...
            program_dir, param_name, param_entry, program_name);
        n_new = numel(rows.npv_billion);
        labels(end + (1:n_new), 1) = rows.labels;
        npv_billion(end + (1:n_new), 1) = rows.npv_billion;
        layout_group_keys(end + (1:n_new), 1) = repmat(layout_key, n_new, 1);
    end

    panel_data = struct('program_label', program_label, 'labels', labels, ...
        'npv_billion', npv_billion, 'layout_group_keys', layout_group_keys);
end


function rows = load_advance_invest_parameter_chart_rows(program_dir, param_name, param_entry, program_name)
    % Load chart rows for one sensitivity parameter (one or two perturbations).

    if sensitivity_table.common.is_numeric_sensitivity_sweep(param_entry)
        rows = load_numeric_sweep_chart_rows(program_dir, param_name, program_name);
    elseif sensitivity_table.common.is_alternative_spec_sensitivity(param_entry)
        rows = load_alternative_spec_chart_rows(program_dir, param_name, param_entry, program_name);
    else
        error('Unsupported sensitivity entry for "%s".', param_name);
    end
end


function rows = load_numeric_sweep_chart_rows(program_dir, param_name, program_name)
    % Two chart rows for a value_1 / value_2 sensitivity sweep.

    value_1_path = fullfile(program_dir, 'processed', sprintf('%s_value_1_benefits_summary.mat', param_name));
    value_2_path = fullfile(program_dir, 'processed', sprintf('%s_value_2_benefits_summary.mat', param_name));
    value_1_data = load(value_1_path, 'scenario_relative_mean_net_value', 'run_config');
    value_2_data = load(value_2_path, 'scenario_relative_mean_net_value', 'run_config');

    value_1 = value_1_data.run_config.(param_name);
    value_2 = value_2_data.run_config.(param_name);
    npv_1 = value_1_data.scenario_relative_mean_net_value / 1e9;
    npv_2 = value_2_data.scenario_relative_mean_net_value / 1e9;

    [low_value, high_value, low_npv, high_npv] = sensitivity_table.common.order_sensitivity_pair( ...
        value_1, npv_1, value_2, npv_2, param_name);

    baseline_config = get_adv_invest_baseline_config(program_dir);
    rows = struct();
    rows.labels = [
        chart_perturbation_label(param_name, low_value, program_name, baseline_config)
        chart_perturbation_label(param_name, high_value, program_name, baseline_config)];
    rows.npv_billion = [low_npv; high_npv];
    rows.param_name = {param_name, param_name};
end


function rows = load_alternative_spec_chart_rows(program_dir, param_name, param_entry, program_name)
    % One chart row for a single alternative-specification scenario.

    benefits_path = fullfile(program_dir, 'processed', sprintf('%s_benefits_summary.mat', param_name));
    alt_data = load(benefits_path, 'scenario_relative_mean_net_value', 'run_config');
    npv_billion = alt_data.scenario_relative_mean_net_value / 1e9;
    display_value = get_adv_invest_alternative_display_value(param_name, param_entry, alt_data.run_config);

    rows = struct();
    baseline_config = get_adv_invest_baseline_config(program_dir);
    rows.labels = chart_perturbation_label(param_name, display_value, program_name, baseline_config);
    rows.npv_billion = npv_billion;
    rows.param_name = {param_name};
end


function label = chart_perturbation_label(param_name, value, program_name, baseline_config)
    % Build a scenario tick label (value only; group header drawn separately).

    if nargin < 4
        baseline_config = [];
    end
    value_str = format_value_for_chart(value, param_name, baseline_config);
    bullet = chart_scenario_bullet();
    if adv_invest_figure_uses_platform_subtitle(param_name)
        platform = adv_invest_parameter_display_name(param_name, program_name);
        label = bullet + platform + ": " + string(value_str);
    else
        label = bullet + string(value_str);
    end
end


function bullet = chart_scenario_bullet()
    % Unicode bullet for tick labels (no TeX interpreter).

    bullet = string(char(8226)) + " ";
end


function value = get_adv_invest_alternative_display_value(param_name, param_entry, run_config)
    % Display value for an alternative-specification sensitivity row.

    if strcmp(param_name, 'include_unid_yearthreshonly')
        value = param_entry.arrival_dist_config;
    elseif isfield(param_entry, 'arrival_dist_config')
        value = param_entry.arrival_dist_config;
    else
        fields = fieldnames(param_entry);
        value = run_config.(fields{1});
    end
end


function plot_advance_invest_npv_program(sensitivity_root_dir, outpath, program_name, shared_panel)
    % Single-program figure of relative NPV sensitivities.

    pdata = collect_program_panel_data(sensitivity_root_dir, program_name);
    spec = shared_panel.spec;

    xlim_upper = 1;
    if ~isempty(pdata.npv_billion)
        xlim_upper = ceil(max(pdata.npv_billion) * 1.08);
    end

    fig = figure('Visible', 'off', 'Units', 'inches', ...
        'Position', [1 1 spec.width_in spec.height_in]);
    ax = axes(fig, 'Position', adv_invest_axes_position(shared_panel.layout_nrows));
    bar_color = [0.2 0.4 0.8];
    render_adv_invest_npv_panel(ax, pdata, xlim_upper, bar_color, spec);

    xlabel(ax, 'Net present value relative to status quo (billion USD)', ...
        'FontName', spec.font_name, 'FontSize', spec.typography.axis_label, ...
        'Interpreter', 'none', 'Color', [0.2 0.2 0.2]);

    export_figure(fig, outpath);
    close(fig);
end


function shared_panel = adv_invest_shared_single_panel_spec(sensitivity_root_dir, program_names)
    % Shared figure size and left margin for LaTeX subpanels (sized to the tallest panel).
    %
    % Each panel uses its own y-axis limits so bars fill the axes vertically; only the
    % outer figure dimensions and label margin are shared across programs.

    max_nrows = 0;
    for p = 1:numel(program_names)
        pdata = collect_program_panel_data(sensitivity_root_dir, program_names{p});
        max_nrows = max(max_nrows, numel(pdata.npv_billion));
    end

    shared_panel = struct();
    shared_panel.layout_nrows = max_nrows;
    shared_panel.spec = adv_invest_single_program_figure_spec(max_nrows);
end


function spec = adv_invest_single_program_figure_spec(nrows)
    % Figure size from double_col_standard preset, scaled to the tallest program panel.

    spec = get_paper_figure_spec('double_col_standard');
    height_scale = 1.35 + 0.012 * max(0, nrows - 12);
    spec.height_in = spec.height_in * height_scale;
end


function spec = adv_invest_wide_pair_figure_spec(nrows_max)
    % Wide two-panel figure (wide_page_2col preset) for a side-by-side page layout.

    spec = get_paper_figure_spec('wide_page_2col');
    height_scale = 1.30 + 0.010 * max(0, nrows_max - 14);
    spec.height_in = spec.height_in * height_scale;
end


function plot_advance_invest_npv_panel_pair(sensitivity_root_dir, outpath, program_names)
    % One-row, two-column wide figure with two programs side by side.

    n_programs = numel(program_names);
    panel_data = cell(n_programs, 1);
    nrows = zeros(n_programs, 1);
    xlim_upper = 1;

    for p = 1:n_programs
        panel_data{p} = collect_program_panel_data(sensitivity_root_dir, program_names{p});
        nrows(p) = numel(panel_data{p}.npv_billion);
        if ~isempty(panel_data{p}.npv_billion)
            xlim_upper = max(xlim_upper, max(panel_data{p}.npv_billion));
        end
    end
    xlim_upper = ceil(xlim_upper * 1.08);

    spec = adv_invest_wide_pair_figure_spec(max(nrows));
    fig = figure('Visible', 'off', 'Units', 'inches', ...
        'Position', [1 1 spec.width_in spec.height_in]);
    bar_color = [0.2 0.4 0.8];
    axes_list = gobjects(n_programs, 1);

    for t = 1:n_programs
        axes_list(t) = axes(fig, 'Position', adv_invest_pair_axes_position(nrows(t), t, n_programs));
        render_adv_invest_npv_panel(axes_list(t), panel_data{t}, xlim_upper, bar_color, spec);
    end

    x_label = 'Net present value relative to status quo (billion USD)';
    for t = 1:n_programs
        xlabel(axes_list(t), x_label, 'FontName', spec.font_name, ...
            'FontSize', spec.typography.axis_label, 'Interpreter', 'none', ...
            'Color', [0.2 0.2 0.2]);
    end

    export_figure(fig, outpath);
    close(fig);
end


function pos = adv_invest_axes_position(nrows)
    % Normalized axes position leaving room for long y-axis labels (single-panel).

    left = min(0.48, 0.34 + 0.004 * nrows);
    pos = [left, 0.11, 0.94 - left, 0.80];
end


function pos = adv_invest_pair_axes_position(nrows, panel_idx, n_panels)
    % Normalized axes position for one panel in a wide one-row multi-column figure.

    gap = 0.04;
    bottom = 0.11;
    height = 0.82;
    panel_width = (0.94 - gap * (n_panels - 1)) / n_panels;
    left_edge = 0.03 + (panel_idx - 1) * (panel_width + gap);
    label_margin = min(0.16, 0.10 + 0.002 * nrows);
    pos = [left_edge + label_margin, bottom, panel_width - label_margin, height];
end


function render_adv_invest_npv_panel(ax, pdata, xlim_upper, bar_color, spec)
    % Draw one program panel with parameter headings and scenario tick labels.

    npv = pdata.npv_billion(:);
    nrows = numel(npv);

    [y_bar, y_ticks, y_ticklabels, header_y, header_labels] = ...
        advance_invest_grouped_y_layout(pdata.layout_group_keys, pdata.labels);

    b = barh(ax, y_bar, npv, 'FaceColor', 'flat');
    b.CData = repmat(bar_color, nrows, 1);
    ax.YDir = 'reverse';
    ax.YTick = y_ticks;
    ax.TickLabelInterpreter = 'none';
    ax.YTickLabel = cellstr(y_ticklabels);

    apply_axis_style(ax, spec);
    if isempty(y_bar)
        ylim(ax, [0, 1]);
    else
        ylim(ax, [0.5, max(y_bar) + 0.5]);
    end
    header_gap = 0.4;
    xlim(ax, [-header_gap, xlim_upper]);
    set(ax, 'Layer', 'bottom');
    format_axis_ticks(ax);
    draw_advance_invest_group_headers(ax, header_y, ...
        pad_parameter_header_label(header_labels), header_gap, spec);

    for i = 1:nrows
        text(ax, npv(i) + 0.02 * xlim_upper, y_bar(i), format_bar_npv_label(npv(i)), ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'FontName', spec.font_name, 'FontSize', spec.typography.legend - 1, ...
            'Interpreter', 'none', 'Color', [0.2 0.2 0.2]);
    end
end


function [y_bar, y_ticks, y_ticklabels, header_y, header_labels] = ...
        advance_invest_grouped_y_layout(layout_group_keys, scenario_labels)
    % Build y positions with bold parameter headings left of scenario tick labels.

    unique_groups = unique(layout_group_keys, 'stable');
    nrows = numel(scenario_labels);
    y_bar = zeros(nrows, 1);
    y_ticks = [];
    y_ticklabels = strings(0, 1);
    header_y = [];
    header_labels = strings(0, 1);
    current_y = 1;

    for g = 1:numel(unique_groups)
        this_group = unique_groups(g);
        in_group = find(layout_group_keys == this_group);
        if isempty(in_group)
            continue;
        end

        if this_group == "__reference__"
            for j = 1:numel(in_group)
                row_idx = in_group(j);
                y_bar(row_idx) = current_y;
                header_y(end + 1, 1) = current_y; %#ok<AGROW>
                header_labels(end + 1, 1) = "Reference program"; %#ok<AGROW>
                current_y = current_y + 1;
            end
            current_y = current_y + 1.3;
        else
            header_y(end + 1, 1) = current_y; %#ok<AGROW>
            header_labels(end + 1, 1) = adv_invest_figure_layout_group_header(this_group); %#ok<AGROW>
            current_y = current_y + 1;
            for j = 1:numel(in_group)
                row_idx = in_group(j);
                y_bar(row_idx) = current_y;
                y_ticks(end + 1, 1) = current_y; %#ok<AGROW>
                y_ticklabels(end + 1, 1) = "   " + scenario_labels(row_idx); %#ok<AGROW>
                current_y = current_y + 1.15;
            end
            current_y = current_y + 1.2;
        end
    end
end


function draw_advance_invest_group_headers(ax, header_y, header_labels, gap, spec)
    % Draw parameter-group headers left of the axis (plain text, no TeX).

    if nargin < 4 || isempty(gap)
        gap = 0.4;
    end
    if isempty(header_y)
        return;
    end
    header_fs = spec.typography.axis_label;
    x_pos = ax.XLim(1) - gap;
    for k = 1:numel(header_y)
        text(ax, x_pos, header_y(k), header_labels(k), ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
            'FontName', char(spec.font_name), 'FontWeight', 'bold', ...
            'FontSize', header_fs - 1, 'Interpreter', 'none', 'Color', [0.2 0.2 0.2], ...
            'Clipping', 'off');
    end
end


function labels_out = pad_parameter_header_label(labels_in)
    % Append one ASCII space after bold parameter headers (not value tick labels).

    labels_out = string(labels_in) + " ";
end


function header = adv_invest_figure_layout_group_header(layout_key)
    % Human-readable header text from a layout group key.

    key = char(layout_key);
    if startsWith(key, 'grp:')
        header = string(extractAfter(layout_key, 'grp:'));
    elseif startsWith(key, 'param:')
        header = string(extractAfter(layout_key, 'param:'));
    else
        header = string(layout_key);
    end
end


function layout_key = adv_invest_figure_layout_group_key(param_name, program_name)
    % Layout group key for figure y-axis blocks.

    group_header = adv_invest_figure_group_header(param_name);
    if ~isempty(group_header)
        layout_key = "grp:" + string(group_header);
    else
        layout_key = "param:" + string(adv_invest_parameter_display_name(param_name, program_name));
    end
end


function ordered_programs = get_adv_invest_program_order(all_programs)
    % Return advance investment programs in a fixed display order (same as table script).

    preferred_order = { ...
        'advance_capacity', ...
        'prototype_rd', ...
        'universal_flu_vaccine', ...
        'improved_early_warning' ...
    };

    ordered_programs = {};
    for i = 1:length(preferred_order)
        program_name = preferred_order{i};
        if any(strcmp(program_name, all_programs))
            ordered_programs{end + 1} = program_name; %#ok<AGROW>
        end
    end

    for i = 1:length(all_programs)
        program_name = all_programs{i};
        if ~any(strcmp(program_name, ordered_programs))
            ordered_programs{end + 1} = program_name; %#ok<AGROW>
        end
    end
end


function eligible_params = filter_eligible_adv_invest_params(program_cfg, param_names, program_name)
    % Return all sensitivity parameters eligible for figure panels.

    excluded = adv_invest_figure_excluded_parameters(program_name);
    eligible_params = {};
    for i = 1:numel(param_names)
        param_name = param_names{i};
        if any(strcmp(param_name, excluded))
            continue;
        end
        param_entry = program_cfg.sensitivities.(param_name);
        if sensitivity_table.common.is_numeric_sensitivity_sweep(param_entry) || ...
                sensitivity_table.common.is_alternative_spec_sensitivity(param_entry)
            eligible_params{end + 1} = param_name; %#ok<AGROW>
        end
    end
end


function excluded = adv_invest_figure_excluded_parameters(program_name)
    % Sensitivity parameters omitted from advance-investment figure panels.

    excluded = {};
    if strcmp(program_name, 'advance_capacity')
        excluded = {'delta'};
    end
end


function layout = get_adv_invest_figure_program_layout(program_name, eligible_params)
    % Return ordered figure layout entries (includes arrival-distribution sensitivities).

    program_specs = containers.Map();
    program_specs('advance_capacity') = { ...
        'adv_cap_build_period', ...
        'theta', ...
        'tailoring_fraction', ...
        'max_capacity', ...
        'capacity_kept', ...
        'epsilon', ...
        struct('label', 'Capacity unit cost (per annual course)', 'children', {{'k_m', 'k_o'}}), ...
        struct('label', 'Surge capacity (annual courses)', 'children', {{'surge_cap_mrna', 'surge_cap_trad'}}) ...
    };
    program_specs('prototype_rd') = { ...
        'advance_RD_cost_per_pathogen', ...
        'advance_RD_benefit_start', ...
        'prototype_success_prob', ...
        'prototype_effect_ptrs', ...
        struct('label', 'Response R&D timeline', 'children', {{'rd_months_with_prototype', 'rd_months_no_prototype'}}) ...
    };
    program_specs('universal_flu_vaccine') = { ...
        'univ_flu_vax_eff_multiplier', ...
        'univ_flu_cost_multiplier', ...
        'initial_share_ufv', ...
        'ufv_success_prob', ...
        'advance_RD_benefit_start' ...
    };
    program_specs('improved_early_warning') = { ...
        'ew_annual_cost', ...
        'improved_ew_precision', ...
        'improved_ew_recall', ...
        'months_to_early_detect', ...
        'frac_invest_on_false', ...
        'capacity_kept' ...
    };

    layout = {};
    if isKey(program_specs, program_name)
        layout = build_adv_invest_layout_from_specs(program_specs(program_name), eligible_params);
    end
    layout = append_unlisted_adv_invest_layout_params(layout, eligible_params);
    layout = append_adv_invest_figure_arrival_params(layout, eligible_params);
end


function layout = append_adv_invest_figure_arrival_params(layout, eligible_params)
    % Append arrival-distribution sensitivities at the end of each program panel.

    trailing_params = {'arrival_dist_config', 'include_unid_yearthreshonly'};
    listed = collect_adv_invest_layout_param_names(layout);
    for i = 1:numel(trailing_params)
        param_name = trailing_params{i};
        if any(strcmp(param_name, eligible_params)) && ~any(strcmp(param_name, listed))
            layout{end + 1} = struct('kind', 'parameter', 'param_name', param_name); %#ok<AGROW>
            listed{end + 1} = param_name; %#ok<AGROW>
        end
    end
end


function layout = build_adv_invest_layout_from_specs(spec_items, eligible_params)
    % Expand program layout specs into layout entry structs.

    layout = {};
    for i = 1:numel(spec_items)
        item = spec_items{i};
        if ischar(item) || isstring(item)
            param_name = char(item);
            if any(strcmp(param_name, eligible_params))
                layout{end + 1} = struct('kind', 'parameter', 'param_name', param_name); %#ok<AGROW>
            end
        elseif isstruct(item)
            child_params = filter_adv_invest_params_in_order(item.children, eligible_params);
            if ~isempty(child_params)
                layout{end + 1} = struct('kind', 'group_parent', 'label', item.label); %#ok<AGROW>
                for c = 1:numel(child_params)
                    layout{end + 1} = struct('kind', 'parameter', 'param_name', child_params{c}); %#ok<AGROW>
                end
            end
        end
    end
end


function layout = append_unlisted_adv_invest_layout_params(layout, eligible_params)
    % Append eligible parameters not covered by the fixed per-program layout.

    listed = collect_adv_invest_layout_param_names(layout);
    for i = 1:numel(eligible_params)
        param_name = eligible_params{i};
        if ~any(strcmp(param_name, listed))
            layout{end + 1} = struct('kind', 'parameter', 'param_name', param_name); %#ok<AGROW>
            listed{end + 1} = param_name; %#ok<AGROW>
        end
    end
end


function param_names = collect_adv_invest_layout_param_names(layout)
    % Collect parameter names referenced by a layout.

    param_names = {};
    for i = 1:numel(layout)
        entry = layout{i};
        if strcmp(entry.kind, 'parameter')
            param_names{end + 1} = entry.param_name; %#ok<AGROW>
        end
    end
end


function ordered_params = filter_adv_invest_params_in_order(preferred_order, all_params)
    % Return preferred parameter names that are present in all_params.

    ordered_params = {};
    for i = 1:numel(preferred_order)
        param_name = preferred_order{i};
        if any(strcmp(param_name, all_params))
            ordered_params{end + 1} = param_name; %#ok<AGROW>
        end
    end
end


function group_header = adv_invest_figure_group_header(param_name)
    % Group header text for nested parameters (aligned with sensitivity table).

    group_map = containers.Map();
    group_map('surge_cap_mrna') = 'Surge capacity (annual courses)';
    group_map('surge_cap_trad') = 'Surge capacity (annual courses)';
    group_map('k_m') = 'Capacity unit cost (per annual course)';
    group_map('k_o') = 'Capacity unit cost (per annual course)';
    group_map('rd_months_with_prototype') = 'Response R&D timeline';
    group_map('rd_months_no_prototype') = 'Response R&D timeline';

    if isKey(group_map, param_name)
        group_header = group_map(param_name);
    else
        group_header = '';
    end
end


function tf = adv_invest_figure_uses_platform_subtitle(param_name)
    % True when tick labels should read ``platform: value'' under a group header.

    platform_params = { ...
        'surge_cap_mrna', 'surge_cap_trad', 'k_m', 'k_o', ...
        'rd_months_with_prototype', 'rd_months_no_prototype' ...
    };
    tf = any(strcmp(param_name, platform_params));
end


function text_label = adv_invest_parameter_display_name(param_name, program_name)
    % Plain-text parameter label (aligned with write_adv_invest_sensitivity_table).

    param_map = containers.Map();
    param_map('surge_cap_mrna') = 'mRNA platform';
    param_map('surge_cap_trad') = 'Traditional platform';
    param_map('k_m') = 'mRNA platform';
    param_map('k_o') = 'Traditional platform';
    param_map('delta') = 'Annual maintenance cost';
    param_map('max_capacity') = 'Max. capacity (annual courses)';
    param_map('adv_cap_build_period') = 'Build period';
    param_map('capacity_kept') = 'Surge capacity kept after pandemic';
    param_map('epsilon') = 'Elasticity of surge capacity supply';
    param_map('theta') = 'Max. surge capacity displacement';
    param_map('tailoring_fraction') = 'Tailoring fraction';

    param_map('improved_ew_precision') = 'Precision';
    param_map('improved_ew_recall') = 'Sensitivity';
    param_map('ew_annual_cost') = 'Annual cost';
    param_map('months_to_early_detect') = 'Detection speedup';
    param_map('frac_invest_on_false') = 'Response cost on false alarm';
    param_map('include_unid_yearthreshonly') = 'Pathogen data';
    param_map('arrival_dist_config') = 'Severity ceiling';

    param_map('advance_RD_cost_per_pathogen') = 'R&D cost per pathogen';
    param_map('prototype_effect_ptrs') = 'Response R&D success prob. increase';
    param_map('prototype_success_prob') = 'R&D success prob.';
    param_map('rd_months_with_prototype') = 'With prototype';
    param_map('rd_months_no_prototype') = 'Without prototype';

    param_map('univ_flu_vax_eff_multiplier') = 'Efficacy multiplier';
    param_map('univ_flu_cost_multiplier') = 'R&D cost multiplier';
    param_map('initial_share_ufv') = 'Peacetime uptake';
    param_map('ufv_success_prob') = 'R&D success prob.';

    if isKey(param_map, param_name)
        text_label = param_map(param_name);
    elseif strcmp(param_name, 'advance_RD_benefit_start')
        if strcmp(program_name, 'universal_flu_vaccine')
            text_label = 'R&D lag';
        else
            text_label = 'R&D timeline';
        end
    elseif sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        text_label = sensitivity_table.common.format_severity_trunc_param_label(param_name);
    else
        text_label = strrep(param_name, '_', ' ');
    end
end


function label = format_program_name(program_name)
    % Format program names for display (same as table script).

    switch char(program_name)
        case 'advance_capacity'
            label = 'Advance capacity';
        case 'improved_early_warning'
            label = 'Improved early warning system';
        case 'prototype_rd'
            label = 'Prototype vaccine R&D';
        case 'universal_flu_vaccine'
            label = 'Universal flu vaccine';
        otherwise
            label = strrep(char(program_name), '_', ' ');
    end
end


function baseline_config = get_adv_invest_baseline_config(program_dir)
    % Baseline run configuration for chart perturbation labels.

    reference_path = fullfile(program_dir, 'processed', 'status_quo_benefits_summary.mat');
    reference_data = load(reference_path, 'run_config');
    baseline_config = reference_data.run_config;
end


function base_value = get_adv_invest_baseline_param_value(param_name, baseline_config)
    % Baseline display value for one sensitivity parameter.

    if strcmp(param_name, 'include_unid_yearthreshonly')
        base_value = 'baseline_sample';
    elseif sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        base_value = baseline_config.arrival_dist_config;
    else
        base_value = baseline_config.(param_name);
    end
end


function s = format_value_for_chart(value, param_name, baseline_config)
    % Format parameter values for chart labels (parallel to format_value_for_table).

    if nargin < 3
        baseline_config = [];
    end

    core_label = format_chart_value_without_direction(value, param_name, baseline_config);
    direction = get_chart_value_direction(value, param_name, baseline_config);
    if strlength(direction) > 0
        s = sprintf('%s to %s', direction, core_label);
    else
        s = core_label;
    end
end


function s = format_chart_value_without_direction(value, param_name, baseline_config)
    % Format a parameter value without an increase/reduce prefix.

    if nargin < 3
        baseline_config = [];
    end

    percentage_params = {'capacity_kept', 'theta', 'improved_ew_precision', ...
        'improved_ew_recall', 'frac_invest_on_false', 'prototype_success_prob', ...
        'ufv_success_prob', 'initial_share_ufv', 'delta', 'tailoring_fraction', ...
        'univ_flu_vax_eff_multiplier'};
    years_params = {'adv_cap_build_period', 'advance_RD_benefit_start'};
    months_params = {'months_to_regular_detect', ...
        'rd_months_with_prototype', 'rd_months_no_prototype'};
    currency_params = {'k_m', 'k_o', 'ew_annual_cost', 'advance_RD_cost_per_pathogen'};
    surge_capacity_params = {'surge_cap_mrna', 'surge_cap_trad'};
    capacity_params = {'max_capacity'};
    percentile_params = {'prototype_effect_ptrs', 'ptrs_pathogen'};

    if strcmp(param_name, 'include_unid_yearthreshonly')
        s = format_pathogen_data_scenario_label(value);
    elseif sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        s = format_severity_ceiling_value_only(value);
    elseif strcmp(param_name, 'months_to_early_detect')
        s = format_detection_speedup_chart_value(value, baseline_config);
    elseif any(strcmp(param_name, percentage_params))
        s = sprintf('%.0f%%', 100 * value);
    elseif any(strcmp(param_name, years_params))
        s = format_count_with_unit(round(value), 'year');
    elseif any(strcmp(param_name, months_params))
        s = format_count_with_unit(round(value), 'month');
    elseif any(strcmp(param_name, surge_capacity_params))
        s = format_annual_courses_billions_chart(value);
    elseif any(strcmp(param_name, capacity_params))
        s = sprintf('%.1f billion', value / 1e9);
    elseif any(strcmp(param_name, currency_params))
        s = format_currency_short_chart(value);
    elseif any(strcmp(param_name, percentile_params))
        s = format_percentile_label(value);
    elseif isnumeric(value) && isscalar(value)
        s = sprintf('%g', value);
    else
        s = char(string(value));
    end
end


function direction = get_chart_value_direction(value, param_name, baseline_config)
    % Return Increase, Reduce, or empty when value matches baseline.

    direction = '';
    if isempty(baseline_config)
        return;
    end
    if strcmp(param_name, 'include_unid_yearthreshonly')
        return;
    end
    if sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        u = sensitivity_table.common.parse_arrival_trunc_u(value);
        u_base = sensitivity_table.common.parse_arrival_trunc_u( ...
            get_adv_invest_baseline_param_value(param_name, baseline_config));
        if isnan(u) || isnan(u_base) || u == u_base
            return;
        end
        if u > u_base
            direction = 'Increase';
        else
            direction = 'Reduce';
        end
        return;
    end
    if is_chart_percentile_param(param_name)
        q = parse_percentile_from_path(value);
        q_base = parse_percentile_from_path( ...
            get_adv_invest_baseline_param_value(param_name, baseline_config));
        if q == q_base
            return;
        end
        if q > q_base
            direction = 'Increase';
        else
            direction = 'Reduce';
        end
        return;
    end
    if strcmp(param_name, 'months_to_early_detect')
        scenario_speedup = detection_speedup_months(value, baseline_config);
        baseline_speedup = detection_speedup_months( ...
            get_adv_invest_baseline_param_value(param_name, baseline_config), baseline_config);
        if scenario_speedup == baseline_speedup
            return;
        end
        if scenario_speedup > baseline_speedup
            direction = 'Increase';
        else
            direction = 'Reduce';
        end
        return;
    end
    if isnumeric(value) && isscalar(value)
        baseline_value = get_adv_invest_baseline_param_value(param_name, baseline_config);
        if ~isnumeric(baseline_value) || ~isscalar(baseline_value) || value == baseline_value
            return;
        end
        if value > baseline_value
            direction = 'Increase';
        else
            direction = 'Reduce';
        end
    end
end


function speedup = detection_speedup_months(months_to_early_detect, baseline_config)
    % Months saved when early warning detects an outbreak vs the regular timeline.

    months_to_regular_detect = baseline_config.months_to_regular_detect;
    speedup = months_to_regular_detect - months_to_early_detect;
end


function s = format_detection_speedup_chart_value(months_to_early_detect, baseline_config)
    % Format detection speedup as months relative to the regular detection timeline.

    speedup = detection_speedup_months(months_to_early_detect, baseline_config);
    s = format_count_with_unit(speedup, 'month');
end


function tf = is_chart_percentile_param(param_name)
    % True when sensitivity values are file paths with optional percentile tags.

    percentile_params = {'prototype_effect_ptrs', 'ptrs_pathogen'};
    tf = any(strcmp(param_name, percentile_params));
end


function q = parse_percentile_from_path(path_spec)
    % Parse a percentile tag from a prediction file path; default to 50 (mean).

    p = char(path_spec);
    [~, stem, ~] = fileparts(p);
    tok = regexp(lower(stem), '(?:^|[_-])q(\d{1,3})(?:$|[_-])', 'tokens', 'once');
    if isempty(tok)
        q = 50;
        return;
    end
    q = str2double(tok{1});
end


function s = format_severity_ceiling_value_only(path_spec)
    % Format a severity ceiling as deaths per 10,000 (no direction prefix).

    u = sensitivity_table.common.parse_arrival_trunc_u(path_spec);
    if isnan(u)
        s = 'Baseline';
        return;
    end
    deaths_label = format_deaths_per_ten_thousand(u);
    s = sprintf('%s deaths per 10,000', deaths_label);
end


function s = format_deaths_per_ten_thousand(u)
    % Format truncation u as deaths per 10,000 with thousands separators.

    u = round(u);
    if u == 1000
        s = '1,000';
    elseif u == 10000
        s = '10,000';
    elseif u == 100
        s = '100';
    else
        s = format_integer_with_commas(u);
    end
end


function s = format_integer_with_commas(n)
    % Insert thousands separators into a non-negative integer.

    n = round(n);
    s = sprintf('%.0f', n);
    if n < 1000
        return;
    end
    groups = {};
    while n >= 1000
        groups{end + 1} = sprintf('%03d', mod(n, 1000)); %#ok<AGROW>
        n = floor(n / 1000);
    end
    groups{end + 1} = sprintf('%.0f', n);
    groups = fliplr(groups);
    s = strjoin(groups, ',');
end


function s = format_pathogen_data_scenario_label(sample_id)
    % Pathogen-data scenario labels (aligned with write_unmitigated_loss_figures).

    v = char(sample_id);
    if contains(v, 'arrival_distributions') || contains(v, filesep)
        meta = parse_arrival_dist_fp(v);
        if meta.year_thresh_only
            s = 'All outbreaks since 1900';
            return;
        end
        if meta.incl_unid
            s = 'Novel + unidentified viral';
            return;
        end
        if strcmp(meta.scope, 'airborne')
            s = 'Airborne novel viral outbreaks';
            return;
        end
        if meta.year_min == 1950
            s = 'Novel viral since 1950';
            return;
        end
    end

    switch v
        case 'include_unid_yearthreshonly'
            s = 'All outbreaks since 1900';
        case 'baseline_sample'
            s = 'Primary sample';
        otherwise
            s = v;
    end
end


function s = format_percentile_label(value)
    % Format file-path sensitivities as percentile labels when possible.

    p = char(value);
    [~, stem, ~] = fileparts(p);
    tok = regexp(lower(stem), '(?:^|[_-])q(\d{1,3})(?:$|[_-])', 'tokens', 'once');
    if isempty(tok)
        s = 'Mean';
        return;
    end
    q = str2double(tok{1});
    s = sprintf('%d%s percentile', q, ordinal_suffix(q));
end


function suffix = ordinal_suffix(n)
    % Return ordinal suffix for an integer.

    n = round(n);
    last_two = mod(n, 100);
    if last_two >= 11 && last_two <= 13
        suffix = 'th';
        return;
    end
    switch mod(n, 10)
        case 1
            suffix = 'st';
        case 2
            suffix = 'nd';
        case 3
            suffix = 'rd';
        otherwise
            suffix = 'th';
    end
end


function s = format_annual_courses_billions_chart(value)
    % Format surge-capacity values as billions of annual courses (no dollar sign).

    s = sprintf('%.1f billion', value / 1e9);
end


function s = format_currency_short_chart(value)
    % Format currency values in chart labels (plain text).

    if abs(value) >= 1e9
        s = sprintf('$%.2f billion', value / 1e9);
    elseif abs(value) >= 1e6
        s = sprintf('$%.0f million', value / 1e6);
    else
        s = sprintf('$%.0f', value);
    end
end


function s = format_count_with_unit(count, unit_singular)
    % Format an integer count with a singular or plural unit name.

    count = round(count);
    if count == 1
        s = sprintf('1 %s', unit_singular);
    else
        s = sprintf('%d %ss', count, unit_singular);
    end
end


function apply_axis_style(ax, spec)
    % Apply consistent styling to horizontal bar axes.

    ax.FontName = char(spec.font_name);
    ax.FontSize = spec.typography.tick;
    ax.LineWidth = spec.stroke.reference;
    ax.Box = 'off';
    ax.XColor = [0.2 0.2 0.2];
    ax.YColor = [0.2 0.2 0.2];
    ax.XGrid = 'on';
    ax.YGrid = 'off';
    ax.GridColor = [0.4 0.4 0.4];
    ax.GridAlpha = 0.30;
    ax.TickDir = 'out';
end


function format_axis_ticks(ax)
    % Format x-axis tick labels without spurious decimals.

    xt = ax.XTick;
    ax.XTickLabel = arrayfun(@format_number_for_display, xt, 'UniformOutput', false);
end


function s = format_bar_npv_label(x)
    % Format NPV bar-end labels rounded to the nearest whole number.

    s = sprintf('%.0f', round(x));
end


function s = format_number_for_display(x)
    % Format numbers with no decimal for integers and one decimal otherwise.

    if abs(x - round(x)) < 1e-10
        s = sprintf('%.0f', x);
    else
        s = sprintf('%.1f', x);
    end
end
