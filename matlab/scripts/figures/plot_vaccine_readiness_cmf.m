function plot_vaccine_readiness_cmf(job_dir)
% Plot cumulative distribution of months with vaccine and R&D outcome shares.
%
% For each scenario, writes:
%   figures/vaccine_readiness_cmf.pdf
%     Share of outbreaks with at most x months of vaccine availability (capped by
%     pandemic harm duration when R&D succeeds).
%   figures/vaccine_rd_outcome_shares.pdf
%     Stacked shares of outbreaks by in-pandemic vaccine R&D outcome.
%   processed/vaccine_readiness_percentiles.csv
%     Percentiles of months with vaccine per scenario.
%   processed/vaccine_rd_outcome_shares.csv
%     Share of outbreaks with both platforms succeeding, one succeeding, or both failing.
%
% Args:
%   job_dir  Path to the job output directory (contains run_config.yaml and raw/).

    run_config = yaml.loadFile(fullfile(job_dir, "run_config.yaml"));
    raw_dir = fullfile(job_dir, "raw");
    processed_dir = fullfile(job_dir, "processed");
    figure_dir = fullfile(job_dir, "figures");
    if ~isfolder(processed_dir)
        mkdir(processed_dir);
    end
    if ~isfolder(figure_dir)
        mkdir(figure_dir);
    end

    [chunk_dirs, ~] = list_chunk_dirs(raw_dir);
    scenarios = get_vaccine_readiness_scenarios(run_config);
    percentiles = (1:100)';

    spec = get_paper_figure_spec("double_col_standard");
    fig_vax = figure("Color", "w", "Units", "inches", ...
        "Position", [1 1 spec.width_in spec.height_in], "Visible", "off");
    ax_vax = axes(fig_vax);
    hold(ax_vax, "on");

    color_palette = lines(numel(scenarios));
    legend_labels = strings(0, 1);
    readiness_table = array2table(percentiles, 'VariableNames', {'percentile'});

    for i = 1:numel(scenarios)
        scenario = scenarios(i);
        [months_with_vax, ~] = load_vaccine_timing_from_chunks(chunk_dirs, raw_dir, scenario);
        if isempty(months_with_vax)
            warning("plot_vaccine_readiness_cmf:NoData", ...
                "No pandemic events found for scenario '%s' in %s.", scenario, job_dir);
            continue;
        end

        col_name = matlab.lang.makeValidName(char(scenario));
        readiness_table.(col_name) = prctile(months_with_vax, percentiles);

        [month_grid, cmf] = empirical_cmf_by_month(months_with_vax);
        stairs(ax_vax, month_grid, cmf, ...
            "LineWidth", spec.stroke.primary, ...
            "Color", color_palette(i, :));
        legend_labels(end + 1, 1) = scenario_display_label(scenario); %#ok<AGROW>
    end

    if width(readiness_table) > 1
        writetable(readiness_table, fullfile(processed_dir, "vaccine_readiness_percentiles.csv"));
    end

    outcome_table = build_rd_outcome_table(scenarios, chunk_dirs, raw_dir);
    if ~isempty(outcome_table)
        writetable(outcome_table, fullfile(processed_dir, "vaccine_rd_outcome_shares.csv"));
        plot_rd_outcome_shares(outcome_table, spec, fullfile(figure_dir, "vaccine_rd_outcome_shares.pdf"));
    end

    style_vaccine_readiness_axes(ax_vax, spec, legend_labels, ...
        "Months with vaccine", "Cumulative share of outbreaks");
    export_figure(fig_vax, fullfile(figure_dir, "vaccine_readiness_cmf.pdf"));
    close(fig_vax);
end


function outcome_table = build_rd_outcome_table(scenarios, chunk_dirs, raw_dir)
% Build a table of R&D outcome shares for each scenario.
    scenario_ids = strings(0, 1);
    scenario_labels = strings(0, 1);
    both_succeed = zeros(0, 1);
    one_succeeds = zeros(0, 1);
    both_fail = zeros(0, 1);
    n_outbreaks = zeros(0, 1);

    for i = 1:numel(scenarios)
        scenario = scenarios(i);
        [months_with_vax, rd_state] = load_vaccine_timing_from_chunks(chunk_dirs, raw_dir, scenario);
        if isempty(months_with_vax)
            continue;
        end

        shares = rd_outcome_shares(rd_state);
        scenario_ids(end + 1, 1) = scenario; %#ok<AGROW>
        scenario_labels(end + 1, 1) = scenario_display_label(scenario); %#ok<AGROW>
        both_succeed(end + 1, 1) = shares.both_succeed; %#ok<AGROW>
        one_succeeds(end + 1, 1) = shares.one_succeeds; %#ok<AGROW>
        both_fail(end + 1, 1) = shares.both_fail; %#ok<AGROW>
        n_outbreaks(end + 1, 1) = shares.n_outbreaks; %#ok<AGROW>
    end

    outcome_table = table( ...
        scenario_ids, scenario_labels, both_succeed, one_succeeds, both_fail, n_outbreaks, ...
        'VariableNames', {'scenario', 'scenario_label', 'both_succeed', 'one_succeeds', 'both_fail', 'n_outbreaks'});
end


function plot_rd_outcome_shares(outcome_table, spec, out_path)
% Plot stacked outbreak shares by in-pandemic vaccine R&D outcome.
    outcome_colors = [0.18 0.72 0.48; 0.35 0.55 0.88; 0.72 0.12 0.12];
    outcome_data = [outcome_table.both_succeed, outcome_table.one_succeeds, outcome_table.both_fail];

    fig = figure("Color", "w", "Units", "inches", ...
        "Position", [1 1 spec.width_in spec.height_in], "Visible", "off");
    ax = axes(fig);
    bar(ax, outcome_data, "stacked", "BarWidth", 0.7);
    ax.ColorOrder = outcome_colors;
    set(ax, "XTick", 1:height(outcome_table), ...
        "XTickLabel", outcome_table.scenario_label, ...
        "XTickLabelRotation", 35, ...
        "YLim", [0 100]);
    ylabel(ax, "Share of outbreaks (%)", ...
        "FontSize", spec.typography.axis_label, "FontName", spec.font_name);
    legend(ax, {"Both platforms succeed", "One platform succeeds", "Both platforms fail"}, ...
        "Location", "northeast", ...
        "Box", "on", ...
        "FontSize", spec.typography.legend, "FontName", spec.font_name);
    apply_paper_axis_style(ax, spec);
    export_figure(fig, out_path);
    close(fig);
end


function shares = rd_outcome_shares(rd_state)
% Return outbreak shares for both succeed, one succeeds, and both fail.
    c = rd_state_codes();
    rd_state = rd_state(:);
    n = numel(rd_state);
    shares = struct();
    shares.n_outbreaks = n;
    shares.both_succeed = 100 * sum(rd_state == c.both) / n;
    shares.one_succeeds = 100 * sum(ismember(rd_state, [c.mrna, c.trad])) / n;
    shares.both_fail = 100 * sum(rd_state == c.none) / n;
end


function style_vaccine_readiness_axes(ax, spec, legend_labels, x_label, y_label)
% Apply shared axis styling for vaccine readiness CMF figures.
    xlabel(ax, x_label, ...
        "FontSize", spec.typography.axis_label, "FontWeight", "normal", "FontName", spec.font_name);
    ylabel(ax, y_label, ...
        "FontSize", spec.typography.axis_label, "FontWeight", "normal", "FontName", spec.font_name);
    if ~isempty(legend_labels)
        legend(ax, legend_labels, ...
            "Location", "southeast", ...
            "Box", "on", ...
            "FontSize", spec.typography.legend, "FontName", spec.font_name);
    end
    apply_paper_axis_style(ax, spec);
    ax.GridColor = [0.6 0.6 0.6];
    hold(ax, "off");
end


function scenarios = get_vaccine_readiness_scenarios(run_config)
% Return scenario names in display order (status quo first, then investment programs).
    available = string(fieldnames(run_config.scenarios));
    preferred_order = ["status_quo", ...
        "advance_capacity_6_month", ...
        "neglected_pathogen_rd_all", ...
        "universal_flu_rd_invest_both", ...
        "improved_early_warning_low_threshold", ...
        "combined_invest_surplus_acc"];
    ordered = preferred_order(ismember(preferred_order, available));
    ordered = ordered(:);
    extra = setdiff(available, ordered, "stable");
    extra = extra(:);
    scenarios = [ordered; extra];
end


function [months_with_vax, rd_state] = load_vaccine_timing_from_chunks(chunk_dirs, raw_dir, scenario)
% Accumulate vaccine timing values across chunks, keeping only needed columns.
    pandemic_vars = ["ufv_protection", "month_response_vaccine_ready", ...
        "prep_start_month", "rd_state", "harm_months", "is_false"];
    with_vax_chunks = cell(numel(chunk_dirs), 1);
    rd_state_chunks = cell(numel(chunk_dirs), 1);
    n_chunks = 0;

    for j = 1:numel(chunk_dirs)
        pandemic_file = fullfile(raw_dir, chunk_dirs(j).name, scenario + "_pandemic_table.mat");
        if ~isfile(pandemic_file)
            continue;
        end

        S = load(pandemic_file, "pandemic_table");
        t = S.pandemic_table(:, pandemic_vars);
        t = t(~t.is_false, :);
        t.is_false = [];
        if isempty(t)
            continue;
        end

        n_chunks = n_chunks + 1;
        [with_vax_chunks{n_chunks}, rd_state_chunks{n_chunks}] = vaccine_timing_from_events(t); %#ok<AGROW>
    end

    if n_chunks == 0
        months_with_vax = [];
        rd_state = [];
    else
        months_with_vax = vertcat(with_vax_chunks{1:n_chunks});
        rd_state = vertcat(rd_state_chunks{1:n_chunks});
    end
end


function [months_with_vax, rd_state] = vaccine_timing_from_events(event_table)
% Compute months with vaccine and retain rd_state for each outbreak.
    month_any_vaccine_ready = nan(height(event_table), 1);
    ufv_mask = event_table.ufv_protection;
    month_any_vaccine_ready(ufv_mask) = event_table.prep_start_month(ufv_mask);
    month_any_vaccine_ready(~ufv_mask) = event_table.month_response_vaccine_ready(~ufv_mask);

    has_vaccine = event_table.rd_state ~= rd_state_codes().none;
    months_with_vax = max(0, has_vaccine .* event_table.harm_months - month_any_vaccine_ready);
    months_with_vax = months_with_vax(isfinite(months_with_vax) & months_with_vax >= 0);
    rd_state = event_table.rd_state;
end


function [month_grid, cmf] = empirical_cmf_by_month(months_with_vax)
% Return CMF evaluated at each integer month: share of outbreaks with at most m months.
    months_with_vax = months_with_vax(:);
    max_month = max(months_with_vax);
    month_grid = (0:max_month)';
    counts = accumarray(months_with_vax + 1, 1, [max_month + 1, 1]);
    cmf = cumsum(counts) / numel(months_with_vax);
end


function label = scenario_display_label(scenario_name)
% Map internal scenario name to a short display label.
    scenario_name = string(scenario_name);
    if scenario_name == "status_quo"
        label = "Status quo response";
    elseif startsWith(scenario_name, "combined_invest")
        label = "Combined";
    elseif startsWith(scenario_name, "advance_capacity")
        label = "Advance capacity";
    elseif startsWith(scenario_name, "universal_flu_rd")
        label = "Universal flu vaccine R&D";
    elseif startsWith(scenario_name, "neglected_pathogen_rd")
        label = "Prototype vaccine R&D";
    elseif startsWith(scenario_name, "improved_early_warning")
        label = "Improved early warning";
    else
        label = scenario_name;
    end
end
