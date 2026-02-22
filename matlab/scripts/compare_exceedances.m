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

    % Job config (needed for chunk bounds and matrix size)
    job_config = yaml.loadFile(fullfile(outdir, "job_config.yaml"));
    sim_periods = job_config.sim_periods;
    num_simulations = job_config.num_simulations;
    sim_num_list = 1:num_simulations;

    % Chunk layout: same as run_job so we can convert chunk-local sim_num to global
    rawdir = fullfile(outdir, "raw");
    chunk_dirs = dir(fullfile(rawdir, "chunk_*"));
    chunk_dirs = chunk_dirs([chunk_dirs.isdir]);
    chunk_numbers = cellfun(@(x) sscanf(x, 'chunk_%d'), {chunk_dirs.name});
    [~, sort_idx] = sort(chunk_numbers);
    chunk_dirs = chunk_dirs(sort_idx);
    num_chunks = length(chunk_dirs);

    % Columns we need from each table (keep loading light)
    base_vars = {'sim_num', 'yr_start', 'eff_severity', 'is_false'};
    pandemic_vars = {'sim_num', 'yr_start', 'ex_post_severity', 'is_false'};

    all_base = cell(num_chunks, 1);
    all_pandemic = cell(num_chunks, 1);
    base_count = 0;
    pandemic_count = 0;

    for i = 1:num_chunks
        chunk_dir = fullfile(rawdir, chunk_dirs(i).name);

        % Base table: all outbreaks (including those below response threshold)
        base_path = fullfile(chunk_dir, 'base_simulation_table.mat');
        if isfile(base_path)
            S = load(base_path, 'base_simulation_table');
            base_t = S.base_simulation_table;
            base_t = base_t(:, base_vars);
            base_t = base_t(~base_t.is_false & ~isnan(base_t.yr_start), :);
            base_t.is_false = [];  % no longer needed
            base_count = base_count + 1;
            all_base{base_count} = base_t;
        end

        % Baseline pandemic table: only outbreaks that passed response threshold
        pandemic_path = fullfile(chunk_dir, 'baseline_pandemic_table.mat');
        if isfile(pandemic_path)
            S = load(pandemic_path, 'pandemic_table');
            pan_t = S.pandemic_table;
            pan_t = pan_t(:, pandemic_vars);
            pan_t = pan_t(~pan_t.is_false & ~isnan(pan_t.yr_start), :);
            pan_t.is_false = [];  % no longer needed
            pandemic_count = pandemic_count + 1;
            all_pandemic{pandemic_count} = pan_t;
        end
    end

    base_merged = vertcat(all_base{1:base_count});
    pandemic_merged = vertcat(all_pandemic{1:pandemic_count});
    clear all_base all_pandemic S base_t pan_t;

    % Merge on (sim_num, yr_start). Ex-post severity from pandemic when present; otherwise eff_severity.
    pandemic_keys = pandemic_merged(:, {'sim_num', 'yr_start', 'ex_post_severity'});
    merged = outerjoin(base_merged, pandemic_keys, 'Keys', {'sim_num', 'yr_start'}, 'Type', 'left', 'MergeKeys', true);
    missing_post = isnan(merged.ex_post_severity);
    merged.ex_post_severity(missing_post) = merged.eff_severity(missing_post);

    ante_severity_matrix = zeros(num_simulations, sim_periods);
    post_severity_matrix = zeros(num_simulations, sim_periods);
    idx = sub2ind(size(ante_severity_matrix), merged.sim_num, merged.yr_start);
    ante_severity_matrix(idx) = merged.eff_severity;
    post_severity_matrix(idx) = merged.ex_post_severity;

    clear base_merged pandemic_merged pandemic_keys merged missing_post;

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

    mean_ante_boot = mean(ante_interp, 1);
    mean_post_boot = mean(post_interp, 1);
    lo_ante = prctile(ante_interp, 5, 1);
    hi_ante = prctile(ante_interp, 95, 1);
    lo_post = prctile(post_interp, 5, 1);
    hi_post = prctile(post_interp, 95, 1);

    % Compute direct exceedance curves from all data (no bootstrap)
    ante_sev_all = ante_severity_matrix(:);
    post_sev_all = post_severity_matrix(:);

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

    % ========== Figure 1: Bootstrap mean ==========
    fig1 = figure('Position', [100 100 900 650]); hold on;

    % Add confidence intervals if requested
    if include_90ci
        plot(x_ribbon, lo_ante, '--', 'LineWidth', 1, 'Color', ex_ante_color, 'HandleVisibility', 'off');
        plot(x_ribbon, hi_ante, '--', 'LineWidth', 1, 'Color', ex_ante_color, 'HandleVisibility', 'off');
        plot(x_ribbon, lo_post, '--', 'LineWidth', 1, 'Color', ex_post_color, 'HandleVisibility', 'off');
        plot(x_ribbon, hi_post, '--', 'LineWidth', 1, 'Color', ex_post_color, 'HandleVisibility', 'off');
    end

    plot(x_ribbon, mean_ante_boot, 'LineWidth', 2, 'Color', ex_ante_color, ...
        'DisplayName', 'Without vaccination');
    plot(x_ribbon, mean_post_boot, 'LineWidth', 2, 'Color', ex_post_color, ...
        'DisplayName', 'With vaccination');
    plot(madhav_severity_central_plot, madhav_exceedance_central_plot, ...
        'LineWidth', 2, 'Color', madhav_color, 'DisplayName', 'Madhav et al. (2023)');

    set(gca, 'XScale', 'log', 'YScale', 'log'); grid on; box off;
    xlabel('Severity (deaths per 10,000)', 'FontSize', 14);
    ylabel('Exceedance probability', 'FontSize', 14);
    title('Exceedance probability curves (Bootstrap mean)', 'FontSize', 15);
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
    print(fig1, fullfile(outdir, sprintf("%s_exceedance_bootstrap_mean%s.png", dirname, ci_suffix)), '-dpng', '-r400');

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
    title('Exceedance probability curves', 'FontSize', 15);

    % Set xlim first so label positions fall inside the visible range
    min_x = max([min(x_ribbon_direct); min(madhav_severity_central_plot(:))]);
    max_x = min([max(x_ribbon_direct); max(madhav_severity_central_plot(:))]);
    xlim([min_x, max_x]);

    % Place line labels at x positions inside the visible range (log-spaced fractions)
    x_ante = 10^(log10(min_x) + 0.4 * (log10(max_x) - log10(min_x)));
    x_post = 10^(log10(min_x) + 0.55 * (log10(max_x) - log10(min_x)));
    y_ante = interp1(x_ribbon_direct, ante_direct, x_ante, 'linear', 'extrap');
    y_post = interp1(x_ribbon_direct, post_direct, x_post, 'linear', 'extrap');
    idx_madhav = min(2, numel(madhav_severity_central_plot));
    text(madhav_severity_central_plot(idx_madhav), madhav_exceedance_central_plot(idx_madhav), ...
        'Madhav et al. (2023) (digitized)', 'FontSize', 11, 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'bottom', 'Color', madhav_color);
    text(x_post, y_post, 'With vaccination', ...
        'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', ex_post_color);
    text(x_ante, y_ante, 'Without vaccination', ...
        'FontSize', 11, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', ex_ante_color);

    legend('off');
    xt = get(gca, 'XTick');
    set(gca, 'XTickLabel', arrayfun(@(x) num2str(round(x), '%.0f'), xt, 'UniformOutput', false));

    % Save figure 2
    print(fig2, fullfile(outdir, sprintf("%s_exceedance_direct.png", dirname)), '-dpng', '-r400');

    % Output mean annual recurrence rates to CSV (using bootstrap mean)
    T = table(common_grid(1:end-1), 1 ./ (mean_ante_boot'), 1 ./ (mean_post_boot'), ...
        'VariableNames', {'severity', 'mean_ante_recurrence', 'mean_post_recurrence'});
    writetable(T, fullfile(outdir, 'mean_annual_recurrence_rates.csv'));

    % Output a smaller table with interpolated values at specific severities
    target_severities = [min(x_ribbon_direct); 4.46; 9.17; 10; 44.6; 50; 100; 150; 171];

    % Get the variables from the table for interpolation
    severity = T.severity;
    mean_ante_recurrence = T.mean_ante_recurrence;
    mean_post_recurrence = T.mean_post_recurrence;

    % Interpolate both columns at requested severities
    interp_mean_ante = interp1(severity, mean_ante_recurrence, target_severities, 'linear', 'extrap');
    interp_mean_post = interp1(severity, mean_post_recurrence, target_severities, 'linear', 'extrap');

    small_T = table(target_severities(:), interp_mean_ante(:), interp_mean_post(:), ...
                    'VariableNames', {'severity', 'mean_ante_recurrence', 'mean_post_recurrence'});

    writetable(small_T, fullfile(outdir, 'mean_annual_recurrence_rates_selected.csv'));
end
