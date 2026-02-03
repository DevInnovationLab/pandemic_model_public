function compare_exceedances(outdir, varargin)
% Compare Madhav et al. exceedance with our model using bootstrap pointwise CIs.
% Args:
%   outdir (string): Path to output directory containing simulation results
%   varargin: Optional name-value pairs:
%       'IncludeCI' (logical): Whether to include confidence intervals in plots (default: false)
    p = inputParser;
    addRequired(p, 'outdir', @ischar);
    addParameter(p, 'Include90CI', false, @islogical);
    parse(p, outdir, varargin{:});
    
    include_90ci = p.Results.Include90CI;
    
    rng(42);
    B = 100;

    % Load Madhav data
    madhav_exceedances = readtable("./data/clean/madhav_et_al_severity_exceedance.csv");
    [madhav_severity_central, central_idx] = sort(madhav_exceedances.severity_central);
    madhav_exceedance_central = madhav_exceedances.exceedance_central(central_idx);
    [madhav_severity_upper, upper_idx] = sort(madhav_exceedances.severity_upper);
    madhav_exceedance_upper = madhav_exceedances.exceedance_upper(upper_idx);
    [madhav_severity_lower, lower_idx] = sort(madhav_exceedances.severity_lower);
    madhav_exceedance_lower = madhav_exceedances.exceedance_lower(lower_idx);

    % Load simulation data from all chunks
    rawdir = fullfile(outdir, "raw");
    chunk_dirs = dir(fullfile(rawdir, "chunk_*"));
    chunk_dirs = chunk_dirs([chunk_dirs.isdir]);
    
    all_tables = cell(length(chunk_dirs), 1);
    table_count = 0;
    for i = 1:length(chunk_dirs)
        chunk_path = fullfile(rawdir, chunk_dirs(i).name, "baseline_pandemic_table.mat");
        if isfile(chunk_path)
            S = load(chunk_path);
            % Filter out false positives (rows where yr_start is NaN)
            chunk_table = S.pandemic_table;
            chunk_table = chunk_table(~isnan(chunk_table.yr_start), :);
            table_count = table_count + 1;
            all_tables{table_count} = chunk_table;
        end
    end
    
    % Concatenate all tables
    all_tables = all_tables(1:table_count);
    pandemic_table = vertcat(all_tables{:});

    clear all_tables chunk_table;

    % Job config
    job_config = yaml.loadFile(fullfile(outdir, "job_config.yaml"));
    sim_periods = job_config.sim_periods;
    num_simulations = job_config.num_simulations;
    sim_num_list = 1:num_simulations;

    ante_severity_matrix = zeros(num_simulations, sim_periods);
    post_severity_matrix = zeros(num_simulations, sim_periods);
    idx = sub2ind(size(ante_severity_matrix), pandemic_table.sim_num, pandemic_table.yr_start);
    ante_severity_matrix(idx) = pandemic_table.eff_severity;
    post_severity_matrix(idx) = pandemic_table.ex_post_severity;

    clear pandemic_table;

    function [boot_mat, grid] = bootstrap_exceedance_matrix(severity_matrix, sim_num_list, num_simulations, B)
    % Compute bootstrap exceedance matrix for a given severity matrix and return the grid.
    % Args:
    %   severity_matrix (matrix): Severity values (simulations x periods)
    %   sim_num_list (vector): List of simulation indices
    %   num_simulations (int): Number of simulations
    %   B (int): Number of bootstrap samples
    % Returns:
    %   boot_mat (matrix): Bootstrap exceedance matrix (B x (length(grid)-1))
    %   grid (vector): Grid used for exceedance calculation
        grid = unique(severity_matrix(:));
        grid = grid(isfinite(grid) & isreal(grid));
        grid = sort(grid(:));
        if numel(grid) < 2
            error('Grid must have at least two unique, real, finite points.');
        end
        grid = [min(grid)-1e-6; grid; max(grid)+1e-6];
        boot_mat = zeros(B, length(grid)-1);
        for b = 1:B
            b_sims = randsample(sim_num_list, num_simulations, true);
            sev_b = severity_matrix(b_sims, :);
            sev_b = sev_b(:);
            sev_b = sev_b(~isnan(sev_b));
            S_b = (numel(sev_b) - histcounts(sev_b, grid, 'Normalization', 'cumcount')) ./ (numel(sev_b) + 1);
            boot_mat(b, :) = S_b;
        end
    end

    [ante_boot_mat, ante_grid] = bootstrap_exceedance_matrix(ante_severity_matrix, sim_num_list, num_simulations, B);
    [post_boot_mat, post_grid] = bootstrap_exceedance_matrix(post_severity_matrix, sim_num_list, num_simulations, B);

    % Use the union of ante and post grids for the common grid
    all_grid_vals = unique([ante_grid(:); post_grid(:)]);
    all_grid_vals = all_grid_vals(isfinite(all_grid_vals) & isreal(all_grid_vals) & all_grid_vals > 0);
    min_grid = min(all_grid_vals);
    max_grid = max(all_grid_vals);
    num_grid_points = 10000;
    common_grid = logspace(log10(min_grid), log10(max_grid), num_grid_points)';

    % Interpolate each bootstrap sample to the common grid
    ante_interp = zeros(B, length(common_grid)-1);
    post_interp = zeros(B, length(common_grid)-1);
    for b = 1:B
        ante_interp(b,:) = interp1(ante_grid(2:end), ante_boot_mat(b,:), common_grid(1:end-1), 'linear', 'extrap');
        post_interp(b,:) = interp1(post_grid(2:end), post_boot_mat(b,:), common_grid(1:end-1), 'linear', 'extrap');
    end

    median_ante_boot = median(ante_interp, 1);
    median_post_boot = median(post_interp, 1);
    lo_ante = prctile(ante_interp, 5, 1);
    hi_ante = prctile(ante_interp, 95, 1);
    lo_post = prctile(post_interp, 5, 1);
    hi_post = prctile(post_interp, 95, 1);

    % Compute direct exceedance curves from all data (no bootstrap)
    ante_sev_all = ante_severity_matrix(:);
    ante_sev_all = ante_sev_all(~isnan(ante_sev_all));
    post_sev_all = post_severity_matrix(:);
    post_sev_all = post_sev_all(~isnan(post_sev_all));

    % Use a grid that includes 0 so zeros (no-event years) are counted by histcounts.
    % common_grid starts at min_grid > 0, so zeros would fall outside and distort exceedance.
    direct_edges = [0; logspace(log10(min_grid), log10(max_grid), num_grid_points - 1)'];
    ante_direct = (numel(ante_sev_all) - histcounts(ante_sev_all, direct_edges, 'Normalization', 'cumcount')) ./ (numel(ante_sev_all) + 1);
    post_direct = (numel(post_sev_all) - histcounts(post_sev_all, direct_edges, 'Normalization', 'cumcount')) ./ (numel(post_sev_all) + 1);

    % Madhav data for plotting
    mad_valid = madhav_severity_central > 0;
    madhav_severity_central_plot = madhav_severity_central(mad_valid);
    madhav_severity_upper_plot = madhav_severity_upper(mad_valid);
    madhav_severity_lower_plot = madhav_severity_lower(mad_valid);
    madhav_exceedance_central_plot = madhav_exceedance_central(mad_valid) / 100;
    madhav_exceedance_upper_plot  = madhav_exceedance_upper(mad_valid) / 100;
    madhav_exceedance_lower_plot  = madhav_exceedance_lower(mad_valid) / 100;

    ex_ante_color = [0 0.4470 0.7410];
    ex_post_color = [0.8500 0.3250 0.0980];
    madhav_color  = [0.4940 0.1840 0.5560];
    x_ribbon = common_grid(1:end-1)';
    x_ribbon_direct = direct_edges(2:end)';
    % ========== Figure 1: Bootstrap median ==========
    fig1 = figure('Position', [100 100 900 650]); hold on;

    % Add confidence intervals if requested
    if include_90ci
        plot(x_ribbon, lo_ante, '--', 'LineWidth', 1, 'Color', ex_ante_color, 'HandleVisibility', 'off');
        plot(x_ribbon, hi_ante, '--', 'LineWidth', 1, 'Color', ex_ante_color, 'HandleVisibility', 'off');
        plot(x_ribbon, lo_post, '--', 'LineWidth', 1, 'Color', ex_post_color, 'HandleVisibility', 'off');
        plot(x_ribbon, hi_post, '--', 'LineWidth', 1, 'Color', ex_post_color, 'HandleVisibility', 'off');
    end

    plot(x_ribbon, median_ante_boot, 'LineWidth', 2, 'Color', ex_ante_color, ...
        'DisplayName', 'Without vaccination');
    plot(x_ribbon, median_post_boot, 'LineWidth', 2, 'Color', ex_post_color, ...
        'DisplayName', 'With vaccination');
    plot(madhav_severity_central_plot, madhav_exceedance_central_plot, ...
        'LineWidth', 2, 'Color', madhav_color, 'DisplayName', 'Madhav et al. (2023)');

    set(gca, 'XScale', 'log', 'YScale', 'log'); grid on; box off;
    xlabel('Severity (deaths per 10,000)', 'FontSize', 14);
    ylabel('Exceedance probability', 'FontSize', 14);
    title('Exceedance probability curves (Bootstrap median)', 'FontSize', 15);
    legend('Location', 'best');

    min_x = max([min(common_grid(:)); min(madhav_severity_central_plot(:))]);
    max_x = min([max(common_grid(:)); max(madhav_severity_central_plot(:))]);
    xlim([min_x, max_x]);
    xt = get(gca, 'XTick');
    set(gca, 'XTickLabel', arrayfun(@(x) num2str(round(x), '%.0f'), xt, 'UniformOutput', false));

    [~, dirname] = fileparts(outdir);
    ci_suffix = '';
    if include_90ci
        ci_suffix = '_with_ci';
    end
    print(fig1, fullfile(outdir, sprintf("%s_exceedance_bootstrap_median%s.png", dirname, ci_suffix)), '-dpng', '-r400');

    % ========== Figure 2: Direct calculation (all data) ==========
    fig2 = figure('Position', [100 100 900 650]); hold on;

    % Plot direct exceedance curves (use x_ribbon_direct from direct_edges)
    plot(x_ribbon_direct, ante_direct, 'LineWidth', 2, 'Color', ex_ante_color, ...
        'DisplayName', 'Without vaccination');
    plot(x_ribbon_direct, post_direct, 'LineWidth', 2, 'Color', ex_post_color, ...
        'DisplayName', 'With vaccination');

    % Madhav
    plot(madhav_severity_central_plot, madhav_exceedance_central_plot, ...
        'LineWidth', 2, 'Color', madhav_color, 'DisplayName', 'Madhav et al. (2023)');

    set(gca, 'XScale', 'log', 'YScale', 'log'); grid on; box off;
    xlabel('Severity (deaths per 10,000)', 'FontSize', 14);
    ylabel('Exceedance probability', 'FontSize', 14);
    title('Exceedance probability curves (Direct calculation)', 'FontSize', 15);

    % Direct labels (index into direct curve length = numel(x_ribbon_direct))
    n_direct = numel(x_ribbon_direct);
    idx_madhav = min(2, numel(madhav_severity_central_plot));
    idx_post = min(max(1, round(0.4 * n_direct)), n_direct);
    idx_ante = min(max(1, round(0.25 * n_direct)), n_direct);
    text(madhav_severity_central_plot(idx_madhav), madhav_exceedance_central_plot(idx_madhav), ...
        'Madhav et al. (2023)', 'FontSize', 11, 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'bottom', 'Color', madhav_color);
    text(x_ribbon_direct(idx_post), post_direct(idx_post), 'With vaccination', ...
        'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', ex_post_color);
    text(x_ribbon_direct(idx_ante), ante_direct(idx_ante), 'Without vaccination', ...
        'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', ex_ante_color);

    legend('off');
    min_x = max([min(x_ribbon_direct); min(madhav_severity_central_plot(:))]);
    max_x = min([max(x_ribbon_direct); max(madhav_severity_central_plot(:))]);
    xlim([min_x, max_x]);
    xt = get(gca, 'XTick');
    set(gca, 'XTickLabel', arrayfun(@(x) num2str(round(x), '%.0f'), xt, 'UniformOutput', false));

    % Save figure 2
    print(fig2, fullfile(outdir, sprintf("%s_exceedance_direct.png", dirname)), '-dpng', '-r400');

    % Output median annual recurrence rates to CSV (using bootstrap median)
    T = table(common_grid(1:end-1), 1 ./ (median_ante_boot'), 1 ./ (median_post_boot'), ...
        'VariableNames', {'severity', 'median_ante_recurrence', 'median_post_recurrence'});
    writetable(T, fullfile(outdir, 'median_annual_recurrence_rates.csv'));

end
