function compare_exceedances(outdir)
    % Compare Madhav et al. exceedance and our respiratory risk exceedance function
    % Args:
    %   outdir: Path to output directory containing simulation results

    rawdir = fullfile(outdir, "raw");
    sim_results = readtable(fullfile(rawdir, "baseline_pandemic_table.csv"));
    job_config = yaml.loadFile(fullfile(outdir, "job_config.yaml"));

    % Get severities from simulations
    ex_ante_severity = sim_results.severity;
    ex_post_severity = sim_results.ex_post_severity;
    num_draws = job_config.sim_periods * job_config.num_simulations;

    % Sort severities separately
    ex_ante_severity_sorted = sort(ex_ante_severity);
    ex_post_severity_sorted = sort(ex_post_severity);

    % Load Madhav data
    madhav_exceedances = readtable("./data/clean/madhav_et_al_severity_exceedance.csv");

    [madhav_severity_central, central_idx] = sort(madhav_exceedances.severity_central);
    madhav_exceedance_central = madhav_exceedances.exceedance_central(central_idx);

    [madhav_severity_upper, upper_idx] = sort(madhav_exceedances.severity_upper);
    madhav_exceedance_upper = madhav_exceedances.exceedance_upper(upper_idx);

    [madhav_severity_lower, lower_idx] = sort(madhav_exceedances.severity_lower);
    madhav_exceedance_lower = madhav_exceedances.exceedance_lower(lower_idx);

    % Calculate exceedance probabilities
    exceedance = (height(ex_ante_severity_sorted):-1:1)' / num_draws;

    % Systematically restrict all lines to the minimum severity shown in our model
    min_sev = max([min(ex_post_severity_sorted), ...
                   min(madhav_severity_central)]);

    % Restrict ex_ante and ex_post to >= min_sev
    ex_ante_valid = ex_ante_severity_sorted >= min_sev;
    ex_ante_severity_plot = ex_ante_severity_sorted(ex_ante_valid);
    exceedance_ante_plot = exceedance(ex_ante_valid);

    ex_post_valid = ex_post_severity_sorted >= min_sev;
    ex_post_severity_plot = ex_post_severity_sorted(ex_post_valid);
    exceedance_post_plot = exceedance(ex_post_valid);

    % Restrict Madhav data to >= min_sev
    madhav_valid = madhav_severity_central >= min_sev;
    madhav_severity_central_plot = madhav_severity_central(madhav_valid);
    madhav_exceedance_central_plot = madhav_exceedance_central(madhav_valid);

    % Create figure with appropriate size and style
    fig = figure('Position', [100 100 800 600]);
    hold on;

    % Plot exceedance functions
    ex_ante_color = [0 0.4470 0.7410];
    ex_post_color = [0.8500 0.3250 0.0980];

    % If you want to include ex_ante, uncomment the next line
    % plot(ex_ante_severity_plot, exceedance_ante_plot, 'LineWidth', 2, 'Color', ex_ante_color, 'DisplayName', 'Without vaccination');
    h_post = plot(ex_post_severity_plot, exceedance_post_plot, 'LineWidth', 2, 'Color', ex_post_color, 'DisplayName', 'Our model');

    % Plot Madhav data (restricted)
    madhav_color = [0.4940 0.1840 0.5560];
    h_madhav = plot(madhav_severity_central_plot, madhav_exceedance_central_plot / 100, ...
        'LineWidth', 2, 'Color', madhav_color, 'DisplayName', 'Madhav et al. (2023)');

    % Customize plot appearance
    set(gca, 'XScale', 'log');
    grid on;
    box off;

    % Add labels and title
    xlabel('Severity (deaths per 10,000)', 'FontSize', 12);
    ylabel('Exceedance probability', 'FontSize', 12);
    title('Pandemic risk accounting for vaccine response', 'FontSize', 16, 'FontWeight', 'normal');

    % Add direct labels to lines
    text(madhav_severity_central_plot(2), madhav_exceedance_central_plot(2)/100, 'Madhav et al. (2023)', ...
        'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', madhav_color);

    % Add direct label for our model (ex_post)
    text(ex_post_severity_plot(1000), exceedance_post_plot(1000), 'Our model', ...
        'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', ex_post_color);

    % Remove legend since we're using direct labels
    legend('off');

    % Set x-axis limits to cover the range of all plotted severity data
    min_x = min([ex_post_severity_plot(:); madhav_severity_central_plot(:)]);
    max_x = max([ex_post_severity_plot(:); madhav_severity_central_plot(:)]);
    xlim([min_x, max_x]);

    % Get directory name for figure filename
    [~, dirname] = fileparts(outdir);
    print(fig, fullfile(outdir, sprintf("%s_exceedance_comparison.png", dirname)), '-dpng', '-r400');
end