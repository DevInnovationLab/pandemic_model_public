function write_adv_invest_sensitivity_table(sensitivity_root_dir, outpath)
    % Write LaTeX sensitivity table grouped by advance investment program.
    %
    % Reads processed sensitivity summaries for each program under a top-level
    % program sensitivity run (for example, advance_investment_programs) and
    % writes one LaTeX table with program heading rows and indented parameter rows.
    %
    % Args:
    %   sensitivity_root_dir  Path to top-level sensitivity run directory containing
    %                         program_sensitivity_config.yaml and per-program folders.
    %   outpath               Optional output path for the .tex table file.
    %                         Defaults to sensitivity_root_dir/advance_investment_sensitivity_table.tex.

    if nargin < 2 || isempty(outpath)
        outpath = fullfile(sensitivity_root_dir, 'advance_investment_sensitivity_table.tex');
    end

    sensitivity_root_dir = char(sensitivity_root_dir);
    cfg = yaml.loadFile(fullfile(sensitivity_root_dir, 'program_sensitivity_config.yaml'));
    program_names = get_adv_invest_program_order(fieldnames(cfg.program_sensitivities));

    program_blocks = cell(1, numel(program_names));
    for p = 1:numel(program_names)
        program_name = program_names{p};
        program_dir = fullfile(sensitivity_root_dir, program_name);

        reference_path = fullfile(program_dir, 'processed', 'status_quo_benefits_summary.mat');
        reference_data = load(reference_path);
        baseline_config = get_required_loaded_field(reference_data, 'run_config', reference_path);
        reference_relative_mean = get_required_loaded_field( ...
            reference_data, 'reference_scenario_relative_mean_net_value', reference_path);
        reference_npv_billion = reference_relative_mean / 1e9;

        program_cfg = yaml.loadFile(fullfile(program_dir, 'sensitivity_config.yaml'));
        param_names = fieldnames(program_cfg.sensitivities);
        eligible_params = filter_eligible_sensitivity_params(program_cfg, param_names, program_name);
        table_layout = get_adv_invest_program_layout(program_name, eligible_params);

        program_blocks{p} = struct( ...
            'program_name', program_name, ...
            'program_label', format_program_name(program_name), ...
            'program_dir', program_dir, ...
            'baseline_config', baseline_config, ...
            'reference_npv_billion', reference_npv_billion, ...
            'program_cfg', program_cfg, ...
            'table_layout', {table_layout});
    end

    write_adv_invest_latex_table(program_blocks, outpath);
    fprintf('Wrote advance investment sensitivity table to %s\n', outpath);
end


function write_adv_invest_latex_table(program_blocks, outpath)
    % Write the full advance-investment sensitivity LaTeX table.

    fid = fopen(outpath, 'w');
    fprintf(fid, '\\begin{table}[p]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, ['\\caption{\n', ...
        '    \\textbf{Sensitivity of advance investment program net present value estimates.} \n', ...
        '    Monetary figures in 2024 USD. \n', ...
        '    ``NPV'''' is an abbreviation for net present discounted value,\n', ...
        '    ``yrs.'''' for years, ``mo.'''' for months, ``bil.'''' for billions, ``mil.'''' for millions, \n', ...
        '    ``prob.'''' for probability, and ``pct.'''' for percentile.\n', ...
        '    NPV estimates represent the estimated mean difference in discounted net surplus generated\n', ...
        '    by the advance investment and the status quo programs under the same parameter \n', ...
        '    configuration across one million simulations. For ``Response R\\&D success prob. increase'''', \n', ...
        '    the baseline parameter value is the mean estimated increase in the probability of technical\n', ...
        '    and regulatory success attributable to prototype availability as described by in \n', ...
        '    Equation~\\ref{eq:vaccine-ptrs-delta}. The reduced and increased parameter values are \n', ...
        '    the 25th and 75th percentiles of the confidence interval distribution. Parameters labeled ``R\\&D''''\n', ...
        '    are specific to the program indicated in the panel.}\n']);
    fprintf(fid, '\\vspace{-0.35\\baselineskip}\n');
    fprintf(fid, '\\footnotesize\n');
    fprintf(fid, '\\begin{tabular*}{\\textwidth}{l @ {\\extracolsep{\\fill}} c c c c c c}\n');
    fprintf(fid, '\\toprule\n');
    fprintf(fid, '& \\multicolumn{2}{c}{Baseline parameter} & \\multicolumn{2}{c}{Parameter reduction} & \\multicolumn{2}{c}{Parameter increase} \\\\\n');
    fprintf(fid, '\\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7}\n');
    fprintf(fid, '& Baseline & NPV & Reduced & NPV & Increased & NPV \\\\\n');
    fprintf(fid, '& parameter & estimate & parameter & estimate & parameter & estimate \\\\\n');
    fprintf(fid, 'Parameter name & value & (billion \\$) & value & (billion \\$) & value & (billion \\$) \\\\\n');
    fprintf(fid, '\\midrule\n');

    for p = 1:numel(program_blocks)
        block = program_blocks{p};
        if p > 1
            fprintf(fid, '\\midrule\n');
        end
        fprintf(fid, '%s \\\\\n', block.program_label);

        for i = 1:numel(block.table_layout)
            entry = block.table_layout{i};
            switch entry.kind
                case 'group_parent'
                    fprintf(fid, '\\hspace{0.6em} $\\bullet$ %s & & & & & & \\\\\n', entry.label);
                case 'parameter'
                    param_name = entry.param_name;
                    param_entry = block.program_cfg.sensitivities.(param_name);
                    write_adv_invest_data_row(fid, param_name, param_entry, block.program_dir, ...
                        block.baseline_config, block.reference_npv_billion, block.program_name, entry.indent);
            end
        end
    end

    fprintf(fid, '\\bottomrule\n');
    fprintf(fid, '\\end{tabular*}\n');
    fprintf(fid, '\\label{tab:adv_invest_sensitivity}\n');
    fprintf(fid, '\\end{table}\n');
    fclose(fid);
end


function eligible_params = filter_eligible_sensitivity_params(program_cfg, param_names, program_name)
    % Return parameter names that have table-eligible sensitivity entries.

    excluded = adv_invest_table_excluded_parameters(program_name);
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


function excluded = adv_invest_table_excluded_parameters(program_name)
    % Sensitivity parameters omitted from the published advance-investment table.

    excluded = { ...
        'arrival_dist_config', ...
        'include_unid_yearthreshonly' ...
    };
    if nargin >= 1 && strcmp(program_name, 'advance_capacity')
        excluded{end + 1} = 'delta'; %#ok<AGROW>
    end
end


function layout = get_adv_invest_program_layout(program_name, eligible_params)
    % Return ordered table layout entries for one advance-investment program.

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
        struct('label', 'Response R\&D timeline', 'children', {{'rd_months_with_prototype', 'rd_months_no_prototype'}}) ...
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
        struct('label', 'System performance', 'children', {{ ...
            'improved_ew_precision', ...
            'improved_ew_recall', ...
            'months_to_early_detect' ...
        }}), ...
        'frac_invest_on_false', ...
        'capacity_kept' ...
    };

    layout = {};
    if isKey(program_specs, program_name)
        layout = build_layout_from_specs(program_specs(program_name), eligible_params);
    end
    layout = append_unlisted_adv_invest_parameters(layout, eligible_params);
end


function layout = build_layout_from_specs(spec_items, eligible_params)
    % Expand program layout specs into layout entry structs.

    layout = {};
    for i = 1:numel(spec_items)
        item = spec_items{i};
        if ischar(item) || isstring(item)
            param_name = char(item);
            if any(strcmp(param_name, eligible_params))
                layout{end + 1} = struct('kind', 'parameter', 'param_name', param_name, 'indent', 'bullet'); %#ok<AGROW>
            end
        elseif isstruct(item)
            child_params = filter_params_in_order(item.children, eligible_params);
            if ~isempty(child_params)
                layout{end + 1} = struct('kind', 'group_parent', 'label', item.label); %#ok<AGROW>
                for c = 1:numel(child_params)
                    layout{end + 1} = struct( ...
                        'kind', 'parameter', ...
                        'param_name', child_params{c}, ...
                        'indent', 'circle'); %#ok<AGROW>
                end
            end
        end
    end
end


function layout = append_unlisted_adv_invest_parameters(layout, eligible_params)
    % Append eligible parameters not covered by the fixed per-program layout.

    listed = collect_layout_parameter_names(layout);
    for i = 1:numel(eligible_params)
        param_name = eligible_params{i};
        if ~any(strcmp(param_name, listed))
            layout{end + 1} = struct('kind', 'parameter', 'param_name', param_name, 'indent', 'bullet'); %#ok<AGROW>
            listed{end + 1} = param_name; %#ok<AGROW>
        end
    end
end


function param_names = collect_layout_parameter_names(layout)
    % Collect parameter names referenced by a table layout.

    param_names = {};
    for i = 1:numel(layout)
        entry = layout{i};
        if strcmp(entry.kind, 'parameter')
            param_names{end + 1} = entry.param_name; %#ok<AGROW>
        end
    end
end


function ordered_params = filter_params_in_order(preferred_order, all_params)
    % Return preferred parameter names that are present in all_params.

    ordered_params = {};
    for i = 1:numel(preferred_order)
        param_name = preferred_order{i};
        if any(strcmp(param_name, all_params))
            ordered_params{end + 1} = param_name; %#ok<AGROW>
        end
    end
end


function ordered_programs = get_adv_invest_program_order(all_programs)
    % Return advance investment programs in a fixed display order.

    preferred_order = { ...
        'advance_capacity', ...
        'prototype_rd', ...
        'universal_flu_vaccine', ...
        'improved_early_warning' ...
    };

    ordered_programs = {};
    for i = 1:numel(preferred_order)
        program_name = preferred_order{i};
        if any(strcmp(program_name, all_programs))
            ordered_programs{end + 1} = program_name; %#ok<AGROW>
        end
    end

    for i = 1:numel(all_programs)
        program_name = all_programs{i};
        if ~any(strcmp(program_name, ordered_programs))
            ordered_programs{end + 1} = program_name; %#ok<AGROW>
        end
    end
end


function value = get_required_loaded_field(loaded_struct, field_name, source_path)
    % Return a loaded struct field or raise a clear error when absent.

    if ~isfield(loaded_struct, field_name)
        error('Missing required field "%s" in %s.', field_name, source_path);
    end
    value = loaded_struct.(field_name);
end


function write_adv_invest_data_row(fid, param_name, param_entry, program_dir, ...
    baseline_config, reference_npv_billion, program_name, indent)
    % Write one parameter data row for an advance-investment program block.

    param_label = format_adv_invest_parameter_label(param_name, indent, program_name);
    base_value = get_adv_invest_baseline_value(param_name, baseline_config);
    reference_npv_str = format_npv_for_table(reference_npv_billion);

    if sensitivity_table.common.is_numeric_sensitivity_sweep(param_entry)
        [reduced_value, increased_value, reduced_npv, increased_npv, is_single_alternative] = ...
            load_adv_invest_numeric_sweep(program_dir, param_name);
    else
        [reduced_value, increased_value, reduced_npv, increased_npv, is_single_alternative] = ...
            load_adv_invest_alternative_spec(program_dir, param_name, param_entry, reference_npv_billion);
    end

    baseline_value_str = format_value_for_table(base_value, param_name, baseline_config);
    reduced_value_str = format_value_for_table(reduced_value, param_name, baseline_config);
    if is_single_alternative
        increased_value_str = '---';
        increased_npv_str = '---';
    else
        increased_value_str = format_value_for_table(increased_value, param_name, baseline_config);
        increased_npv_str = format_npv_for_table(increased_npv);
    end
    reduced_npv_str = format_npv_for_table(reduced_npv);

    fprintf(fid, '%s & %s & %s & %s & %s & %s & %s \\\\\n', ...
        param_label, baseline_value_str, reference_npv_str, ...
        reduced_value_str, reduced_npv_str, increased_value_str, increased_npv_str);
end


function s = format_npv_for_table(value_billion)
    % Format NPV entries as rounded billions with thousands separators.

    s = add_thousands_separators(sprintf('%.0f', value_billion));
end


function base_value = get_adv_invest_baseline_value(param_name, baseline_config)
    % Baseline display value for one sensitivity parameter.

    if strcmp(param_name, 'include_unid_yearthreshonly')
        base_value = 'baseline_sample';
    elseif sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        base_value = baseline_config.arrival_dist_config;
    else
        base_value = baseline_config.(param_name);
    end
end


function [reduced_value, increased_value, reduced_npv, increased_npv, is_single_alternative] = ...
    load_adv_invest_numeric_sweep(program_dir, param_name)

    value_1_path = fullfile(program_dir, 'processed', sprintf('%s_value_1_benefits_summary.mat', param_name));
    value_2_path = fullfile(program_dir, 'processed', sprintf('%s_value_2_benefits_summary.mat', param_name));
    value_1_data = load(value_1_path);
    value_2_data = load(value_2_path);

    run_config_1 = get_required_loaded_field(value_1_data, 'run_config', value_1_path);
    run_config_2 = get_required_loaded_field(value_2_data, 'run_config', value_2_path);
    value_1 = run_config_1.(param_name);
    value_2 = run_config_2.(param_name);
    relative_mean_1 = get_required_loaded_field(value_1_data, 'scenario_relative_mean_net_value', value_1_path);
    relative_mean_2 = get_required_loaded_field(value_2_data, 'scenario_relative_mean_net_value', value_2_path);
    npv_1 = relative_mean_1 / 1e9;
    npv_2 = relative_mean_2 / 1e9;

    [reduced_value, increased_value, reduced_npv, increased_npv] = ...
        sensitivity_table.common.order_sensitivity_pair(value_1, npv_1, value_2, npv_2, param_name);
    is_single_alternative = false;
end


function [reduced_value, increased_value, reduced_npv, increased_npv, is_single_alternative] = ...
    load_adv_invest_alternative_spec(program_dir, param_name, param_entry, reference_npv_billion)

    benefits_path = fullfile(program_dir, 'processed', sprintf('%s_benefits_summary.mat', param_name));
    alt_data = load(benefits_path);
    run_config = get_required_loaded_field(alt_data, 'run_config', benefits_path);
    relative_mean = get_required_loaded_field(alt_data, 'scenario_relative_mean_net_value', benefits_path);
    alt_npv = relative_mean / 1e9;

    reduced_value = get_adv_invest_alternative_display_value(param_name, param_entry, run_config);
    increased_value = [];
    reduced_npv = alt_npv;
    increased_npv = reference_npv_billion;
    is_single_alternative = true;
end


function value = get_adv_invest_alternative_display_value(param_name, param_entry, run_config)
    % Display value for a single-scenario alternative specification.

    if strcmp(param_name, 'include_unid_yearthreshonly')
        value = 'include_unid_yearthreshonly';
    elseif isfield(param_entry, 'arrival_dist_config')
        value = param_entry.arrival_dist_config;
    else
        fields = fieldnames(param_entry);
        value = run_config.(fields{1});
    end
end


function label = format_program_name(program_name)
    % Format program names for table display.

    switch char(program_name)
        case 'advance_capacity'
            label = 'Advance capacity';
        case 'improved_early_warning'
            label = 'Improved early warning system';
        case 'prototype_rd'
            label = 'Prototype vaccine R\&D';
        case 'universal_flu_vaccine'
            label = 'Universal flu vaccine';
        otherwise
            label = strrep(char(program_name), '_', ' ');
    end
end


function label = format_adv_invest_parameter_label(param_name, indent, program_name)
    % Format a parameter row label with bullet or circle indentation.

    text_label = adv_invest_parameter_display_name(param_name, program_name);
    switch indent
        case 'circle'
            label = sprintf('\\hspace{1.2em} $\\circ$ %s', text_label);
        otherwise
            label = sprintf('\\hspace{0.6em} $\\bullet$ %s', text_label);
    end
end


function text_label = adv_invest_parameter_display_name(param_name, program_name)
    % Plain-text parameter label for one advance-investment program row.

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

    param_map('advance_RD_cost_per_pathogen') = 'R\&D cost per pathogen';
    param_map('prototype_effect_ptrs') = 'Response R\&D success prob. increase';
    param_map('prototype_success_prob') = 'R\&D success prob.';
    param_map('rd_months_with_prototype') = 'With prototype';
    param_map('rd_months_no_prototype') = 'Without prototype';

    param_map('univ_flu_vax_eff_multiplier') = 'Efficacy multiplier';
    param_map('univ_flu_cost_multiplier') = 'R\&D cost multiplier';
    param_map('initial_share_ufv') = 'Peacetime uptake';
    param_map('ufv_success_prob') = 'R\&D success prob.';

    if isKey(param_map, param_name)
        text_label = param_map(param_name);
    elseif strcmp(param_name, 'advance_RD_benefit_start')
        if strcmp(program_name, 'universal_flu_vaccine')
            text_label = 'R\&D lag';
        else
            text_label = 'R\&D timeline';
        end
    elseif sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        text_label = sensitivity_table.common.format_severity_trunc_param_label(param_name);
    else
        text_label = strrep(param_name, '_', ' ');
    end
end


function s = format_value_for_table(value, param_name, baseline_config)
    % Format parameter values using simple, parameter-aware display rules.

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
        s = sensitivity_table.common.format_epidemic_sample_label(value);
    elseif sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        s = sensitivity_table.common.format_arrival_severity_trunc(value);
    elseif strcmp(param_name, 'months_to_early_detect')
        s = format_detection_speedup_for_table(value, baseline_config);
    elseif any(strcmp(param_name, percentage_params))
        s = sprintf('%.0f\\%%', 100 * value);
    elseif any(strcmp(param_name, years_params))
        s = sprintf('%.0f yrs.', value);
    elseif any(strcmp(param_name, months_params))
        s = sprintf('%.0f mo.', value);
    elseif any(strcmp(param_name, surge_capacity_params))
        s = format_annual_courses_billions(value);
    elseif any(strcmp(param_name, capacity_params))
        s = sprintf('%.1f bil.', value / 1e9);
    elseif any(strcmp(param_name, currency_params))
        s = format_currency(value);
    elseif any(strcmp(param_name, percentile_params))
        s = format_percentile_value_for_table(value);
    elseif isnumeric(value) && isscalar(value)
        s = sprintf('%g', value);
    else
        s = escape_latex(char(string(value)));
    end
end


function speedup = detection_speedup_months(months_to_early_detect, baseline_config)
    % Months saved when early warning detects an outbreak vs the regular timeline.

    months_to_regular_detect = baseline_config.months_to_regular_detect;
    speedup = months_to_regular_detect - months_to_early_detect;
end


function s = format_detection_speedup_for_table(months_to_early_detect, baseline_config)
    % Format detection speedup as months relative to the regular detection timeline.

    speedup = detection_speedup_months(months_to_early_detect, baseline_config);
    s = sprintf('%.0f mo.', speedup);
end


function s = format_annual_courses_billions(value)
    % Format surge-capacity values as billions of annual courses.

    s = sprintf('%.1f bil.', value / 1e9);
end


function s = format_percentile_value_for_table(value)
    % Format string-like values, parsing percentile tags when present.

    value_char = char(value);
    [~, stem, ~] = fileparts(value_char);

    stem_lower = lower(char(string(stem)));
    token = regexp(stem_lower, '(?:^|[_-])q(\d{1,3})(?:$|[_-])', 'tokens', 'once');
    if isempty(token)
        s = 'Mean';
    else
        percentile = str2double(token{1});
        s = sprintf('%d%s pct.', round(percentile), ordinal_suffix(percentile));
    end
end


function suffix = ordinal_suffix(n)
    % Return ordinal suffix for integer n (for example 1 -> st).

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


function s = format_currency(value)
    % Format currency values in billions, millions, or dollars.

    if abs(value) >= 1e9
        s = sprintf('\\$%s bil.', format_compact_decimal(value / 1e9));
    elseif abs(value) >= 1e6
        s = sprintf('\\$%s mil.', format_compact_decimal(value / 1e6));
    else
        if mod(value, 1) == 0
            s = sprintf('\\$%.0f', value);
        else
            s = sprintf('\\$%s', format_compact_decimal(value));
        end
    end
end


function s = format_compact_decimal(value)
    % Format numeric values without scientific notation for table display.

    abs_value = abs(value);
    if abs_value >= 100
        s = sprintf('%.0f', value);
    elseif abs_value >= 10
        s = sprintf('%.1f', value);
    else
        s = sprintf('%.2f', value);
    end

    if contains(s, '.')
        s = regexprep(s, '0+$', '');
        s = regexprep(s, '\.$', '');
    end
    s = add_thousands_separators(s);
end


function s_out = add_thousands_separators(s_in)
    % Insert commas every three digits to the left of decimal point.

    s_in = char(string(s_in));
    if startsWith(s_in, '-')
        sign_prefix = '-';
        unsigned = s_in(2:end);
    else
        sign_prefix = '';
        unsigned = s_in;
    end

    decimal_pos = strfind(unsigned, '.');
    if isempty(decimal_pos)
        integer_part = unsigned;
        fractional_part = '';
    else
        integer_part = unsigned(1:decimal_pos(1)-1);
        fractional_part = unsigned(decimal_pos(1):end);
    end

    integer_len = length(integer_part);
    if integer_len > 3
        first_group_len = mod(integer_len, 3);
        if first_group_len == 0
            first_group_len = 3;
        end

        grouped = integer_part(1:first_group_len);
        idx = first_group_len + 1;
        while idx <= integer_len
            grouped = [grouped, ',', integer_part(idx:idx + 2)]; %#ok<AGROW>
            idx = idx + 3;
        end
        integer_part = grouped;
    end

    s_out = [sign_prefix, integer_part, fractional_part];
end


function s = escape_latex(text_in)
    % Escape LaTeX special characters in plain text.

    s = char(string(text_in));
    s = strrep(s, '&', '\&');
    s = strrep(s, '_', '\_');
    s = strrep(s, '%', '\%');
    s = strrep(s, '#', '\#');
end
