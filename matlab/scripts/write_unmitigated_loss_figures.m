function write_unmitigated_loss_figures(sensitivity_dir, annualized_summary_table, total_summary_table)
    % Builds tables (if needed), writes LaTeX tables, and writes both stacked bar figures.
    %
    % Args:
    %   sensitivity_dir (char or string): Path to sensitivity run directory.
    %   annualized_summary_table (table): Optional. If omitted, calls build_sensitivity_loss_tables first.
    %   total_summary_table (table): Optional. If either table is omitted, both are built.
    %
    % Saves:
    %   sensitivity_dir/sensitivity_annualized_loss_summary.tex
    %   sensitivity_dir/sensitivity_total_loss_summary.tex
    %   sensitivity_dir/figures/sensitivity_stacked_losses.png (annualized)
    %   sensitivity_dir/figures/sensitivity_total_stacked_losses.png (total)

    sensitivity_dir = char(sensitivity_dir);
    if nargin < 3
        [annualized_summary_table, total_summary_table] = build_sensitivity_loss_tables(sensitivity_dir);
    end

    write_to_latex(annualized_summary_table, fullfile(sensitivity_dir, "sensitivity_annualized_loss_summary.tex"));
    write_to_latex(total_summary_table, fullfile(sensitivity_dir, "sensitivity_total_loss_summary.tex"));

    fig_dir = fullfile(sensitivity_dir, 'figures');
    if ~isfolder(fig_dir)
        mkdir(fig_dir);
    end

    plot_annualized_and_deaths_panel(annualized_summary_table, fig_dir);
end

function plot_annualized_and_deaths_panel(summary_table, fig_dir)
    % Two-panel figure: top = expected annualized pandemic losses (stacked), bottom = expected annual deaths.
    n = height(summary_table);
    mortality = zeros(n, 1);
    economic  = zeros(n, 1);
    learning  = zeros(n, 1);
    annual_deaths = zeros(n, 1);
    for i = 1:n
        mortality(i) = summary_table{i, 4}{1}.mean;
        economic(i)  = summary_table{i, 5}{1}.mean;
        learning(i)  = summary_table{i, 6}{1}.mean;
        % Annual deaths: stored mean is mean(sample)/1e12; display in millions = .mean * 1e6
        annual_deaths(i) = summary_table{i, 3}{1}.mean * 1e6;
    end
    loss_data = [mortality, economic, learning];

    [loss_data_ordered, labels, order_idx, group_names] = order_rows_and_labels(summary_table, loss_data);
    deaths_ordered = annual_deaths(order_idx);

    % Use blue for mortality, red for economic, green for learning
    colors = [0.2 0.4 0.8;    % nice blue for mortality
              0.85 0.33 0.1;  % pleasant red for economic
              0.25 0.65 0.32];% nice green for learning
    nrows = size(loss_data_ordered, 1);

    % Combined two-panel figure (for reference)
    % Figure: social losses only
    fig_loss = figure('Visible', 'off', 'Position', [100 100 780 640]);
    fig_loss.PaperPositionMode = 'auto';
    ax_loss = axes(fig_loss);
    % Grouped y-axis layout with group headers and spacing
    [y_bar_loss, y_ticks_loss, y_ticklabels_loss, header_y_loss, header_labels_loss] = ...
        grouped_y_layout(group_names, labels);
    b_loss = barh(ax_loss, y_bar_loss, loss_data_ordered, 'stacked', 'FaceColor', 'flat');
    for k = 1:3
        b_loss(k).CData = repmat(colors(k,:), nrows, 1);
    end
    ax_loss.YDir = 'reverse';
    ax_loss.YTick = y_ticks_loss;
    ax_loss.YTickLabel = y_ticklabels_loss;
    ax_loss.TickLabelInterpreter = 'tex';

    apply_axis_style(ax_loss);
    draw_group_headers(ax_loss, header_y_loss, header_labels_loss);
    xlabel(ax_loss, 'Expected annualized social loss (trillion $)', 'FontName', 'Arial', ...
        'FontSize', 13, 'Interpreter', 'tex', 'Color', [0.2 0.2 0.2]);
    legend(ax_loss, {'Mortality', 'Economic', 'Learning'}, 'Location', 'southeast', ...
        'Orientation', 'vertical', 'FontName', 'Arial', 'FontSize', 12, ...
        'Interpreter', 'tex', 'TextColor', [0.2 0.2 0.2]);
    set(ax_loss, 'Layer', 'bottom');
    format_axis_ticks(ax_loss);

    % Bar totals at bar ends
    total_loss = sum(loss_data_ordered, 2);
    for i = 1:nrows
        x_val = total_loss(i);
        y_val = y_bar_loss(i);
        text(ax_loss, x_val + 0.3, y_val, format_number_for_display(x_val), ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'FontName', 'Arial', 'FontSize', 10, 'Interpreter', 'tex', 'Color', [0.2 0.2 0.2]);
    end
    % Save axis limits to match styling on second panel
    xlims_loss = [0, ceil(max(total_loss)) + 1];
    xlim(ax_loss, xlims_loss);

    outpath_loss = fullfile(fig_dir, 'sensitivity_stacked_losses_social.pdf');
    exportgraphics(fig_loss, outpath_loss, ...
        'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
    close(fig_loss);
    fprintf('Social loss panel saved to %s\n', outpath_loss);

    % Figure: annual deaths only
    fig_deaths = figure('Visible', 'off', 'Position', [100 100 780 640]);
    fig_deaths.PaperPositionMode = 'auto';
    ax_deaths = axes(fig_deaths);
    % Reuse grouped y-axis layout for deaths
    [y_bar_deaths, y_ticks_deaths, y_ticklabels_deaths, header_y_deaths, header_labels_deaths] = ...
        grouped_y_layout(group_names, labels);

    % Match the coloring style -> we manually color each bar like the first panel
    h_bar = barh(ax_deaths, y_bar_deaths, deaths_ordered, 'FaceColor', 'flat');
    % For single bar vector, apply "mortality" color from colors
    if ~isempty(h_bar)
        h_bar.CData = repmat(colors(1,:), nrows, 1);
    end

    ax_deaths.YDir = 'reverse';
    ax_deaths.YTick = y_ticks_deaths;
    ax_deaths.YTickLabel = y_ticklabels_deaths;
    ax_deaths.TickLabelInterpreter = 'tex';
    apply_axis_style(ax_deaths);
    draw_group_headers(ax_deaths, header_y_deaths, header_labels_deaths, 0.2);
    xlabel(ax_deaths, 'Expected annual deaths (millions)', 'FontName', 'Arial', ...
        'FontSize', 13, 'Interpreter', 'tex', 'Color', [0.2 0.2 0.2]);
    set(ax_deaths, 'Layer', 'bottom');
    format_axis_ticks(ax_deaths);

    % Bar totals at bar ends (annual deaths)
    for i = 1:nrows
        x_val = deaths_ordered(i);
        y_val = y_bar_deaths(i);
        text(ax_deaths, x_val + 0.1, y_val, format_number_for_display(x_val), ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'FontName', 'Arial', 'FontSize', 10, 'Interpreter', 'tex', 'Color', [0.2 0.2 0.2]);
    end

    % Match xlim style to first panel for visual consistency
    xlims_deaths = [0, ceil(max(deaths_ordered)) + 1];
    xlim(ax_deaths, xlims_deaths);

    outpath_deaths = fullfile(fig_dir, 'sensitivity_stacked_losses_deaths.pdf');
    exportgraphics(fig_deaths, outpath_deaths, ...
        'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
    close(fig_deaths);
    fprintf('Annual deaths panel saved to %s\n', outpath_deaths);
end

function [data_ordered, labels, order_idx, group_names] = order_rows_and_labels(summary_table, data)
    % Order rows into canonical groups and within-group ordering used in both
    % tables and figures. Uses the formatted Variable names coming from
    % build_sensitivity_loss_tables so headings/ordering are driven
    % entirely by those upstream labels.

    % Desired group ordering using the formatted names (must match build_sensitivity_loss_tables)
    groupOrder = [
        "Baseline"
        "Severity ceiling ($\overline{s}$)"
        "Severity floor ($\underline{x}$)"
        "Per capita GDP growth rate ($r_g$)"
        "Value of statistical life ($v$)"
        "Social discount rate ($r_s$)"
        "Pathogen data"
    ];

    order_idx = [];
    for g = 1:length(groupOrder)
        thisGroup = groupOrder(g);
        % Rows whose formatted Variable name matches this group exactly
        inGroup = find(summary_table.Variable == thisGroup);
        if isempty(inGroup)
            continue;
        end

        % Custom within-group ordering for pathogen data
        if thisGroup == "Pathogen data"
            scores = zeros(numel(inGroup), 1);
            for j = 1:numel(inGroup)
                scores(j) = pathogen_row_score(summary_table.Value(inGroup(j)));
            end
            [~, ordWithin] = sort(scores);
            inGroup = inGroup(ordWithin);
        end

        order_idx = [order_idx; inGroup(:)]; %#ok<AGROW>
    end

    data_ordered = data(order_idx, :);

    % Human-readable scenario labels in the same order
    n_ordered = length(order_idx);
    labels = strings(n_ordered, 1);
    group_names = strings(n_ordered, 1);
    for i = 1:n_ordered
        row = order_idx(i);
        val = string(summary_table.Value(row));
        group_names(i) = string(summary_table.Variable(row));
        if ismissing(val)
            val = "";
        end
        labels(i) = scenario_label_for_chart(summary_table.Variable(row), val);
    end
end

function label = scenario_label_for_chart(variable, value)
    % Map (Variable, Value) from the summary table to intuitive chart tick labels.
    variable = char(variable);
    value = char(value);

    % Bullet to prepend (LaTeX math mode)
    bullet = "\bullet ";

    if strcmp(variable, 'Baseline') || isempty(value) || strlength(value) == 0
        label = bullet + "Baseline";
        return;
    end

    % Custom labels for specific groups in the bar plot
    if contains(variable, 'Severity ceiling')
        % Expect values like "Increase to 10,000 deaths per 10,000".
        cleaned = regexprep(value, '\s*deaths per 10,000.*$', ' deaths per 10,000');
        label = bullet + string(strtrim(cleaned));
        return;
    end

    if contains(variable, 'Severity floor')
        % Expect values like "Increase to 1 death per 10,000 per year".
        cleaned = regexprep(value, '\s*death? per 10,000 per year.*$', ' deaths per 10,000 per year');
        label = bullet + string(strtrim(cleaned));
        return;
    end

    if contains(variable, 'Per capita GDP growth rate')
        % Values like "Reduce to 1.4\%" or "Increase to 1.8\%"
        v = strrep(value, '\%', '%');
        v = strtrim(v);
        % Drop trailing .0 on whole-number percentages
        if endsWith(v, '%')
            numStr = strrep(v, '%', '');
            numVal = str2double(numStr);
            if ~isnan(numVal) && abs(numVal - round(numVal)) < 1e-10
                v = sprintf('%.0f%%', numVal);
            end
        end
        label = bullet + string(v);
        return;
    end

    if contains(variable, 'Value of statistical life')
        % Values like "Reduce to \$1.0 million" or "Increase to \$1.6 million"

        v = strrep(value, '\$', '$');
        v = strtrim(v);
        % Drop trailing .0 in the numeric part before " million" if present
        tokens = regexp(v, '^(\$?)([\d\.]+)(.*)$', 'tokens', 'once');
        if ~isempty(tokens)
            prefix = tokens{1};
            numStr = tokens{2};
            suffix = tokens{3};
            numVal = str2double(numStr);
            if ~isnan(numVal) && abs(numVal - round(numVal)) < 1e-10
                numStr = sprintf('%.0f', numVal);
            end
            v = [prefix numStr suffix];
        end
        label = bullet + string(v);
        return;
    end

    if contains(variable, 'Social discount rate')
        % Values like "Reduce to 2.0\%" or "Increase to 6.0\%"
        v = strrep(value, '\%', '%');
        v = strtrim(v);
        % Drop trailing .0 on whole-number percentages
        if endsWith(v, '%')
            numStr = strrep(v, '%', '');
            numVal = str2double(numStr);
            if ~isnan(numVal) && abs(numVal - round(numVal)) < 1e-10
                v = sprintf('%.0f%%', numVal);
            end
        end
        label = bullet + string(v);
        return;
    end

    % All other cases: use the formatted value directly with bullet
    label = bullet + string(value);
end

function score = pathogen_row_score(value)
    % Scoring for pathogen-related rows so they appear in the desired order
    % within the Pathogen data group, based only on the Value text.
    v = lower(char(value));

    % Default score (later in the ordering)
    score = 5;

    if contains(v, 'airborne')
        % Airborne novel viral outbreaks
        score = 1;
    elseif contains(v, 'since 1950')
        % Novel viral outbreaks since 1950
        score = 2;
    elseif contains(v, 'unidentified')
        % Novel + unidentified viral
        score = 3;
    elseif contains(v, 'all outbreaks since 1900')
        % All outbreaks since 1900
        score = 4;
    end
end

function write_to_latex(summary_data, outpath)
    arguments
        summary_data (:,:) table
        outpath (1,1) string
    end
    fileID = fopen(outpath, 'w');
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    fprintf(fileID, '\\caption{\\textbf{Expected global pandemic deaths and losses in the absence of mitigations.} Monetized losses are discounted. Each cell presents the mean estimate.}\n');
    fprintf(fileID, '\\vskip 3pt');
    fprintf(fileID, '\\small\n\\renewcommand{\\arraystretch}{0.9}\n');
    fprintf(fileID, '\\begin{tabular}{l c c c c c}\n');
    fprintf(fileID, '\\hline\\hline\n');
    fprintf(fileID, '\\noalign{\\vskip 3pt}\n');
    fprintf(fileID, 'Scenario & \\shortstack[c]{Expected annual deaths\\\\(millions)} & \\multicolumn{4}{c}{\\shortstack[c]{Expected annualized pandemic losses \\\\ (trillion \\$)}}\\\\\n');
    fprintf(fileID, '\\hline\n');
    fprintf(fileID, ' & & Mortality & Economic & Learning & Total \\\\\n');
    fprintf(fileID, ' & $\\overline{D}$ & $AV\\!\\left(\\overline{ML}\\right)$ & $AV\\!\\left(\\overline{OL}\\right)$ & $AV\\!\\left(\\overline{LL}\\right)$ & $AV\\!\\left(\\overline{TL}\\right)$\\\\\n');
    fprintf(fileID, '\\hline\n');
    % Use the same ordering logic as the figures
    dummyData = zeros(height(summary_data), 1);
    [~, ~, order_idx] = order_rows_and_labels(summary_data, dummyData);

    lastGroup = "";
    for ii = 1:length(order_idx)
        rowIdx = order_idx(ii);
        varName = summary_data.Variable(rowIdx);
        value = summary_data.Value{rowIdx};
        groupName = string(varName);

        % Print group heading the first time we see a group
        if groupName ~= lastGroup
            if groupName == "Baseline"
                fprintf(fileID, '%s ', 'Baseline');
            else
                fprintf(fileID, '%s \\\\ \n', groupName);
            end
            lastGroup = groupName;
        end

        % Print the scenario row
        fprintf(fileID, '\\hspace{3mm} %s & ', value);
        for k = 1:5
            stat = summary_data{rowIdx, 2+k}{1};
            if k == 1
                top = stat.mean .* 1e6;
            else
                top = stat.mean;
            end
            cellstr = format_number_for_display(top);
            if k < 5
                fprintf(fileID, '%s & ', cellstr);
            else
                fprintf(fileID, '%s \\\\\n', cellstr);
            end
        end
    end
    fprintf(fileID, '\\hline\\hline\n\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:pandemic_losses}\n');
    fprintf(fileID, '\\end{table}\n');
    fclose(fileID);
    fprintf('LaTeX table successfully written to %s\n', outpath);
end

function [y_bar, y_ticks, y_ticklabels, header_y, header_labels] = grouped_y_layout(group_names, scenario_labels)
% Build y positions and labels. Scenario rows get ticks; group headers are drawn separately (no tick).
    unique_groups = unique(group_names, 'stable');
    nrows = numel(scenario_labels);
    y_bar = zeros(nrows, 1);
    y_ticks = [];
    y_ticklabels = strings(0, 1);
    header_y = [];
    header_labels = strings(0, 1);
    current_y = 1;
    for g = 1:numel(unique_groups)
        this_group = unique_groups(g);
        in_group = find(group_names == this_group);
        if isempty(in_group)
            continue;
        end
        if this_group == "Baseline"
            for j = 1:numel(in_group)
                row_idx = in_group(j);
                y_bar(row_idx) = current_y;
                y_ticks(end+1, 1) = current_y; %#ok<AGROW>
                y_ticklabels(end+1, 1) = scenario_labels(row_idx); %#ok<AGROW>
                current_y = current_y + 1;
            end
            current_y = current_y + 0.9;
        else
            % Group header: no tick; drawn separately
            header_y(end+1, 1) = current_y; %#ok<AGROW>
            header_labels(end+1, 1) = group_header_latex(this_group); %#ok<AGROW>
            current_y = current_y + 1;
            for j = 1:numel(in_group)
                row_idx = in_group(j);
                y_bar(row_idx) = current_y;
                y_ticks(end+1, 1) = current_y; %#ok<AGROW>
                y_ticklabels(end+1, 1) = "   " + scenario_labels(row_idx); %#ok<AGROW>
                current_y = current_y + 1;
            end
            current_y = current_y + 0.9;
        end
    end
end

function apply_axis_style(ax)
% Apply consistent styling to axes. Slightly dark color for weightier look without full bold.
    ax.FontName = 'Arial';
    ax.FontSize = 11;
    ax.Box = 'off';
    ax.XColor = [0.2 0.2 0.2];
    ax.YColor = [0.2 0.2 0.2];
    ax.XGrid = 'on';
    ax.YGrid = 'off';
    ax.GridColor = [0.4 0.4 0.4];
    ax.GridAlpha = 0.6;
    ax.TickDir = 'out';
end

function draw_group_headers(ax, header_y, header_labels, gap)
% Draw group header text left of axis (no tick marks). Right-aligned with small gap.
    if nargin < 4
        gap = 0.4;
    end
    if isempty(header_y)
        return;
    end
    x_pos = ax.XLim(1) - gap;
    for k = 1:numel(header_y)
        text(ax, x_pos, header_y(k), header_labels(k), ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
            'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 11, 'Interpreter', 'tex', 'Color', [0.2 0.2 0.2]);
    end
end

function format_axis_ticks(ax)
% Format axis tick labels so whole numbers are shown without decimals.
    xt = ax.XTick;
    xt_labels = arrayfun(@format_number_for_display, xt, 'UniformOutput', false);
    ax.XTickLabel = xt_labels;
end

function s = format_number_for_display(x)
% Helper to format numbers with no decimal for integers and one decimal otherwise.
    if abs(x - round(x)) < 1e-10
        s = sprintf('%.0f', x);
    else
        s = sprintf('%.1f', x);
    end
end

function s = latex_escape_label(s)
% Escape characters so scenario labels render correctly with LaTeX interpreter.
    s = strrep(s, '%', '\%');
    s = strrep(s, '$', '\$');
end

function label = group_header_latex(group_name)
% LaTeX-rendered group headers (italic with symbols).
    g = char(group_name);
    if contains(g, 'Severity ceiling')
        label = 'Severity ceiling (   )';
    elseif contains(g, 'Severity floor')
        label = 'Severity floor (   )';
    elseif contains(g, 'Per capita GDP growth rate')
        label = 'Per capita GDP growth (   )';
    elseif contains(g, 'Value of statistical life')
        label = 'Value of statistical life (   )';
    elseif contains(g, 'Social discount rate')
        label = 'Social discount rate (   )';
    else    
        label = ['' g ''];
    end
end
