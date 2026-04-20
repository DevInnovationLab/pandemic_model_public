# Shared paper figure style helpers for ggplot figures.

paper_figure_sizes <- list(
  single_col = c(width = 3.35, height = 2.4),
  double_col = c(width = 6.9, height = 3.2),
  tall_panel = c(width = 3.35, height = 3.4),
  double_col_tall = c(width = 6.9, height = 7.8),
  grid_2x4 = c(width = 6.9, height = 4.8)
)

paper_base_font_sizes <- list(
  tick = 8.8,
  axis_label = 9.8,
  legend = 8.8,
  title = 9.8,
  suptitle = 10.8
)

paper_linewidths <- list(
  primary = 1.6,
  secondary = 1.2,
  reference = 0.6
)

paper_text_scale <- function(width_in, ref_width_in = 3.35, min_scale = 0.95, max_scale = 1.15) {
  # Return clamped square-root text scaling by figure width.
  scale <- sqrt(width_in / ref_width_in)
  pmin(pmax(scale, min_scale), max_scale)
}

get_paper_size <- function(preset = "single_col") {
  # Return width/height in inches for a named paper figure preset.
  if (!preset %in% names(paper_figure_sizes)) {
    stop(sprintf("Unknown figure preset: %s", preset))
  }
  paper_figure_sizes[[preset]]
}

paper_typography <- function(width_in) {
  # Return scaled font sizes for manuscript figures.
  scale <- as.numeric(paper_text_scale(width_in = width_in))
  list(
    tick = round(paper_base_font_sizes$tick * scale, 1),
    axis_label = round(paper_base_font_sizes$axis_label * scale, 1),
    legend = round(paper_base_font_sizes$legend * scale, 1),
    title = round(paper_base_font_sizes$title * scale, 1),
    suptitle = round(paper_base_font_sizes$suptitle * scale, 1)
  )
}

theme_paper <- function(width_in, base_family = "Arial", legend_position = "right") {
  # Return a publication-oriented ggplot theme with scaled typography.
  typography <- paper_typography(width_in = width_in)
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
      panel.grid.major.x = ggplot2::element_line(color = "gray", linewidth = paper_linewidths$reference),
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
