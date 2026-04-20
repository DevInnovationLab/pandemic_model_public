function spec = get_paper_figure_spec(preset, varargin)
% Return standardized paper figure settings.
%
% Uses named presets for figure dimensions and applies clamped square-root
% scaling for typography relative to the single-column reference width.
%
% Args:
%   preset: Preset name ('single_col', 'double_col', 'tall_panel', 'double_col_tall', 'grid_2xn')
%
% Name-value args:
%   GridCols: Number of columns when preset is 'grid_2xn' (default: 4)
%
% Returns:
%   spec: Struct with width/height in inches, typography, and stroke settings.

    p = inputParser;
    addRequired(p, "preset", @(x) ischar(x) || isstring(x));
    addParameter(p, "GridCols", 4, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    parse(p, preset, varargin{:});

    preset = lower(string(p.Results.preset));
    grid_cols = p.Results.GridCols;

    ref_width = 3.35;

    switch preset
        case "single_col"
            width_in = 3.35;
            height_in = 2.40;
        case "double_col"
            width_in = 6.90;
            height_in = 3.20;
        case "tall_panel"
            width_in = 3.35;
            height_in = 3.40;
        case "double_col_tall"
            width_in = 6.90;
            height_in = 7.80;
        case "grid_2xn"
            width_in = 6.90;
            height_in = 2 * 2.40;
        otherwise
            error("get_paper_figure_spec:UnknownPreset", "Unknown figure preset: %s", preset);
    end

    scale = sqrt(width_in / ref_width);
    scale = min(max(scale, 0.95), 1.15);

    spec = struct();
    spec.preset = char(preset);
    spec.width_in = width_in;
    spec.height_in = height_in;
    spec.font_name = "Arial";
    spec.scale = scale;

    spec.typography = struct( ...
        "tick", round(8.8 * scale, 1), ...
        "axis_label", round(9.8 * scale, 1), ...
        "legend", round(8.8 * scale, 1), ...
        "title", round(9.8 * scale, 1), ...
        "suptitle", round(10.8 * scale, 1));

    spec.stroke = struct( ...
        "primary", 1.6, ...
        "secondary", 1.2, ...
        "reference", 0.6, ...
        "ci_alpha", 0.20, ...
        "ci_alpha_light", 0.17);
end
