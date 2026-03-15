function plot_losses_share(job_dir)
    % Plots share of losses and share of events by pandemic severity bins, along with Lorenz curve
    % Args:
    %   job_dir: Directory containing job configuration and results

    % Load and merge pandemic tables from all chunks
    raw_dir = fullfile(job_dir, "raw");
    chunk_dirs = dir(fullfile(raw_dir, "chunk_*"));
    
    % Preallocate cell array for tables
    pandemic_tables = cell(length(chunk_dirs), 1);
    valid_chunks = 0;
    
    % Load all tables
    for i = 1:length(chunk_dirs)
        chunk_dir = fullfile(raw_dir, chunk_dirs(i).name);
        baseline_file = fullfile(chunk_dir, "baseline_pandemic_table.mat");
        
        S = load(baseline_file);
        valid_chunks = valid_chunks + 1;
        pandemic_tables{valid_chunks} = S.pandemic_table;
    end
    
    % Concatenate all tables
    pandemic_tables = pandemic_tables(1:valid_chunks);
    pandemic_table = vertcat(pandemic_tables{:});
    
    pandemic_table = pandemic_table(~pandemic_table.is_false, :); % Remove false positives

    % Load intensity threshold
    job_config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    response_threshold_dict = yaml.loadFile(job_config.response_threshold_path);
    response_threshold = response_threshold_dict.response_threshold;

    %% Create histogram bins for severity
    severity = pandemic_table.eff_severity;
    pandemic_losses = sum(pandemic_table{:, ["m_mortality_losses", "m_output_losses", "m_learning_losses"]}, 2);
    total_losses = sum(pandemic_losses);

    % Create figure for histograms
    fig1 = figure('Position', [100 100 1000 500]);
    sgtitle('Pandemic severity distribution')

    % Calculate max y value for consistent axis
    max_severity = max(severity);
    num_bins = 10;
    bin_width = (max_severity - response_threshold) / num_bins;
    edges = response_threshold:bin_width:max_severity;
    [counts, edges] = histcounts(severity, edges, 'Normalization', 'probability');
    centers = (edges(1:end-1) + edges(2:end))/2;
    loss_shares = zeros(size(counts));
    for i = 1:length(counts)
        if i < length(counts)
            mask = severity >= edges(i) & severity < edges(i+1);
        else
            mask = severity >= edges(i) & severity <= edges(i+1); % Include rightmost edge in last bin
        end
        loss_shares(i) = sum(pandemic_losses(mask)) / total_losses;
    end
    y_max = max(max(counts), max(loss_shares));

    % Plot share of events
    subplot(1,2,1)
    histogram(severity, edges, 'Normalization', 'probability')
    title('Events')
    ylabel('Share')
    xlabel('Severity (deaths / 10,000)')
    ylim([0 y_max])
    box off
    grid on
    ax = gca;
    ax.GridAlpha = 0.1;

    % Plot share of losses
    subplot(1,2,2)
    bar(centers, loss_shares)
    title('Losses')
    ylabel('Share')
    xlabel('Severity (deaths / 10,000)')
    ylim([0 y_max])
    box off
    grid on
    ax = gca;
    ax.GridAlpha = 0.1;

    % Save bar plots figure
    comparisons_dir = fullfile(job_dir, "figures", "comparison");
    create_folders_recursively(comparisons_dir);
    % Save high resolution figure using print instead of saveas
    print(fig1, fullfile(comparisons_dir, "losses_share_bars.png"), '-dpng', '-r600');
    close(fig1);

    %% Create separate figure for Lorenz curve
    fig2 = figure('Position', [100 100 800 600]);

    % Sort intensities and corresponding losses
    sorted_losses = sort(pandemic_losses);
    cum_event_share = (1:length(sorted_losses))' / length(sorted_losses);
    cum_loss_share = cumsum(sorted_losses) / sum(sorted_losses);
    
    % Add perfect equality line
    plot([0 1], [0 1], '--k', 'LineWidth', 1)
    hold on
    % Plot Lorenz curve
    plot([0; cum_event_share], [0; cum_loss_share], 'b-', 'LineWidth', 2)
    xlabel('Cumulative share of pandemics', 'FontName', 'Arial', 'FontSize', 14)
    ylabel('Cumulative share of social losses', 'FontName', 'Arial', 'FontSize', 14)
    ylim([0 1])
    box off
    grid on
    ax = gca;
    ax.GridAlpha = 0.3;

    % Save high resolution figure using print instead of saveas
    print(fig2, fullfile(comparisons_dir, "losses_share_lorenz.png"), '-dpng', '-r600');
    close(fig2);
end
