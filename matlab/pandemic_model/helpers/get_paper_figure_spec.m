function spec = get_paper_figure_spec(preset, varargin)
% Return standardized paper figure settings.
%
% Named presets set figure dimensions; typography uses fixed point sizes (no
% width scaling). Use adjust_paper_typography after this function to shift all
% font sizes together if needed.
%
% Args:
%   preset: Preset name ('single_col', 'double_col_standard', 'double_col_wide', 'tall_panel', 'double_col_tall', 'grid_2xn')
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

    switch preset
        case "single_col"
            width_in = 3.35;
            height_in = 2.40;
        case "double_col_standard"
            width_in = 6.90;
            height_in = 4.80;
        case "double_col_wide"
            width_in = 6.90;
            height_in = 4.20;
        case "tall_panel"
            width_in = 3.35;
            height_in = 3.40;
        case "double_col_tall"
            width_in = 6.90;
            height_in = 7;
        case "grid_2xn"
            width_in = 6.90;
            height_in = 2 * 2.40;
        otherwise
            error("get_paper_figure_spec:UnknownPreset", "Unknown figure preset: %s", preset);
    end

    spec = struct();
    spec.preset = char(preset);
    spec.width_in = width_in;
    spec.height_in = height_in;
    spec.font_name = "Arial";

    spec.typography = struct( ...
        "tick", 9, ...
        "axis_label", 10, ...
        "legend", 10, ...
        "title", 12, ...
        "suptitle", 11);

    spec.stroke = struct( ...
        "primary", 1.6, ...
        "secondary", 1.2, ...
        "reference", 0.6, ...
        "ci_alpha", 0.20, ...
        "ci_alpha_light", 0.17);
end
