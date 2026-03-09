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

    % Equal-sized panels. Margins on all sides; use print so they export. Left margin 80% of original (toned down 20%).
    marginLeft = 0.22;
    marginRight = 0.07;
    marginBottom = 0.06;
    marginTop = 0.05;
    panelW = 1 - marginLeft - marginRight;
    gap = 0.04;
    % Panel height so both panels fill the vertical space (figure is 25% taller; plots inhabit that area).
    panelH = (1 - marginTop - marginBottom - gap) / 2;
    bottomPanelBottom = marginBottom;
    topPanelBottom = marginBottom + panelH + gap;

    fig = figure('Visible', 'off', 'Position', [100 100 920 1025]);
    fig.PaperPositionMode = 'auto';
    % Top panel: annualized losses (stacked)
    ax1 = axes(fig, 'Position', [marginLeft topPanelBottom panelW panelH]);
    b = barh(ax1, loss_data_ordered, 'stacked', 'FaceColor', 'flat');
    for k = 1:3
        b(k).CData = repmat(colors(k,:), nrows, 1);
    end
    ax1.YDir = 'reverse';
    ax1.YTick = 1:nrows;
    ax1.YTickLabel = labels;
    ax1.TickLabelInterpreter = 'none';
    ax1.FontSize = 9;
    ax1.Box = 'off';
    ax1.XGrid = 'on';
    ax1.Title = [];
    xlabel(ax1, 'Expected annualized pandemic loss ($ trillion)', 'FontSize', 10);
    legend(ax1, {'Mortality', 'Economic', 'Learning'}, 'Location', 'northeast', ...
        'Orientation', 'horizontal', 'FontSize', 9);
    set(ax1, 'Layer', 'top');

    % Bottom panel: expected annual deaths (millions), same size as top
    ax2 = axes(fig, 'Position', [marginLeft bottomPanelBottom panelW panelH]);
    barh(ax2, deaths_ordered, 'FaceColor', [0.45 0.25 0.55]);
    ax2.YDir = 'reverse';
    ax2.YTick = 1:nrows;
    ax2.YTickLabel = labels;
    ax2.TickLabelInterpreter = 'none';
    ax2.FontSize = 9;
    ax2.Box = 'off';
    ax2.XGrid = 'on';
    ax2.Title = [];
    xlabel(ax2, 'Expected annual deaths (millions)', 'FontSize', 10);
    set(ax2, 'Layer', 'top');

    outpath = fullfile(fig_dir, 'sensitivity_stacked_losses.png');
    % Use print so the full figure (including margins) is exported; exportgraphics crops tightly to content.
    print(fig, outpath, '-dpng', '-r300');
    close(fig);
    fprintf('Stacked loss and deaths panel saved to %s\n', outpath);
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
    % Order rows: baseline first, then by variable order. Return ordered data, value labels, and row indices.
    variableOrder = [
        "Lower severity threshold ($\underline{s}$)"
        "Pathogen types"
        "Sample period"
        "Severity upper bound ($\overline{s}$)"
        "Per capita GDP growth rate ($y$)"
        "Value of statistical life (VSL)"
        "Social discount rate $r$"
    ];
    uniqueVars = unique(summary_table.Variable, 'stable');
    baselineIdx = strcmp(uniqueVars, 'Baseline');
    orderedVars = uniqueVars(baselineIdx);
    for k = 1:length(variableOrder)
        idx = find(strcmp(uniqueVars, variableOrder(k)), 1);
        if ~isempty(idx)
            orderedVars = [orderedVars; uniqueVars(idx)];
        end
    end
    remaining = ~ismember(uniqueVars, orderedVars);
    if any(remaining)
        orderedVars = [orderedVars; uniqueVars(remaining)];
    end

    order_idx = [];
    for v = 1:length(orderedVars)
        order_idx = [order_idx; find(strcmp(summary_table.Variable, orderedVars(v)))];
    end
    data_ordered = data(order_idx, :);
    % Use intuitive chart labels (same order as table)
    n_ordered = length(order_idx);
    labels = strings(n_ordered, 1);
    for i = 1:n_ordered
        row = order_idx(i);
        var = string(summary_table.Variable(row));
        val = string(summary_table.Value(row));
        if ismissing(val)
            val = "";
        end
        labels(i) = scenario_label_for_chart(var, val);
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
    if contains(variable, 'Lower severity') && contains(value, '1 SU')
        label = "Lower threshold 1 SU";
        return;
    end
    if contains(variable, 'Pathogen types')
        if contains(value, 'Airborne')
            label = "Airborne pathogens only";
        elseif contains(value, 'unidentified and bacterial')
            label = "All outbreaks since 1900";
        elseif contains(value, 'unidentified')
            label = "Including unidentified pathogens";
        else
            label = value;
        end
        return;
    end
    if contains(variable, 'Sample period') && contains(value, '1950')
        label = "Outbreaks since 1950";
        return;
    end
    if contains(variable, 'Severity upper')
        if contains(value, '10000') || contains(value, '10,000')
            label = "Severity ceiling 10,000";
        elseif contains(value, '1000') || contains(value, '1,000')
            label = "Severity ceiling 1,000";
        else
            label = value;
        end
        return;
    end
    if contains(variable, 'VSL') || contains(variable, 'statistical life')
        if contains(value, '1.6')
            label = "VSL $1.6 million";
        elseif contains(value, '1 million')
            label = "VSL $1 million";
        else
            label = value;
        end
        return;
    end
    if contains(variable, 'growth rate') || contains(variable, 'GDP growth')
        if contains(value, '1.4')
            label = "Growth rate 1.4%";
        elseif contains(value, '1.8')
            label = "Growth rate 1.8%";
        else
            label = value;
        end
        return;
    end
    if contains(variable, 'discount rate')
        if contains(value, '2') && ~contains(value, '6')
            label = "Discount rate 2%";
        elseif contains(value, '6')
            label = "Discount rate 6%";
        else
            label = value;
        end
        return;
    end
    % Fallback: use value or variable
    if isempty(value)
        label = variable;
    else
        label = value;
    end
end

function write_to_latex(summary_data, outpath)
    arguments
        summary_data (:,:) table
        outpath (1,1) string
    end
    fileID = fopen(outpath, 'w');
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    fprintf(fileID, '\\caption{\\textbf{Expected global pandemic deaths and losses in the absence of mitigations.} Monetized losses are discounted. Each cell presents the mean estimates in the center with the 10--90 percentiles in square brackets below.}\n');
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
    variableOrder = [
        "Lower severity threshold ($\underline{s}$)"
        "Pathogen types"
        "Sample period"
        "Severity upper bound ($\overline{s}$)"
        "Per capita GDP growth rate ($y$)"
        "Value of statistical life (VSL)"
        "Social discount rate $r$"
    ];
    uniqueVars = unique(summary_data.Variable, 'stable');
    baselineIdx = strcmp(uniqueVars, 'Baseline');
    ordered = uniqueVars(baselineIdx);
    for k = 1:length(variableOrder)
        idx = find(strcmp(uniqueVars, variableOrder(k)), 1);
        if ~isempty(idx)
            ordered = [ordered; uniqueVars(idx)];
        end
    end
    remaining = ~ismember(uniqueVars, ordered);
    if any(remaining)
        ordered = [ordered; uniqueVars(remaining)];
    end
    uniqueVars = ordered;
    for i = 1:length(uniqueVars)
        varRows = strcmp(summary_data.Variable, uniqueVars{i});
        varData = summary_data(varRows, :);
        if strcmp(uniqueVars{i}, 'Baseline')
            fprintf(fileID, '%s ', uniqueVars{i});
        else
            fprintf(fileID, '%s \\\\\n', uniqueVars{i});
        end
        for j = 1:height(varData)
            fprintf(fileID, '\\hspace{3mm} %s & ', varData.Value{j});
            for k = 1:5
                stat = varData{j, 2+k}{1};
                if k == 1
                    top = stat.mean .* 1e6;
                    lo  = stat.p10  .* 1e6;
                    hi  = stat.p90  .* 1e6;
                else
                    top = stat.mean;
                    lo  = stat.p10;
                    hi  = stat.p90;
                end
                cellstr = sprintf('\\begin{tabular}[c]{@{}c@{}}%.1f \\\\[-0.7em] \\footnotesize [%.1f, %.1f]\\end{tabular}', top, lo, hi);
                if k < 5
                    fprintf(fileID, '%s & ', cellstr);
                else
                    fprintf(fileID, '%s \\\\\n', cellstr);
                end
            end
        end
    end
    fprintf(fileID, '\\hline\\hline\n\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:pandemic_losses}\n');
    fprintf(fileID, '\\end{table}\n');
    fclose(fileID);
    fprintf('LaTeX table successfully written to %s\n', outpath);
end
