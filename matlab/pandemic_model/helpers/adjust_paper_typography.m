function spec = adjust_paper_typography(spec, delta)
% Shift all paper typography sizes on a spec by delta (points).
%
% Args:
%   spec: Struct from get_paper_figure_spec.
%   delta: Numeric scalar added to tick, axis_label, legend, title, and suptitle.
%
% Returns:
%   spec: Updated struct (same fields as input).

    if nargin < 2
        error("adjust_paper_typography:MissingArgs", "Provide spec and delta.");
    end

    spec.typography.tick = spec.typography.tick + delta;
    spec.typography.axis_label = spec.typography.axis_label + delta;
    spec.typography.legend = spec.typography.legend + delta;
    spec.typography.title = spec.typography.title + delta;
    spec.typography.suptitle = spec.typography.suptitle + delta;
end
