function write_status_quo_sensitivity_table(sensitivity_dir)
    % Build the status-quo vaccine benefits sensitivity table and write CSV + LaTeX.
    %
    % Loads aggregated benefits from all sensitivity variants and computes mean vaccine
    % benefits for the baseline and each variant. Writes a summary table showing the
    % baseline value and the range across sensitivity runs.
    %
    % Args:
    %   sensitivity_dir  Path to sensitivity output directory containing
    %                    processed/status_quo_benefits_summary.mat and
    %                    sensitivity_config.yaml.

    sensitivity_dir = char(sensitivity_dir);
    sensitivity_config = yaml.loadFile(fullfile(sensitivity_dir, 'sensitivity_config.yaml'));

    baseline_results_path = fullfile(sensitivity_dir, 'processed', 'status_quo_benefits_summary.mat');
    baseline_data = load(baseline_results_path, 'status_quo_absolute_mean_net_value', 'run_config');
    baseline_benefits = baseline_data.status_quo_absolute_mean_net_value;
    baseline_config = baseline_data.run_config;

    param_names = fieldnames(sensitivity_config.sensitivities);
    table_layout = get_status_quo_table_layout(param_names);
    layout_param_names = collect_layout_parameter_names(table_layout);
    rows_by_param = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:numel(layout_param_names)
        param_name = layout_param_names{i};
        entry = sensitivity_config.sensitivities.(param_name);
        rows_by_param(param_name) = build_status_quo_sensitivity_row( ...
            param_name, entry, sensitivity_dir, baseline_config, baseline_benefits);
    end

    summary_rows = cell(numel(layout_param_names), 1);
    for i = 1:numel(layout_param_names)
        summary_rows{i} = rows_by_param(layout_param_names{i});
    end
    summary_table = sensitivity_rows_to_summary_table(summary_rows, baseline_benefits);
    writetable(summary_table, fullfile(sensitivity_dir, 'sensitivity_summary.csv'));

    generate_latex_table(table_layout, rows_by_param, ...
        fullfile(sensitivity_dir, 'sensitivity_summary.tex'), baseline_benefits, baseline_config);
    fprintf('Sensitivity summary generated and saved to %s\n', sensitivity_dir);
end


function row = build_status_quo_sensitivity_row(param_name, entry, sensitivity_dir, baseline_config, baseline_benefits)
    % Assemble one sensitivity row for CSV and LaTeX output.

    row = struct();
    row.param_name = param_name;
    row.baseline_value = get_baseline_display_scalar(param_name, baseline_config);
    row.baseline_benefits = baseline_benefits;

    if sensitivity_table.common.is_numeric_sensitivity_sweep(entry)
        row = append_numeric_sweep_row(row, param_name, sensitivity_dir, baseline_config);
    elseif sensitivity_table.common.is_alternative_spec_sensitivity(entry)
        row = append_alternative_spec_row(row, param_name, entry, sensitivity_dir, baseline_benefits);
    else
        error('Unsupported sensitivity entry for "%s".', param_name);
    end
end


function row = append_numeric_sweep_row(row, param_name, sensitivity_dir, baseline_config)
    % Fill row fields from value_1 and value_2 sensitivity runs.

    value_1_path = fullfile(sensitivity_dir, 'processed', sprintf('%s_value_1_benefits_summary.mat', param_name));
    value_2_path = fullfile(sensitivity_dir, 'processed', sprintf('%s_value_2_benefits_summary.mat', param_name));
    value_1_data = load(value_1_path, 'scenario_absolute_mean_net_value', 'run_config');
    value_2_data = load(value_2_path, 'scenario_absolute_mean_net_value', 'run_config');

    param_value_1 = value_1_data.run_config.(param_name);
    param_value_2 = value_2_data.run_config.(param_name);
    benefits_value_1 = value_1_data.scenario_absolute_mean_net_value;
    benefits_value_2 = value_2_data.scenario_absolute_mean_net_value;

    [row.low_value, row.high_value, row.low_benefits, row.high_benefits] = ...
        sensitivity_table.common.order_sensitivity_pair( ...
            param_value_1, benefits_value_1, param_value_2, benefits_value_2, param_name);

    row.reduced_value = row.low_value;
    row.increased_value = row.high_value;
    row.reduced_benefits = row.low_benefits;
    row.increased_benefits = row.high_benefits;
    row.is_single_alternative = false;
    row.baseline_value = get_baseline_display_scalar(param_name, baseline_config);
end


function row = append_alternative_spec_row(row, param_name, entry, sensitivity_dir, baseline_benefits)
    % Fill row fields from a single alternative-specification scenario.

    benefits_path = fullfile(sensitivity_dir, 'processed', sprintf('%s_benefits_summary.mat', param_name));
    alt_data = load(benefits_path, 'scenario_absolute_mean_net_value', 'run_config');
    alt_benefits = alt_data.scenario_absolute_mean_net_value;

    if strcmp(param_name, 'include_unid_yearthreshonly')
        row.is_pathogen_data_row = true;
        row.is_single_alternative = false;
        row.baseline_value = 'default';
        row.reduced_value = [];
        row.increased_value = 'all_1900_plus';
        row.low_value = NaN;
        row.high_value = NaN;
        row.low_benefits = baseline_benefits;
        row.high_benefits = alt_benefits;
        row.reduced_benefits = baseline_benefits;
        row.increased_benefits = alt_benefits;
        return;
    end

    row.low_value = NaN;
    row.high_value = NaN;
    row.low_benefits = alt_benefits;
    row.high_benefits = alt_benefits;
    row.reduced_value = get_alternative_display_value(param_name, entry, alt_data.run_config);
    row.increased_value = [];
    row.reduced_benefits = alt_benefits;
    row.increased_benefits = baseline_benefits;
    row.is_single_alternative = true;
end


function summary_table = sensitivity_rows_to_summary_table(rows, baseline_benefits)
    % Convert row structs into the CSV summary table.

    n = numel(rows) + 1;
    summary_table = table('Size', [n, 9], ...
        'VariableTypes', {'string', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
        'VariableNames', {'Parameter', 'BaselineValue', 'LowValue', 'HighValue', 'LowBenefit', 'HighBenefit', ...
        'LowBenefitPctDiff', 'HighBenefitPctDiff', 'MaxAbsPctDiff'});

    summary_table(1, :) = {'Status quo', NaN, NaN, NaN, baseline_benefits, baseline_benefits, 0, 0, 0};

    for i = 1:numel(rows)
        row = rows{i};
        low_pct = 100 * (row.low_benefits - baseline_benefits) / baseline_benefits;
        high_pct = 100 * (row.high_benefits - baseline_benefits) / baseline_benefits;
        baseline_scalar = row.baseline_value;
        if ~isnumeric(baseline_scalar) || ~isscalar(baseline_scalar)
            baseline_scalar = NaN;
        end
        low_scalar = row.low_value;
        if ~isnumeric(low_scalar) || ~isscalar(low_scalar)
            low_scalar = NaN;
        end
        high_scalar = row.high_value;
        if ~isnumeric(high_scalar) || ~isscalar(high_scalar)
            high_scalar = NaN;
        end
        summary_table(i + 1, :) = {row.param_name, baseline_scalar, low_scalar, high_scalar, ...
            row.low_benefits, row.high_benefits, low_pct, high_pct, max(abs([low_pct, high_pct]))};
    end
end


function generate_latex_table(table_layout, rows_by_param, output_path, baseline_benefits, baseline_config)
    % Write the LaTeX sensitivity table from layout entries and row structs.

    fileID = fopen(output_path, 'w');
    fprintf(fileID, '\\begin{table}[p]\n');
    fprintf(fileID, '\\addtocounter{table}{1}\n');
    fprintf(fileID, '\\centering\n');
    fprintf(fileID, ['\\caption{\n', ...
        '    \\textbf{Sensitivity of NPV estimates for status quo vaccine response to parameter changes.}  \n', ...
        '    Monetary figures in 2024 USD. \n', ...
        '    ``NPV'' is an abbreviation for net present discounted value,\n', ...
        '    ``yrs.'' for years, ``mo.'' for months, ``bil.'' for billions, ``mil.'' for millions, \n', ...
        '    ``probs.'' for probabilities, and ``pct.'' for percentile. \n', ...
        '    ``Successful at-risk capacity'' is the proportion dedicated to successful candidates that \n', ...
        '    can be produced immediately after approval. \n', ...
        '    ``Repurposable at-risk capacity'' is the proportion dedicated to unsuccessful candidates\n', ...
        '    that can be repurposed with a lag of $m^r_\\ell$ months. \n', ...
        '    For response R\\&D success probabilities, the baseline parameter values are the mean PTRS estimates for\n', ...
        '    each pathogen (Panel~(a), Figure~\\ref{fig:ptrs-plot}), while the reduced and \n', ...
        '    increased parameter values are the 25th and 75th percentile values generated by bootstrapping\n', ...
        '    from the fitted random-effects beta regression.}\n']);
    fprintf(fileID, '\\vspace{-0.35\\baselineskip}\n');
    fprintf(fileID, '\\footnotesize\n');
    fprintf(fileID, '\\begin{tabular*}{\\textwidth}{l @{\\extracolsep{\\fill}}cccccc}\n');
    fprintf(fileID, '\\toprule\n');
    fprintf(fileID, '& \\mc{2}{c}{Baseline parameter} & \\mc{2}{c}{Parameter reduction} & \\mc{2}{c}{Parameter increase} \\\\\n');
    fprintf(fileID, '\\cmidrule(lr){2-3} \\cmidrule(lr){4-5} \\cmidrule(lr){6-7}\n');
    fprintf(fileID, '& Baseline & NPV & Reduced & NPV & Increased & NPV \\\\\n');
    fprintf(fileID, '& parameter & estimate & parameter & estimate & parameter & estimate \\\\\n');
    fprintf(fileID, 'Parameter & value & (trillion \\$) & value & (trillion \\$) & value & (trillion \\$) \\\\\n');
    fprintf(fileID, '\\midrule\n');

    baseline_npv_trillion = baseline_benefits / 1e12;
    for i = 1:numel(table_layout)
        entry = table_layout{i};
        switch entry.kind
            case 'section'
                if i > 1
                    fprintf(fileID, '\\midrule\n');
                end
                fprintf(fileID, '%s \\\\\n', entry.label);
            case 'group_parent'
                fprintf(fileID, '\\hspace{0.6em} $\\bullet$ %s \\\\\n', entry.label);
            case 'parameter'
                row = rows_by_param(entry.param_name);
                write_status_quo_data_row(fileID, row, baseline_config, baseline_npv_trillion, entry.indent);
        end
    end

    fprintf(fileID, '\\bottomrule\n');
    fprintf(fileID, '\\end{tabular*}\n');
    fprintf(fileID, '\\label{tab:sensitivity_analysis}\n');
    fprintf(fileID, '\\end{table}\n');
    fclose(fileID);
end


function write_status_quo_data_row(fileID, row, baseline_config, baseline_npv_trillion, indent)
    % Write one bulleted or circled data row to the LaTeX table.

    param_label = format_parameter_label(row.param_name, indent);
    base_str = format_value(row.baseline_value, row.param_name, baseline_config);

    if isfield(row, 'is_pathogen_data_row') && row.is_pathogen_data_row
        reduced_str = '---';
        increased_str = format_value(row.increased_value, row.param_name, baseline_config);
        reduced_npv_str = '---';
        increased_npv_str = sprintf('%.1f', row.increased_benefits / 1e12);
    elseif row.is_single_alternative
        reduced_str = format_value(row.reduced_value, row.param_name, baseline_config);
        increased_str = '---';
        reduced_npv_str = sprintf('%.1f', row.reduced_benefits / 1e12);
        increased_npv_str = '---';
    else
        reduced_str = format_value(row.reduced_value, row.param_name, baseline_config);
        increased_str = format_value(row.increased_value, row.param_name, baseline_config);
        reduced_npv_str = sprintf('%.1f', row.reduced_benefits / 1e12);
        increased_npv_str = sprintf('%.1f', row.increased_benefits / 1e12);
    end

    fprintf(fileID, '%s & %s & %.1f & %s & %s & %s & %s \\\\\n', ...
        param_label, base_str, baseline_npv_trillion, reduced_str, reduced_npv_str, ...
        increased_str, increased_npv_str);
end


function layout = get_status_quo_table_layout(all_params)
    % Return ordered table layout entries (sections, groups, parameters).

    section_specs = { ...
        'General parameters', { ...
            'gamma', ...
            'arrival_dist_config', ...
            'include_unid_yearthreshonly' ...
        }; ...
        'Response parameters', { ...
            'months_to_regular_detect', ...
            'response_threshold_path' ...
        }; ...
        'Capacity parameters', { ...
            'max_capacity', ...
            struct('label', 'Surge capacity (annual courses)', 'children', {{'surge_cap_mrna', 'surge_cap_trad'}}), ...
            'capacity_kept', ...
            'beta', ...
            'epsilon', ...
            'delta', ...
            struct('label', 'Capacity cost (per annual course)', 'children', {{'k_m', 'k_o'}}), ...
            struct('label', 'Production unit cost (per course)', 'children', {{'c_m', 'c_o'}}), ...
            struct('label', 'Successful at-risk capacity', 'children', {{'f_m', 'f_o'}}), ...
            struct('label', 'Repurposable at-risk capacity', 'children', {{'g_m', 'g_o'}}), ...
            struct('label', 'Repurposing delay', 'children', {{'tau_m', 'tau_o'}}) ...
        }; ...
        'Response R\&D parameters', { ...
            'inp_RD_spend', ...
            'ptrs_pathogen', ...
            struct('label', 'Response R\&D timeline', 'children', {{'rd_months_with_prototype', 'rd_months_no_prototype'}}) ...
        } ...
    };

    layout = {};
    for s = 1:size(section_specs, 1)
        section_label = section_specs{s, 1};
        section_items = section_specs{s, 2};
        section_entries = {};
        for i = 1:numel(section_items)
            item = section_items{i};
            if ischar(item) || isstring(item)
                param_name = char(item);
                if any(strcmp(param_name, all_params))
                    section_entries{end + 1} = struct('kind', 'parameter', 'param_name', param_name, 'indent', 'bullet'); %#ok<AGROW>
                end
            elseif isstruct(item)
                child_params = filter_params_in_order(item.children, all_params);
                if ~isempty(child_params)
                    section_entries{end + 1} = struct('kind', 'group_parent', 'label', item.label); %#ok<AGROW>
                    for c = 1:numel(child_params)
                        section_entries{end + 1} = struct( ...
                            'kind', 'parameter', ...
                            'param_name', child_params{c}, ...
                            'indent', 'circle'); %#ok<AGROW>
                    end
                end
            end
        end
        if ~isempty(section_entries)
            layout{end + 1} = struct('kind', 'section', 'label', section_label); %#ok<AGROW>
            layout = [layout, section_entries]; %#ok<AGROW>
        end
    end

    layout = append_unlisted_parameters(layout, all_params);
end


function layout = append_unlisted_parameters(layout, all_params)
    % Append sensitivity parameters not covered by the fixed layout.

    excluded = status_quo_table_excluded_parameters();
    listed = collect_layout_parameter_names(layout);
    extras = {};
    for i = 1:numel(all_params)
        param_name = all_params{i};
        if any(strcmp(param_name, excluded))
            continue;
        end
        if ~any(strcmp(param_name, listed))
            extras{end + 1} = param_name; %#ok<AGROW>
        end
    end
    if isempty(extras)
        return;
    end
    layout{end + 1} = struct('kind', 'section', 'label', 'Other parameters');
    for i = 1:numel(extras)
        layout{end + 1} = struct('kind', 'parameter', 'param_name', extras{i}, 'indent', 'bullet'); %#ok<AGROW>
    end
end


function excluded = status_quo_table_excluded_parameters()
    % Sensitivity parameters omitted from the published status-quo table.

    excluded = { ...
        'ptrs_pathogen_gamma1' ...
    };
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


function ordered_params = pick_params_in_order(preferred_order, all_params)
    % Keep preferred names that exist in the config, then append any others.

    ordered_params = filter_params_in_order(preferred_order, all_params);
    for i = 1:numel(all_params)
        param_name = all_params{i};
        if ~any(strcmp(param_name, ordered_params))
            ordered_params{end + 1} = param_name; %#ok<AGROW>
        end
    end
end


function value = get_baseline_display_scalar(param_name, baseline_config)
    % Return a baseline display value, including for path-based overrides.

    switch param_name
        case 'arrival_dist_config'
            value = baseline_config.arrival_dist_config;
        case 'include_unid_yearthreshonly'
            value = 'default';
        case 'ptrs_pathogen_gamma1'
            value = baseline_config.gamma;
        otherwise
            if isfield(baseline_config, param_name)
                value = baseline_config.(param_name);
            else
                value = NaN;
            end
    end
end


function value = get_alternative_display_value(param_name, entry, run_config)
    % Return a display value for an alternative-specification scenario.

    switch param_name
        case 'include_unid_yearthreshonly'
            value = 'include_unid_yearthreshonly';
        case 'ptrs_pathogen_gamma1'
            value = run_config.gamma;
        otherwise
            if isfield(entry, 'arrival_dist_config')
                value = entry.arrival_dist_config;
            else
                fields = fieldnames(entry);
                if numel(fields) == 1
                    value = run_config.(fields{1});
                else
                    value = entry;
                end
            end
    end
end


function label = format_parameter_label(param_name, indent)
    % Format a parameter row label with bullet or circle indentation.

    param_map = containers.Map();
    param_map('arrival_dist_config') = 'Severity ceiling (deaths / 10k)';
    param_map('include_unid_yearthreshonly') = 'Pathogen data';
    param_map('value_of_death') = 'Value of statistical life';
    param_map('y') = 'GDP growth rate';
    param_map('r') = 'Social discount rate';
    param_map('gamma') = 'Harm mitigated by vaccine';
    param_map('capacity_kept') = 'Surge capacity kept after pandemic';
    param_map('surge_cap_mrna') = 'mRNA platform';
    param_map('surge_cap_trad') = 'Traditional platform';
    param_map('k_m') = 'mRNA platform';
    param_map('k_o') = 'Traditional platform';
    param_map('c_m') = 'mRNA platform';
    param_map('c_o') = 'Traditional platform';
    param_map('epsilon') = 'Elasticity of surge capacity supply';
    param_map('f_m') = 'mRNA platform';
    param_map('f_o') = 'Traditional platform';
    param_map('g_m') = 'mRNA platform';
    param_map('g_o') = 'Traditional platform';
    param_map('tau_m') = 'mRNA platform';
    param_map('tau_o') = 'Traditional platform';
    param_map('rental_share') = 'Advance capacity rental share';
    param_map('false_positive_rate') = 'False positive rate';
    param_map('max_capacity') = 'Max capacity (annual courses)';
    param_map('delta') = 'Annual capacity maintenance cost';
    param_map('response_threshold_path') = 'Response threshold (deaths / 10k)';
    param_map('ptrs_pathogen_gamma1') = 'Vaccines always succeed and $\gamma = 1$';
    param_map('ptrs_pathogen') = 'Response R\&D success probs.';
    param_map('inp_RD_spend') = 'Response R\&D spending';
    param_map('months_to_regular_detect') = 'Months to pandemic detection';
    param_map('beta') = 'Surge capacity cost kink';
    param_map('rd_months_with_prototype') = 'With prototype';
    param_map('rd_months_no_prototype') = 'Without prototype';

    if isKey(param_map, param_name)
        text_label = param_map(param_name);
    elseif sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        text_label = 'Severity ceiling (deaths / 10k)';
    else
        text_label = param_name;
    end

    switch indent
        case 'circle'
            label = sprintf('\\hspace{1.2em} $\\circ$ %s', text_label);
        otherwise
            label = sprintf('\\hspace{0.6em} $\\bullet$ %s', text_label);
    end
end


function formatted_value = format_value(value, param_name, ~) %#ok<INUSD>
    % Format parameter values for table cells.

    if isempty(value)
        formatted_value = '---';
        return;
    end

    if sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
        formatted_value = format_severity_ceiling_value(value);
        return;
    end
    if strcmp(param_name, 'include_unid_yearthreshonly')
        formatted_value = format_pathogen_data_label(value);
        return;
    end
    if strcmp(param_name, 'ptrs_pathogen_gamma1') && isnumeric(value) && isscalar(value)
        formatted_value = sprintf('%.0f\\%%', value * 100);
        return;
    end

    percentage_params = {'y', 'r', 'gamma', 'theta', 'f_m', 'f_o', 'g_m', 'g_o', ...
        'rental_share', 'capacity_kept', 'delta'};
    million_params = {'value_of_death'};
    currency_short_params = {'inp_RD_spend', 'beta'};
    surge_capacity_params = {'surge_cap_mrna', 'surge_cap_trad'};

    if any(strcmp(param_name, percentage_params))
        formatted_value = sprintf('%.0f\\%%', value * 100);
    elseif any(strcmp(param_name, surge_capacity_params))
        formatted_value = format_annual_courses_billions(value);
    elseif any(strcmp(param_name, million_params))
        formatted_value = sprintf('\\$%.1f mil.', value / 1e6);
    elseif any(strcmp(param_name, currency_short_params))
        formatted_value = format_currency_short(value);
    elseif contains(param_name, 'tau') || strcmp(param_name, 'months_to_regular_detect') || ...
            strcmp(param_name, 'rd_months_with_prototype') || strcmp(param_name, 'rd_months_no_prototype')
        formatted_value = sprintf('%.0f mo.', value);
    elseif startsWith(param_name, 'k_') || startsWith(param_name, 'c_')
        formatted_value = format_dollar_amount(value);
    elseif strcmp(param_name, 'max_capacity')
        formatted_value = sprintf('%.1f bil.', value / 1e9);
    elseif strcmp(param_name, 'response_threshold_path')
        formatted_value = format_response_threshold(value);
    elseif strcmp(param_name, 'ptrs_pathogen')
        formatted_value = format_ptrs_percentile(value);
    else
        formatted_value = sprintf('%g', value);
    end
end


function s = format_response_threshold(path_spec)
    % Format response-threshold path as threshold value (deaths / 10k).

    if isnumeric(path_spec) && isscalar(path_spec)
        s = sprintf('%.1f', path_spec);
        return;
    end

    p = char(path_spec);
    if exist(p, 'file')
        y = yaml.loadFile(p);
        if isfield(y, 'response_threshold')
            s = sprintf('%.1f', y.response_threshold);
            return;
        end
    end

    [~, stem, ~] = fileparts(p);
    if contains(stem, 'quarter')
        s = '3.1';
    elseif contains(stem, 'half')
        s = '6.1';
    elseif contains(stem, 'full')
        s = '12.3';
    else
        s = '6.1';
    end
end


function s = format_ptrs_percentile(path_spec)
    % Format PTRS path as percentile label (q25 -> 25th pct., default mean).

    p = char(path_spec);
    [~, stem, ~] = fileparts(p);
    tok = regexp(lower(stem), '(?:^|[_-])q(\d{1,3})(?:$|[_-])', 'tokens', 'once');
    if isempty(tok)
        s = 'Mean';
        return;
    end
    q = str2double(tok{1});
    s = sprintf('%d%s pct.', q, ordinal_suffix(q));
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


function s = format_currency_short(value)
    % Format currency values in short table units.

    if abs(value) >= 1e9
        s = sprintf('\\$%.2f bil.', value / 1e9);
    elseif abs(value) >= 1e6
        s = sprintf('\\$%.0f mil.', value / 1e6);
    else
        s = sprintf('\\$%.0f', value);
    end
end


function s = format_severity_ceiling_value(path_spec)
    % Format severity-ceiling sensitivity as a numeric truncation level.

    u = sensitivity_table.common.parse_arrival_trunc_u(path_spec);
    if isnan(u)
        s = '---';
        return;
    end
    s = sprintf('%d', u);
end


function s = format_annual_courses_billions(value)
    % Format annual-course capacity levels in billions without a currency symbol.

    s = sprintf('%.2f bil.', value / 1e9);
end


function s = format_dollar_amount(value)
    % Format a dollar amount, dropping unnecessary trailing zeros.

    if mod(value, 1) == 0
        s = sprintf('\\$%.0f', value);
        return;
    end
    amount_str = regexprep(sprintf('%.2f', value), '0+$', '');
    amount_str = regexprep(amount_str, '\.$', '');
    s = sprintf('\\$%s', amount_str);
end


function s = format_pathogen_data_label(sample_id)
    % Format pathogen-data sensitivity labels for the status-quo table.

    switch char(sample_id)
        case {'default', 'primary', 'baseline_sample'}
            s = 'Default';
        case {'all_1900_plus', 'all_since_1900', 'all_from_1900', 'include_unid_yearthreshonly'}
            s = 'All 1900+';
        otherwise
            s = strrep(char(sample_id), '_', ' ');
    end
end
