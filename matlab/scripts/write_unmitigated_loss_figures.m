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
    plot_total_stacked_bars(total_summary_table, fig_dir);
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

    [loss_data_ordered, labels, order_idx] = order_rows_and_labels(summary_table, loss_data);
    deaths_ordered = annual_deaths(order_idx);

    colors = [0.45 0.25 0.55; 0.85 0.45 0.25; 0.25 0.55 0.45];
    nrows = size(loss_data_ordered, 1);

    % Combined two-panel figure (for reference)
    % Figure: social losses only
    fig_loss = figure('Visible', 'off', 'Position', [100 100 780 540]);
    fig_loss.PaperPositionMode = 'auto';
    ax_loss = axes(fig_loss);
    b_loss = barh(ax_loss, loss_data_ordered, 'stacked', 'FaceColor', 'flat');
    for k = 1:3
        b_loss(k).CData = repmat(colors(k,:), nrows, 1);
    end
    ax_loss.YDir = 'reverse';
    ax_loss.YTick = 1:nrows;
    ax_loss.YTickLabel = labels;
    ax_loss.TickLabelInterpreter = 'none';
    ax_loss.FontSize = 9;
    ax_loss.Box = 'off';
    ax_loss.XGrid = 'on';
    ax_loss.Title = [];
    xlabel(ax_loss, 'Expected annualized social loss ($ trillion)', 'FontSize', 10);
    legend(ax_loss, {'Mortality', 'Economic', 'Learning'}, 'Location', 'northeast', ...
        'Orientation', 'horizontal', 'FontSize', 9);
    set(ax_loss, 'Layer', 'top');
    outpath_loss = fullfile(fig_dir, 'sensitivity_stacked_losses_social.png');
    print(fig_loss, outpath_loss, '-dpng', '-r600');
    close(fig_loss);
    fprintf('Social loss panel saved to %s\n', outpath_loss);

    % Figure: annual deaths only
    fig_deaths = figure('Visible', 'off', 'Position', [100 100 780 540]);
    fig_deaths.PaperPositionMode = 'auto';
    ax_deaths = axes(fig_deaths);
    barh(ax_deaths, deaths_ordered, 'FaceColor', [0.45 0.25 0.55]);
    ax_deaths.YDir = 'reverse';
    ax_deaths.YTick = 1:nrows;
    ax_deaths.YTickLabel = labels;
    ax_deaths.TickLabelInterpreter = 'none';
    ax_deaths.FontSize = 9;
    ax_deaths.Box = 'off';
    ax_deaths.XGrid = 'on';
    ax_deaths.Title = [];
    xlabel(ax_deaths, 'Expected annual deaths (millions)', 'FontSize', 10);
    set(ax_deaths, 'Layer', 'top');
    outpath_deaths = fullfile(fig_dir, 'sensitivity_stacked_losses_deaths.png');
    print(fig_deaths, outpath_deaths, '-dpng', '-r600');
    close(fig_deaths);
    fprintf('Annual deaths panel saved to %s\n', outpath_deaths);
end

function plot_total_stacked_bars(total_summary_table, fig_dir)
    % Horizontal stacked bar chart of total (undiscounted) losses per scenario.
    n = height(total_summary_table);
    mortality = zeros(n, 1);
    economic  = zeros(n, 1);
    learning  = zeros(n, 1);
    for i = 1:n
        mortality(i) = total_summary_table{i, 4}{1}.mean;
        economic(i)  = total_summary_table{i, 5}{1}.mean;
        learning(i)  = total_summary_table{i, 6}{1}.mean;
    end
    data = [mortality, economic, learning];

    [data, labels] = order_rows_and_labels(total_summary_table, data);
    colors = [0.45 0.25 0.55; 0.85 0.45 0.25; 0.25 0.55 0.45];

    fig = figure('Visible', 'off', 'Position', [100 100 640 420]);
    ax = axes(fig);
    b = barh(ax, data, 'stacked', 'FaceColor', 'flat');
    for k = 1:3
        b(k).CData = repmat(colors(k,:), size(data, 1), 1);
    end
    ax.YDir = 'reverse';
    ax.YTick = 1:size(data, 1);
    ax.YTickLabel = labels;
    ax.TickLabelInterpreter = 'none';
    ax.FontSize = 9;
    ax.Box = 'off';
    ax.Title = [];
    ax.XGrid = 'on';
    xlabel(ax, 'Expected total pandemic loss ($ trillion)', 'FontSize', 10);
    legend(ax, {'Mortality', 'Economic', 'Learning'}, 'Location', 'eastoutside', 'FontSize', 9);
    set(ax, 'Layer', 'top');

    outpath = fullfile(fig_dir, 'sensitivity_total_stacked_losses.png');
    exportgraphics(fig, outpath, 'Resolution', 600);
    close(fig);
    fprintf('Total stacked loss chart saved to %s\n', outpath);
end

function [data_ordered, labels, order_idx] = order_rows_and_labels(summary_table, data)
    % Order rows into canonical groups and within-group ordering used in both
    % tables and figures. Uses the formatted Variable names coming from
    % build_sensitivity_loss_tables so headings/ordering are driven
    % entirely by those upstream labels.

    n = height(summary_table);

    % Desired group ordering using the formatted names
    groupOrder = [
        "Baseline"
        "Severity ceiling ($\overline{s}$)"
        "Intensity floor ($\underline{x}$)"
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
    for i = 1:n_ordered
        row = order_idx(i);
        val = string(summary_table.Value(row));
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

    if strcmp(variable, 'Baseline') || isempty(value) || strlength(value) == 0
        label = "Baseline";
        return;
    end

    % Custom labels for specific groups in the bar plot
    if contains(variable, 'Severity ceiling')
        % Expect values like "Increase to 10,000 deaths per 10,000".
        % Strip the verb, then replace the deaths-per-10,000 unit with SMU.
        cleaned = regexprep(value, '^Increase to\s*', '');
        cleaned = regexprep(cleaned, '\s*deaths per 10,000.*$', ' SMU');
        label = "Severity ceiling = " + string(strtrim(cleaned));
        return;
    end

    if contains(variable, 'Intensity floor')
        % Expect values like "Increase to 1 death per 10,000 per year".
        cleaned = regexprep(value, '^Increase to\s*', '');
        % Replace the deaths-per-10,000-per-year unit with SMU per year.
        cleaned = regexprep(cleaned, '\s*death? per 10,000 per year.*$', ' SMU per year');
        label = "Intensity floor = " + string(strtrim(cleaned));
        return;
    end

    if contains(variable, 'Per capita GDP growth rate')
        % Values like "Reduce to 1.4\%" or "Increase to 1.8\%"
        v = strrep(value, 'Reduce to ', '');
        v = strrep(v, 'Increase to ', '');
        v = strrep(v, '\%', '%');
        v = strtrim(v);
        label = "Per capita GDP growth rate = " + string(v);
        return;
    end

    if contains(variable, 'Value of statistical life')
        % Values like "Reduce to \$1.0 million" or "Increase to \$1.6 million"
        v = strrep(value, 'Reduce to ', '');
        v = strrep(v, 'Increase to ', '');
        v = strrep(v, '\$', '$');
        v = strtrim(v);
        label = "Value of statistical life = " + string(v);
        return;
    end

    if contains(variable, 'Social discount rate')
        % Values like "Reduce to 2.0\%" or "Increase to 6.0\%"
        v = strrep(value, 'Reduce to ', '');
        v = strrep(v, 'Increase to ', '');
        v = strrep(v, '\%', '%');
        v = strtrim(v);
        label = "Social discount rate = " + string(v);
        return;
    end

    % All other cases: use the formatted value directly
    label = string(value);
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
    fprintf(fileID, 'Scenario & \\shortstack[c]{Expected annual deaths\\\\(millions)} & \\multicolumn{4}{c}{\\shortstack[c]{Expected annualized pandemic losses \\\\ (\\$ trillion)}}\\\\\n');
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
            cellstr = sprintf('%.1f', top);
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
