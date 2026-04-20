function apply_paper_axis_style(ax, spec)
% Apply standardized paper axis styling.
%
% Args:
%   ax:   Axes handle.
%   spec: Struct returned by get_paper_figure_spec.

    if nargin < 2
        error("apply_paper_axis_style:MissingSpec", "Provide spec from get_paper_figure_spec.");
    end

    ax.FontName = spec.font_name;
    ax.FontSize = spec.typography.tick;
    ax.LineWidth = spec.stroke.reference;
    ax.GridAlpha = 0.30;
    ax.Box = "off";
    grid(ax, "on");
end
