# plot_ptrs.R — Plot vaccine PTRS by pathogen/platform and prototype effect (two-panel figure).
#
# Produces two figures saved separately:
#   1. Horizontal dot plot of PTRS by pathogen and technology platform with 95% CIs.
#   2. Horizontal dot plot of the prototype R&D effect on PTRS by platform.
# Pathogen ordering follows the arrival-share plot for visual consistency across figures.
#
# Inputs:  data/derived/marginal_ptrs_preds.csv
#          data/clean/prototype_effect_preds.csv
#          data/clean/arrival_rates_all.csv
# Outputs: output/ptrs/ptrs_plot.pdf
#          output/ptrs/proto_effect_plot.pdf
#
# Run from the repository root.

library(forcats)
library(ggplot2)
library(snakecase)
library(tidyverse)
source("R/scripts/paper_figure_style.R")

## --- Load data and derive pathogen ordering -----------------------------------

ptrs_preds <- readr::read_csv("data/derived/marginal_ptrs_preds.csv")

arrival_risk_summary_all <- readr::read_csv("./data/clean/arrival_rates_all.csv")

# Derive pathogen ordering from arrival risk plot
arrival_pathogen_order <- arrival_risk_summary_all %>%
  mutate(
    pathogen = to_sentence_case(gsub("_", " ", pathogen)),
    pathogen = ifelse(grepl("crimean", pathogen, ignore.case = TRUE), "CCHF", pathogen)
  ) %>%
  group_by(pathogen) %>%
  summarise(estimate = mean(estimate, na.rm = TRUE), .groups = "drop") %>%
  arrange(estimate) %>%
  pull(pathogen)

## --- Build PTRS plot ----------------------------------------------------------
ptrs_pred_plot <- ptrs_preds %>%
  mutate(
    pathogen = to_sentence_case(gsub("_", " ", pathogen)),
    pathogen = ifelse(pathogen == "Crimean congo hemorrhagic fever", "CCHF", pathogen),
    platform = recode_factor(
      platform,
      mrna_only = "mRNA",
      traditional_only = "Traditional"
    )
  ) %>%
  mutate(
    pathogen = factor(pathogen, levels = arrival_pathogen_order),
    platform = factor(platform, levels = c("mRNA", "Traditional"))
  )

# Set color palette for platforms
platform_colors <- c("mRNA" = "#0072B2", "Traditional" = "#D55E00")

ptrs_panel_delta <- 4
ptrs_ty <- paper_typography(delta = ptrs_panel_delta)
# Axis titles one point larger than ptrs_ty$axis_label (ticks/legend stay at ptrs_panel_delta).
ptrs_axis_title_size <- ptrs_ty$axis_label + 1

ptrs_plot <- ggplot(ptrs_pred_plot, aes(
  x = mu_hat,
  y = pathogen,
  color = platform,
  shape = platform
)) +
  geom_point(size = 4, position = position_dodge(width = 0.6)) +
  geom_errorbarh(
    aes(xmin = lo95, xmax = hi95),
    height = 0.2,
    linewidth = 0.6,
    position = position_dodge(width = 0.6),
    alpha = 0.8
  ) +
  scale_color_manual(
    values = platform_colors,
    name = NULL,
    breaks = c("Traditional", "mRNA")
  ) +
  scale_shape_manual(
    values = c("mRNA" = 16, "Traditional" = 17),
    name = NULL,
    breaks = c("Traditional", "mRNA")
  ) +
  scale_y_discrete(
    labels = function(x) if_else(tolower(x) == "cchf", "CCHF", tools::toTitleCase(tolower(x)))
  ) +
  scale_x_continuous(
    limits = c(0, 1),
    labels = scales::percent_format(accuracy = 1, suffix = ""),
    breaks = seq(0, 1, by = 0.1)
  ) +
  labs(
    x = "Probability of vaccine success (PTRS)",
    y = "Pathogen"
  ) +
  # font_delta = ptrs_panel_delta: slightly larger type than default (busy dot + errorbar chart).
  theme_paper(base_family = "Arial", font_delta = ptrs_panel_delta) +
  theme(
    axis.title.x = element_text(size = ptrs_axis_title_size),
    axis.title.y = element_text(size = ptrs_axis_title_size),
    plot.margin = margin(0, 0, 0, 0),
    legend.position = c(0.8, 0.1),
    legend.justification = c(0.5, 0.5),
    legend.background = element_rect(fill = "white", colour = NA)
  )

## --- Build prototype effect plot (second panel) -------------------------------
proto_effect <- readr::read_csv("data/clean/prototype_effect_preds.csv", show_col_types = FALSE)

proto_effect <- proto_effect %>%
  mutate(
    platform = recode_factor(
      platform,
      mrna_only = "mRNA",
      traditional_only = "Traditional"
    ),
    platform = factor(platform, levels = c("mRNA", "Traditional"))
  )

proto_panel_delta <- 4
proto_ty <- paper_typography(delta = proto_panel_delta)
proto_axis_title_size <- proto_ty$axis_label + .5

proto_effect_plot <- ggplot(proto_effect, aes(
  x = effect_mean,
  y = platform,
  color = platform,
  shape = platform
)) +
  geom_point(size = 4, position = position_dodge(width = 0.6)) +
  geom_errorbarh(
    aes(xmin = effect_lo95, xmax = effect_hi95),
    height = 0.2,
    linewidth = 0.6,
    position = position_dodge(width = 0.6),
    alpha = 0.8
  ) +
  scale_color_manual(
    values = platform_colors,
    name = NULL,
    breaks = c("Traditional", "mRNA")
  ) +
  scale_shape_manual(
    values = c("mRNA" = 16, "Traditional" = 17),
    name = NULL,
    breaks = c("Traditional", "mRNA")
  ) +
  scale_x_continuous(
    limits = c(-.04, 1),
    breaks = seq(0, 1, by = 0.1),
    labels = scales::percent_format(accuracy = 1, suffix = "")
  ) +
  labs(
    x = "Increase in probability of success (ΔPTRS)",
    y = "Technology\nplatform"
  ) +
  theme_paper(base_family = "Arial", font_delta = proto_panel_delta) +
  theme(
    axis.title.x = element_text(size = proto_axis_title_size),
    axis.title.y = element_text(size = proto_axis_title_size),
    plot.margin = margin(12, 14, 10, 10),
    legend.position = "none"
  )

## --- Save outputs -------------------------------------------------------------
save_paper_plot(
  plot = ptrs_plot,
  path = "output/ptrs_plot.pdf",
  preset = "double_col_tall",
  dpi = 600
)

save_paper_plot(
  plot = proto_effect_plot,
  path = "output/proto_effect_plot.pdf",
  preset = "double_col_wide",
  dpi = 600
)
