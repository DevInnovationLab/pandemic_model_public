# Shared paper figure style helpers for ggplot figures.
#
# Typography uses fixed sizes in paper_base_font_sizes (no width scaling).
# Use theme_paper(font_delta = 1) where noted in plot_ptrs.R and
# plot_arrival_shares.R for slightly larger type on busy horizontal dot plots.

paper_figure_sizes <- list(
  single_col = c(width = 3.35, height = 2.4),
  double_col_standard = c(width = 6.9, height = 4.8),
  double_col_wide = c(width = 6.9, height = 4.2),
  tall_panel = c(width = 3.35, height = 3.4),
  double_col_tall = c(width = 6.9, height = 7),
  grid_2x4 = c(width = 6.9, height = 4.8)
)

paper_base_font_sizes <- list(
  tick = 9,
  axis_label = 10,
  legend = 10,
  title = 12,
  suptitle = 11
)

paper_linewidths <- list(
  primary = 1.6,
  secondary = 1.2,
  reference = 0.6
)

get_paper_size <- function(preset = "single_col") {
  # Return width/height in inches for a named paper figure preset.
  if (!preset %in% names(paper_figure_sizes)) {
    stop(sprintf("Unknown figure preset: %s", preset))
  }
  paper_figure_sizes[[preset]]
}

# Shift all paper font sizes by delta (points). Returns tick, axis_label, legend, title, suptitle.
adjust_paper_typography <- function(delta = 0) {
  list(
    tick = paper_base_font_sizes$tick + delta,
    axis_label = paper_base_font_sizes$axis_label + delta,
    legend = paper_base_font_sizes$legend + delta,
    title = paper_base_font_sizes$title + delta,
    suptitle = paper_base_font_sizes$suptitle + delta
  )
}

paper_typography <- function(delta = 0) {
  # Alias for adjust_paper_typography (backwards compatible name).
  adjust_paper_typography(delta = delta)
}

theme_paper <- function(base_family = "Arial", legend_position = "right", font_delta = 0) {
  # Publication-oriented ggplot theme using fixed base sizes plus optional font_delta.
  typography <- paper_typography(delta = font_delta)
  ggplot2::theme_classic(base_size = typography$tick, base_family = base_family) +
    ggplot2::theme(
      axis.text = ggplot2::element_text(family = base_family, size = typography$tick, color = "black"),
      axis.title.x = ggplot2::element_text(
        family = base_family, size = typography$axis_label, margin = ggplot2::margin(t = 10)
      ),
      axis.title.y = ggplot2::element_text(
        family = base_family, size = typography$axis_label, color = "black", face = "bold"
      ),
      axis.line = ggplot2::element_line(color = "black", linewidth = paper_linewidths$reference),
      axis.ticks = ggplot2::element_line(color = "black", linewidth = paper_linewidths$reference),
      panel.grid.major.x = ggplot2::element_line(color = scales::alpha("black", 0.15), linewidth = paper_linewidths$reference),
 
      panel.grid.minor.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor.y = ggplot2::element_blank(),
      panel.background = ggplot2::element_rect(fill = "white"),
      plot.background = ggplot2::element_rect(fill = "white"),
      legend.position = legend_position,
      legend.text = ggplot2::element_text(family = base_family, size = typography$legend),
      legend.title = ggplot2::element_blank()
    )
}

save_paper_plot <- function(plot, path, preset, dpi = 600, device = cairo_pdf, ...) {
  # Save plot with standardized dimensions and manuscript defaults.
  size <- get_paper_size(preset)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(
    filename = path,
    plot = plot,
    width = size["width"],
    height = size["height"],
    units = "in",
    dpi = dpi,
    device = device,
    ...
  )
}
