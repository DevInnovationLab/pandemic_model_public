function write_sensitivity_benefits_figures(sensitivity_dir)
    % Writes LaTeX table and bar figure from aggregated benefits (processed/*.mat).
    %
    % Uses the output of agg_sensitivity_benefits: reads sensitivity_dir/processed/
    % (baseline_benefits_summary.mat and <scenario_id>_benefits_summary.mat for each scenario),
    % builds a summary table of mean net present value (and 10/90 percentiles),
    % then writes LaTeX and a horizontal bar figure. Run agg_sensitivity_benefits
    % (sensitivity_dir) first to create the processed files. Supports both one-parameter
    % (param_value_N) and multi-parameter (e.g. ptrs_pathogen_gamma1) scenario IDs.
    %
    % Args:
    %   sensitivity_dir (char or string): Path to sensitivity run directory
    %     (e.g. output/sensitivity/baseline_vaccine_program_small).
    %
    % Saves:
    %   sensitivity_dir/sensitivity_benefits_summary.tex
    %   sensitivity_dir/figures/sensitivity_benefits_bars.png

    sensitivity_dir = char(sensitivity_dir);
    processed_dir = fullfile(sensitivity_dir, 'processed');
    if ~isfolder(processed_dir)
        error('write_sensitivity_benefits_figures:NoProcessed', ...
            'Processed directory not found: %s. Run agg_sensitivity_benefits(''%s'') first.', ...
            processed_dir, sensitivity_dir);
    end

    % Collect baseline
    baseline_path = fullfile(processed_dir, 'baseline_benefits_summary.mat');
    if ~isfile(baseline_path)
        error('write_sensitivity_benefits_figures:NoBaseline', ...
            'Baseline benefits summary not found: %s', baseline_path);
    end
    S = load(baseline_path, 'mean_benefits', 'sum_net_values');
    scale = 1e12;  % report in trillions
    mean_b = S.mean_benefits / scale;
    pct = prctile(S.sum_net_values, [10 90]) / scale;

    var_names = ["Variable", "Value", "MeanBenefits", "P10", "P90"];
    summary_table = table("Baseline", "", mean_b, pct(1), pct(2), ...
        'VariableNames', var_names);

    % Collect all scenario summaries (param_value_N or multi-parameter scenario_id)
    mat_files = dir(fullfile(processed_dir, '*_benefits_summary.mat'));
    mat_files = mat_files(~strcmp({mat_files.name}, 'baseline_benefits_summary.mat'));
    for k = 1:length(mat_files)
        [~, stem, ~] = fileparts(mat_files(k).name);
        % stem is like "c_m_value_2" (one-parameter) or "ptrs_pathogen_gamma1" (multi-parameter)
        tok = regexp(stem, '^(.+)_(value_\d+)$', 'tokens');
        if ~isempty(tok)
            param_name = string(tok{1}{1});
            value_name = string(tok{1}{2});
        else
            param_name = string(stem);
            value_name = "";
        end
        % Use display name for known multi-parameter scenarios (sentence case)
        param_name = scenario_display_name(param_name);
        path_k = fullfile(processed_dir, mat_files(k).name);
        S = load(path_k, 'mean_benefits', 'sum_net_values');
        mean_b = S.mean_benefits / scale;
        pct = prctile(S.sum_net_values, [10 90]) / scale;
        summary_table = [summary_table; table(param_name, value_name, mean_b, pct(1), pct(2), 'VariableNames', var_names)];
    end

    fig_dir = fullfile(sensitivity_dir, 'figures');
    if ~isfolder(fig_dir)
        mkdir(fig_dir);
    end

    write_benefits_to_latex(summary_table, fullfile(sensitivity_dir, 'sensitivity_benefits_summary.tex'));
    plot_benefits_bars(summary_table, fig_dir);
end

function write_benefits_to_latex(summary_table, outpath)
    % Writes a LaTeX table: scenario (Variable, Value) and mean benefits (trillion $) with 10--90 percentiles.
    fileID = fopen(outpath, 'w');
    fprintf(fileID, '\\begin{table}[htbp]\n\\centering\n');
    fprintf(fileID, '\\caption{\\textbf{Expected net present value of pandemic response.} Mean and 10--90 percentiles in \\$ trillion (PV).}\n');
    fprintf(fileID, '\\small\n\\renewcommand{\\arraystretch}{0.9}\n');
    fprintf(fileID, '\\begin{tabular}{l l c}\n');
    fprintf(fileID, '\\hline\\hline\n');
    fprintf(fileID, 'Scenario (variable) & Value & Net present value (\\$ trillion) \\\\\n');
    fprintf(fileID, '\\hline\n');
    for i = 1:height(summary_table)
        v = summary_table.Variable(i);
        val = summary_table.Value(i);
        if strlength(val) == 0
            if v == "Baseline"
                val = "Baseline";
            else
                val = "--";
            end
        end
        m = summary_table.MeanBenefits(i);
        lo = summary_table.P10(i);
        hi = summary_table.P90(i);
        fprintf(fileID, '%s & %s & %.2f [%.2f, %.2f] \\\\\n', v, val, m, lo, hi);
    end
    fprintf(fileID, '\\hline\\hline\n\\end{tabular}\n');
    fprintf(fileID, '\\label{tab:sensitivity_benefits}\n');
    fprintf(fileID, '\\end{table}\n');
    fclose(fileID);
    fprintf('LaTeX table written to %s\n', outpath);
end

function plot_benefits_bars(summary_table, fig_dir)
    % Horizontal bar chart of mean benefits (trillion $) by scenario.
    n = height(summary_table);
    means = summary_table.MeanBenefits;
    labels = arrayfun(@(i) sprintf('%s %s', summary_table.Variable(i), summary_table.Value(i)), (1:n)', 'UniformOutput', false);
    for i = 1:n
        if strlength(summary_table.Value(i)) == 0
            if i == 1
                labels{i} = 'Baseline';
            else
                labels{i} = char(summary_table.Variable(i));
            end
        end
    end

    fig = figure('Visible', 'off', 'Position', [100 100 640 420]);
    ax = axes(fig);
    barh(ax, means, 'FaceColor', [0.35 0.55 0.75]);
    ax.YDir = 'reverse';
    ax.YTick = 1:n;
    ax.YTickLabel = labels;
    ax.TickLabelInterpreter = 'none';
    ax.FontSize = 9;
    ax.Box = 'on';
    ax.XGrid = 'on';
    xlabel(ax, 'Net present value (trillion $)', 'FontSize', 10);
    title(ax, 'Sensitivity of net benefits by scenario', 'FontSize', 11);

    outpath = fullfile(fig_dir, 'sensitivity_benefits_bars.png');
    exportgraphics(fig, outpath, 'Resolution', 300);
    close(fig);
    fprintf('Benefits bar chart saved to %s\n', outpath);
end

function display_name = scenario_display_name(scenario_id)
    % Return human-readable display name for known multi-parameter scenario IDs (sentence case).
    if scenario_id == "ptrs_pathogen_gamma1"
        display_name = "Vaccines always succeed, gamma = 1";
    else
        display_name = scenario_id;
    end
end
