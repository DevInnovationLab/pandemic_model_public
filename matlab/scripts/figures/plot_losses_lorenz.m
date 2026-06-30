function plot_losses_lorenz(job_dir, varargin)
    % Plot Lorenz curve for unmitigated pandemic losses (greatest to least harm).
    %
    % By default plots flat time weights only. Set IncludeDiscounted true to also write
    % a discounted figure and an overlay with both series.
    %
    % Args:
    %   job_dir: Directory containing unmitigated_losses.mat.
    %
    % Name-value:
    %   IncludeDiscounted: If true, also save discounted and overlay Lorenz PDFs (default: false).
    %
    % Saves figures/unmitigated_losses_lorenz_flat.pdf and, when requested,
    % unmitigated_losses_lorenz_discounted.pdf and unmitigated_losses_lorenz.pdf.

    p = inputParser;
    addParameter(p, "IncludeDiscounted", false, @islogical);
    parse(p, varargin{:});

    losses_file = fullfile(job_dir, "unmitigated_losses.mat");
    figdir = fullfile(job_dir, "figures");
    create_folders_recursively(figdir);

    y_label = "Cumulative share of social losses";

    S = load(losses_file, "outbreak_total_usd_flat_weights");
    flat_losses = S.outbreak_total_usd_flat_weights;
    plot_and_export_lorenz(flat_losses, y_label, fullfile(figdir, "unmitigated_losses_lorenz_flat.pdf"));

    if p.Results.IncludeDiscounted
        S = load(losses_file, "outbreak_total_usd_social_pv");
        pv_losses = S.outbreak_total_usd_social_pv;
        plot_and_export_lorenz(pv_losses, y_label, fullfile(figdir, "unmitigated_losses_lorenz_discounted.pdf"));
        plot_and_export_lorenz_together(flat_losses, pv_losses, y_label, fullfile(figdir, "unmitigated_losses_lorenz.pdf"));
    end
end

function plot_and_export_lorenz(pandemic_losses, y_label, out_path)
    [cum_event_share, cum_loss_share] = lorenz_coords(pandemic_losses);

    spec = get_paper_figure_spec("double_col_standard");
    fig = figure("Units", "inches", "Position", [1 1 spec.width_in spec.height_in]);
    plot(cum_event_share, cum_loss_share, "-", "LineWidth", spec.stroke.primary);
    hold on;
    plot([0 1], [0 1], "--k", "LineWidth", spec.stroke.reference);
    xlabel("Cumulative share of pandemics", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    ylabel(y_label, "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    xlim([0 1]);
    ylim([0 1]);
    xticks(0:0.2:1);
    yticks(0:0.2:1);
    apply_paper_axis_style(gca, spec);
    export_figure(fig, out_path);
    close(fig);
end

function plot_and_export_lorenz_together(flat_losses, pv_losses, y_label, out_path)
    [x_flat, y_flat] = lorenz_coords(flat_losses);
    [x_pv, y_pv] = lorenz_coords(pv_losses);

    spec = get_paper_figure_spec("double_col_standard");
    fig = figure("Units", "inches", "Position", [1 1 spec.width_in spec.height_in]);
    ax = axes(fig);
    co = colororder(ax);
    plot(ax, x_flat, y_flat, "-", "Color", co(1, :), "LineWidth", spec.stroke.primary);
    hold(ax, "on");
    plot(ax, x_pv, y_pv, "--", "Color", co(2, :), "LineWidth", spec.stroke.primary);
    plot(ax, [0 1], [0 1], "--k", "LineWidth", spec.stroke.reference);
    xlabel(ax, "Cumulative share of pandemics", "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    ylabel(ax, y_label, "FontName", spec.font_name, "FontSize", spec.typography.axis_label);
    xlim(ax, [0 1]);
    ylim(ax, [0 1]);
    xticks(ax, 0:0.2:1);
    yticks(ax, 0:0.2:1);
    apply_paper_axis_style(ax, spec);
    export_figure(fig, out_path);
    close(fig);
end

function [cum_event_share, cum_loss_share] = lorenz_coords(pandemic_losses)
    losses = pandemic_losses(:);
    losses = losses(isfinite(losses));
    sorted_losses = sort(losses, "descend");
    n = numel(sorted_losses);
    cum_event_share = [0; (1:n)' / n];
    cum_loss_share = [0; cumsum(sorted_losses) / sum(sorted_losses)];
end
