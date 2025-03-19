function plot_losses_share(job_dir)
    % Plots share of losses and share of events by pandemic severity bins, along with Lorenz curve
    % Args:
    %   job_dir: Directory containing job configuration and results

    % Load pandemic table
    pandemic_table = readtable(fullfile(job_dir, "raw", "baseline_pandemic_table.csv"));
    pandemic_table = pandemic_table(~pandemic_table.is_false, :); % Remove false positives

    % Create logarithmic bins in base 10 for severity
    intensity = pandemic_table.intensity;
    % Get min and max values
    min_val = min(intensity);
    max_val = max(intensity);
    
    % Create 5 logarithmic bins between min and max
    bin_edges = logspace(log10(min_val), log10(max_val), 6);
    [~, ~, bin_indices] = histcounts(intensity, bin_edges);

    % Calculate share of events in each bin
    event_counts = histcounts(intensity, bin_edges, 'Normalization', 'probability');

    % Calculate share of losses in each bin
    pandemic_losses = sum(pandemic_table{:, ["m_mortality_losses", "m_output_losses", "m_learning_losses"]}, 2);
    total_losses = sum(pandemic_losses);
    loss_shares = zeros(1, length(bin_edges)-1);
    for i = 1:length(bin_edges)-1
        bin_mask = bin_indices == i;
        loss_shares(i) = sum(pandemic_losses(bin_mask)) / total_losses;
    end

    % Create bin labels with decimal notation for smaller numbers and scientific for larger
    bin_labels = cell(length(bin_edges)-1, 1);
    for i = 1:length(bin_edges)-1
        if bin_edges(i) < 0.01 || bin_edges(i) >= 10000
            label_start = sprintf('%.1e', bin_edges(i));
        else
            % Only use as many decimals as needed
            if bin_edges(i) == floor(bin_edges(i))
                label_start = sprintf('%.0f', bin_edges(i));
            elseif bin_edges(i) * 10 == floor(bin_edges(i) * 10)
                label_start = sprintf('%.1f', bin_edges(i));
            else
                label_start = sprintf('%.2f', bin_edges(i));
            end
        end
        
        if bin_edges(i+1) < 0.01 || bin_edges(i+1) >= 10000 % Scientific notation
            label_end = sprintf('%0.0f×10^%d', bin_edges(i+1)/10^floor(log10(bin_edges(i+1))), floor(log10(bin_edges(i+1))));
        else
            % Only use as many decimals as needed
            if bin_edges(i+1) == floor(bin_edges(i+1))
                label_end = sprintf('%.0f', bin_edges(i+1));
            elseif bin_edges(i+1) * 10 == floor(bin_edges(i+1) * 10)
                label_end = sprintf('%.1f', bin_edges(i+1));
            else
                label_end = sprintf('%.2f', bin_edges(i+1));
            end
        end
        
        bin_labels{i} = sprintf('%s - %s', label_start, label_end);
    end
    
    % Ensure bins are ordered by size (smallest to largest)
    % Convert to categorical with explicit ordering
    bin_labels_cat = categorical(bin_labels);
    bin_labels_cat = reordercats(bin_labels_cat, bin_labels);

    % Create figure for bar plots
    fig1 = figure('Position', [100 100 1000 500]);

    % Plot share of events
    subplot(1,2,1)
    b1 = bar(bin_labels_cat, event_counts);
    title('Share of events by intensity')
    ylabel('Share of events')
    xlabel('Intensity (deaths / 10,000 / year)')
    xtickangle(45)
    box off
    grid on
    ax = gca;
    ax.GridAlpha = 0.1;

    % Plot share of losses 
    subplot(1,2,2)
    b2 = bar(bin_labels_cat, loss_shares);
    title('Share of losses by intensity')
    ylabel('Share of losses')
    xlabel('Intensity (deaths / 10,000 / year)')
    xtickangle(45)
    box off
    grid on
    ax = gca;
    ax.GridAlpha = 0.1;

    % Save bar plots figure
    comparisons_dir = fullfile(job_dir, "figures", "comparison");
    create_folders_recursively(comparisons_dir);
    % Save high resolution figure using print instead of saveas
    print(fig1, fullfile(comparisons_dir, "losses_share_bars.png"), '-dpng', '-r450');
    close(fig1);

    % Create separate figure for Lorenz curve
    fig2 = figure('Position', [100 100 800 600]);

    % Sort intensities and corresponding losses
    sorted_losses = sort(pandemic_losses);
    cum_event_share = (1:length(sorted_losses))' / length(sorted_losses);
    cum_loss_share = cumsum(sorted_losses) / sum(sorted_losses);
    
    % Calculate Gini coefficient
    % Gini = A/(A+B) where A is area between Lorenz curve and equality line
    % and A+B is total area under equality line (0.5)
    area_under_lorenz = trapz([0; cum_event_share], [0; cum_loss_share]);
    gini = 1 - 2*area_under_lorenz;
    
    % Add perfect equality line
    plot([0 1], [0 1], '--k', 'LineWidth', 1)
    hold on
    % Plot Lorenz curve
    plot([0; cum_event_share], [0; cum_loss_share], 'b-', 'LineWidth', 2)
    title(sprintf('Lorenz curve for pandemic losses\nGini coefficient: %.2f', gini))
    xlabel('Cumulative share of events')
    ylabel('Cumulative share of losses')
    ylim([0 1])
    box off
    grid on
    ax = gca;
    ax.GridAlpha = 0.1;

    % Save high resolution figure using print instead of saveas
    print(fig2, fullfile(comparisons_dir, "losses_share_lorenz.png"), '-dpng', '-r450');
    close(fig2);
end
