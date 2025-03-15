function plot_losses_share(job_dir)
    % Plots share of losses and share of events by pandemic severity bins
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
    
    % Get powers of 10 between min and max
    min_exp = ceil(log10(min_val));
    max_exp = floor(log10(max_val));
    
    % Create edges array starting with min value, then powers of 10, then max value
    bin_edges = [min_val, 10.^(min_exp:max_exp), max_val];
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
    % Convert to categorical and preserve order
    bin_labels = categorical(bin_labels, 'Ordinal', true);

    % Create figure
    fig = figure('Position', [100 100 1200 500]);

    % Plot share of events
    subplot(1,2,1)
    barh(bin_labels, event_counts)
    title('Share of events by intensity')
    xlabel('Share of events')
    ylabel('Intensity (deaths / 10,000 / year)')
    grid on

    % Plot share of losses 
    subplot(1,2,2)
    barh(bin_labels, loss_shares)
    title('Share of losses by intensity')
    xlabel('Share of losses')
    ylabel('Intensity (deaths / 10,000 / year)')
    grid on

    % Save figure
    comparisons_dir = fullfile(job_dir, "figures", "comparison");
    create_folders_recursively(comparisons_dir);
    saveas(fig, fullfile(comparisons_dir, "losses_share.png"));
    close(fig);
end
