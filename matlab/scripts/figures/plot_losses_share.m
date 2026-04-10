function plot_losses_share(job_dir)
    % Plot Lorenz curve for pandemic losses from unmitigated outbreak totals.
    %
    % Args:
    %   job_dir: Directory containing unmitigated_losses.mat produced by
    %            estimate_unmitigated_losses (aggregated across chunks).
    %
    % Notes:
    %   - Only outbreaks that are not false positives are included
    %     (filters by outbreak_is_false from unmitigated_losses.mat).
    %   - The Lorenz curve is ordered from greatest harm to least harm.

    losses_file = fullfile(job_dir, "unmitigated_losses.mat");
    if ~isfile(losses_file)
        error("plot_losses_share:NoUnmitigatedFile", ...
            "Expected unmitigated_losses.mat in %s. Run estimate_unmitigated_losses first.", job_dir);
    end

    S = load(losses_file, "outbreak_total_loss", "outbreak_is_false_positive");
    if ~isfield(S, "outbreak_total_loss") || ~isfield(S, "outbreak_is_false_positive")
        error("plot_losses_share:MissingOutbreakFields", ...
            "unmitigated_losses.mat in %s does not contain outbreak_total_loss and outbreak_is_false_positive.", job_dir);
    end

    outbreak_total_loss = S.outbreak_total_loss(:);
    outbreak_is_false_positive = logical(S.outbreak_is_false_positive(:));

    if numel(outbreak_total_loss) ~= numel(outbreak_is_false_positive)
        error("plot_losses_share:SizeMismatch", ...
            "outbreak_total_loss and outbreak_is_false_positive must have the same length.");
    end

    % Exclude false positives explicitly
    pandemic_losses = outbreak_total_loss(~outbreak_is_false_positive);

    % Filter non-finite or zero-sum cases gracefully
    pandemic_losses = pandemic_losses(isfinite(pandemic_losses));
    total_losses = sum(pandemic_losses);
    if total_losses <= 0
        warning("plot_losses_share:NonPositiveLosses", ...
            "Total losses are non-positive (%g). Lorenz curve may be invalid.", total_losses);
        total_losses = max(total_losses, 1);
    end

    % Sort losses from greatest harm to least harm
    sorted_losses = sort(pandemic_losses, "descend");

    % Cumulative shares
    [cum_event_share, cum_loss_share] = compute_lorenz(sorted_losses, total_losses);

    % Create Lorenz curve figure
    fig = figure("Position", [100 100 800 600]);

    % Equality line
    plot([0 1], [0 1], "--k", "LineWidth", 1);
    hold on;

    % Lorenz curve ordered from greatest to least harm
    plot([0; cum_event_share], [0; cum_loss_share], "b-", "LineWidth", 2);

    xlabel("Cumulative share of pandemics", "FontName", "Arial", "FontSize", 14);
    ylabel("Cumulative share of social losses", "FontName", "Arial", "FontSize", 14);

    xlim([0 1]);
    ylim([0 1]);
    xticks(0:0.2:1);
    yticks(0:0.2:1);

    box off;
    grid on;
    ax = gca;
    ax.GridAlpha = 0.3;

    % Save Lorenz curve as a tight vector PDF
    comparisons_dir = fullfile(job_dir, "figures", "comparison");
    create_folders_recursively(comparisons_dir);
    exportgraphics(fig, fullfile(comparisons_dir, "losses_share_lorenz.pdf"), ...
        "ContentType", "vector", "Resolution", 600, "BackgroundColor", "none");
    close(fig);
end

function [cum_event_share, cum_loss_share] = compute_lorenz(sorted_losses, total_losses)
    % Compute cumulative shares for a Lorenz curve from sorted losses.
    num_events = numel(sorted_losses);
    cum_event_share = (1:num_events)' / num_events;
    cum_loss_share = cumsum(sorted_losses) / total_losses;
end
