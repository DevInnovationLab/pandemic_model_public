function plot_losses_lorenz(job_dir)
    % Plot Lorenz curve for unmitigated pandemic losses (greatest to least harm).
    %
    % Args:
    %   job_dir: Directory containing unmitigated_losses.mat from
    %            estimate_unmitigated_losses (aggregated across chunks).
    %
    % Excludes false-positive outbreaks. Saves figures/comparison/unmitigated_losses_lorenz.pdf.

    losses_file = fullfile(job_dir, "unmitigated_losses.mat");
    if ~isfile(losses_file)
        error("plot_losses_lorenz:NoUnmitigatedFile", ...
            "Expected unmitigated_losses.mat in %s. Run estimate_unmitigated_losses first.", job_dir);
    end

    S = load(losses_file, "outbreak_total_loss", "outbreak_is_false_positive");
    if ~isfield(S, "outbreak_total_loss") || ~isfield(S, "outbreak_is_false_positive")
        error("plot_losses_lorenz:MissingOutbreakFields", ...
            "unmitigated_losses.mat in %s does not contain outbreak_total_loss and outbreak_is_false_positive.", job_dir);
    end

    outbreak_total_loss = S.outbreak_total_loss(:);
    outbreak_is_false_positive = logical(S.outbreak_is_false_positive(:));

    if numel(outbreak_total_loss) ~= numel(outbreak_is_false_positive)
        error("plot_losses_lorenz:SizeMismatch", ...
            "outbreak_total_loss and outbreak_is_false_positive must have the same length.");
    end

    pandemic_losses = outbreak_total_loss(~outbreak_is_false_positive);
    pandemic_losses = pandemic_losses(isfinite(pandemic_losses));
    total_losses = sum(pandemic_losses);
    if total_losses <= 0
        warning("plot_losses_lorenz:NonPositiveLosses", ...
            "Total losses are non-positive (%g). Lorenz curve may be invalid.", total_losses);
        total_losses = max(total_losses, 1);
    end

    sorted_losses = sort(pandemic_losses, "descend");
    n = numel(sorted_losses);
    cum_event_share = (1:n)' / n;
    cum_loss_share = cumsum(sorted_losses) / total_losses;

    spec = get_paper_figure_spec("single_col");
    fig = figure("Units", "inches", "Position", [1 1 spec.width_in spec.height_in]);

    plot([0 1], [0 1], "--k", "LineWidth", spec.stroke.reference);
    hold on;
    plot([0; cum_event_share], [0; cum_loss_share], "b-", "LineWidth", spec.stroke.primary);

    xlabel("Cumulative share of pandemics", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    ylabel("Cumulative share of social losses", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);

    xlim([0 1]);
    ylim([0 1]);
    xticks(0:0.2:1);
    yticks(0:0.2:1);

    ax = gca;
    apply_paper_axis_style(ax, spec);

    comparisons_dir = fullfile(job_dir, "figures", "comparison");
    create_folders_recursively(comparisons_dir);
    export_figure(fig, fullfile(comparisons_dir, "unmitigated_losses_lorenz.pdf"));
    close(fig);
end
