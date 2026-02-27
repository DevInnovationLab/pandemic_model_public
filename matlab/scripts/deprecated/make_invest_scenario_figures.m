function make_invest_scenario_figures(job_dir, recalculate_bc)
    % MAKE_OPTION1_PLOTS
    % Creates two plots using the same data + logic as your table generator:
    %  (1) Impact vs. Cost scatter (benefits vs. costs, bubble size = lives saved @30y)
    %  (2) Cumulative lives saved over time (stacked by scenario), plus combined line if present
    %
    % Args:
    %   job_dir (string): root directory with /raw and /processed
    %   recalculate_bc (logical): if true, re-run benefit/cost processing first
    %
    % Outputs:
    %   Saves figures into <processed_dir>/fig_impact_vs_cost.<ext> and
    %   <processed_dir>/fig_lives_saved_timeline.<ext>

    % ------------------------------------------------------------
    % 0) Precompute benefits & costs if asked
    % ------------------------------------------------------------
    if recalculate_bc
        process_benefit_cost(job_dir, recalculate_bc);
    end
    
    rawdata_dir    = fullfile(job_dir, "raw");
    processed_dir  = fullfile(job_dir, "processed");
    figure_dir     = fullfile(job_dir, "figures");
    
    % ------------------------------------------------------------
    % 1) Load baseline data & config
    % ------------------------------------------------------------
    baseline_npv       = readmatrix(fullfile(processed_dir, "baseline_absolute_npv.csv"));
    baseline_costs     = readmatrix(fullfile(processed_dir, "baseline_pv_costs.csv"));
    baseline_mortality = load(fullfile(rawdata_dir, "baseline_results.mat"), "sim_out_arr_m_deaths");
    baseline_mortality = baseline_mortality.sim_out_arr_m_deaths;
    
    % Totals across all years (discounted)
    total_baseline_npv      = mean(sum(baseline_npv, 2));
    total_baseline_costs    = mean(sum(baseline_costs, 2));
    total_baseline_benefits = total_baseline_npv + total_baseline_costs;
    
    % Scenarios (same ordering logic; move combined_invest to end)
    config    = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, 'baseline'));
    
    combined_idx = find(strcmp(scenarios, 'combined_invest'));
    if ~isempty(combined_idx)
        scenarios = [scenarios(1:(combined_idx-1)); scenarios((combined_idx+1):end); scenarios(combined_idx)];
    end
    
    % Determine time horizon from baseline data
    T = size(baseline_costs, 2);
    years = 1:T;
    
    % Containers for plotting
    S = numel(scenarios);
    cost_diff_all     = nan(S,1);
    benefit_diff_all  = nan(S,1);
    lives_10yr        = nan(S,1);
    lives_30yr        = nan(S,1);
    bcr_all           = nan(S,1);
    pretty_labels     = strings(S,1);
    
    % For timeline (stacked area): cumulative lives saved per scenario by year
    cum_lives_by_scen = nan(S, T);
    
    for i = 1:S
        scen = scenarios(i);
    
        % ---- Load scenario files ----
        scen_npv    = readmatrix(fullfile(processed_dir, scen + "_absolute_npv.csv"));
        scen_costs  = readmatrix(fullfile(processed_dir, scen + "_pv_costs.csv"));
        scen_benef  = scen_npv + scen_costs;
    
        scen_m      = load(fullfile(rawdata_dir, sprintf('%s_results.mat', scen)), 'sim_out_arr_m_deaths');
        scen_mort   = scen_m.sim_out_arr_m_deaths;
    
        % ---- Totals (discounted) ----
        total_scen_npv      = mean(sum(scen_npv, 2));
        total_scen_costs    = mean(sum(scen_costs, 2));
        total_scen_benefits = mean(sum(scen_benef, 2));
    
        % Differences from baseline
        cost_diff     = total_scen_costs    - total_baseline_costs;
        benefit_diff  = total_scen_benefits - total_baseline_benefits;
        if cost_diff <= 0
            bc_ratio_all = Inf;
        else
            bc_ratio_all = benefit_diff / cost_diff;
        end
    
        % ---- Lives saved (mean across sims) ----
        lives_diff_yearly = mean(baseline_mortality - scen_mort, 1);  % 1 x T
        lives_cum         = cumsum(lives_diff_yearly);                 % cumulative
    
        % Store for plotting
        cost_diff_all(i)    = cost_diff;
        benefit_diff_all(i) = benefit_diff;
        bcr_all(i)          = bc_ratio_all;
        lives_10yr(i)       = sum(lives_diff_yearly(1:min(10,T)));
        lives_30yr(i)       = sum(lives_diff_yearly(1:min(30,T)));
        cum_lives_by_scen(i,:) = lives_cum;
    
        % Human-friendly labels
        lbl = scen;
        lbl = convert_varnames(lbl);
        pretty_labels(i) = lbl;
    end
    
    % ------------------------------------------------------------
    % 2) Figure 1 — Impact vs. cost scatter (bubble = benefit-cost ratio, linear size)
    % ------------------------------------------------------------
    fig1 = figure('Color','w','Position',[100 100 900 650]);
    
    % Axes values in $ billions
    x_cost_B = cost_diff_all  / 1e9;
    y_ben_B  = benefit_diff_all / 1e9;
    
    size_metric = round(bcr_all);
    marker_color = [0 0.4470 0.7410];
    
    % Draw bubbles
    h = bubblechart(x_cost_B, y_ben_B, size_metric, marker_color);
    hold on; grid on; box off;
    
    % Label each bubble with the scenario name
    for i = 1:S
        % If scenario is 'advance_capacity', align label at bottom, else middle
        if strcmp(scenarios(i), "advance_capacity")
            valign = 'bottom';
            y_offset = 0.15; % push a little more up if advance capacity
        else
            valign = 'middle';
            y_offset = 0;
        end
        text(x_cost_B(i) + 0.12, y_ben_B(i) + y_offset, " " + pretty_labels(i), ...
            'FontSize',10,'Interpreter','none', ...
            'HorizontalAlignment','left','VerticalAlignment',valign);
    end
    
    % Reference lines for B/C = 10 and 100   (y = 10x, y = 100x)
    x_max = max([eps, max(x_cost_B)]);
    y_max = max([eps, max(y_ben_B)]);
    x_ref = linspace(0, x_max, 200);
    
    y10   = 10*x_ref; y10(y10>y_max) = NaN;
    y100  = 100*x_ref; y100(y100>y_max) = NaN;
    
    plot(x_ref, y10,  ':',  'LineWidth',1, 'Color',[0.7 0.4 0.1]);
    plot(x_ref, y100, '-.',  'LineWidth',1, 'Color',[0.2 0.6 0.2]);
    
    % Slope-aligned labels
    ax = gca; dar = daspect(ax);
    angle10  = atan2d(10*dar(1),  dar(2));
    angle100 = atan2d(100*dar(1), dar(2));
    idx10  = round(length(x_ref)/2);
    idx100 = round(length(x_ref)/5);
    text(x_ref(idx10), y10(idx10), ' BCR = 10', 'FontSize',10, ...
        'Color',[0.7 0.4 0.1], 'Rotation', angle10, ...
        'VerticalAlignment','bottom','HorizontalAlignment','left');
    text(x_ref(idx100), y100(idx100), ' BCR = 100', 'FontSize',10, ...
        'Color',[0.2 0.6 0.2], 'Rotation', angle100, ...
        'VerticalAlignment','bottom','HorizontalAlignment','left');
    
    % Axes labels
    xlabel('Costs ($ billions)','FontSize',13);
    ylabel('Benefits ($ billions)','FontSize',13);
    
    % Bubble legend uses the underlying size values automatically (here = B/C)
    blgd = bubblelegend('Benefit–cost ratio');
    blgd.NumBubbles = 3;             % compact legend
    blgd.Location = 'eastoutside';

    % Set x and y axis limits so that the minimum is 0, but keep the current upper limits
    ax = gca;
    xlim([0, ax.XLim(2)]);
    ylim([0, ax.YLim(2)]);

    % Save high-quality versions using saveas (PNG and vector PDF)
    set(fig1, 'PaperPositionMode', 'auto');
    print(fig1, fullfile(figure_dir, 'fig_impact_vs_cost.png'), '-dpng', '-r600');

    % ------------------------------------------------------------
    % 3) FIGURE 2 — Cumulative lives saved over time
    %     Stacked area by scenario; also plot combined_invest line if present
    % ------------------------------------------------------------
    fig2 = figure('Color','w','Position',[100 100 1000 650]);

    % Convert cumulative lives saved to millions (do not remove negatives)
    cum_lives_millions = cum_lives_by_scen / 1e6;

    % Plot lines for each scenario over time
    plot(years, cum_lives_millions', 'LineWidth', 2);
    grid on; box on;
    xlabel('Year');
    ylabel('Cumulative lives saved (millions)');
    title('Cumulative lives saved over time (by scenario)');
    legend(pretty_labels, 'Location','northwestoutside', 'Interpreter','none');

    % Save high-quality versions using saveas (PNG and vector PDF)
    set(fig2, 'PaperPositionMode', 'auto');
    print(fig2, fullfile(figure_dir, 'fig_lives_saved_timeline.png'), '-dpng', '-r600');
end
