# Paper figure style specification

This document defines a shared figure style system for manuscript-ready plots across MATLAB, Python, and R scripts in this repository.

## Size presets (inches)

- `single_col`: 3.35 x 2.40
- `double_col`: 6.90 x 3.20
- `tall_panel`: 3.35 x 3.40
- `double_col_tall`: 6.90 x 7.80
- `grid_2xN(n_cols)`: width = `double_col.width`, height = `2 * single_col.height`

These dimensions are intended for standard academic two-column formats while allowing different panel layouts.

## Typography hierarchy (point sizes at reference width)

Reference width is `single_col.width = 3.35 in`.

- Tick labels: `8.8 pt`
- Axis labels: `9.8 pt`
- Legend text: `8.8 pt`
- Panel title: `9.8 pt`
- Figure-level title/sup-label: `10.8 pt`

Font family:
- Primary: `Arial`
- Fallbacks are language/runtime-specific where needed.

## Scale rule across dimensions

To keep text visually uniform while figure widths vary:

- `scale = clamp(sqrt(fig_width_in / ref_width_in), 0.95, 1.15)`
- `effective_size = round(base_size * scale, 1)`

This keeps larger panels readable without creating oversized typography.

## Stroke hierarchy

- Primary data line: `1.6 pt`
- Secondary data line: `1.2 pt`
- Reference/grid line: `0.6 pt`
- CI fill alpha:
  - Broad interval fills: `0.20`
  - Lighter comparison band: `0.17`

## Export defaults

- Primary manuscript output: vector PDF
- Optional raster companion: PNG at `600 DPI`
- Tight bounding box/padding and explicit background (white unless transparency is required)

## Labeling policy

- Use sentence case for axis labels, titles, legends, and table/figure text.
- Keep semantic styling consistent:
  - MLE or principal series uses primary stroke.
  - Confidence intervals/bands use fixed alpha and secondary styling.
