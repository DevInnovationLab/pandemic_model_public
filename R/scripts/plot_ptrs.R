# plot_ptrs.R — Plot vaccine PTRS by pathogen/platform and prototype effect (two-panel figure).
#
# Produces two figures saved separately:
#   1. Horizontal dot plot of PTRS by pathogen and technology platform with 95% CIs.
#   2. Horizontal dot plot of the prototype R&D effect on PTRS by platform.
# Pathogen ordering follows the arrival-share plot for visual consistency across figures.
#
# Inputs:  output/ptrs/marginal_ptrs_preds.csv
#          output/ptrs/prototype_effect_preds.csv
#          data/clean/arrival_rates_all.csv
# Outputs: output/ptrs/ptrs_plot.pdf
#          output/ptrs/proto_effect_plot.pdf
#
# Run from the repository root.

library(forcats)
library(ggplot2)
library(snakecase)
library(tidyverse)

## --- Load data and derive pathogen ordering -----------------------------------

ptrs_preds <- readr::read_csv("output/ptrs/marginal_ptrs_preds.csv")

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
  theme_classic(base_size = 10, base_family = "Arial") +
  theme(
    axis.text = element_text(size = 13, colour = "black"),
    axis.title = element_text(size = 15),
    axis.title.x = element_text(size = 15, margin = margin(t = 10)),
    axis.title.y = element_text(size = 15, colour = "black", face = "bold"),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(0, 0, 0, 0),
    legend.position = c(0.8, 0.1),
    legend.justification = c(0.5, 0.5),
    legend.background = element_rect(fill = "white", colour = NA),
    legend.title = element_blank(),
    legend.text = element_text(size = 12)
  )

## --- Build prototype effect plot (second panel) -------------------------------
proto_effect <- readr::read_csv("output/ptrs/prototype_effect_preds.csv", show_col_types = FALSE)

proto_effect <- proto_effect %>%
  mutate(
    platform = recode_factor(
      platform,
      mrna_only = "mRNA",
      traditional_only = "Traditional"
    ),
    platform = factor(platform, levels = c("mRNA", "Traditional"))
  )

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
    limits = c(0, 1),
    breaks = seq(0, 1, by = 0.1),
    labels = scales::percent_format(accuracy = 1, suffix = "")
  ) +
  labs(
    x = "Increase in probability of success (ΔPTRS)",
    y = "Technology\nplatform"
  ) +
  theme_classic(base_size = 10, base_family = "Arial") +
  theme(
    axis.text = element_text(size = 13, colour = "black"),
    axis.title = element_text(size = 15),
    axis.title.x = element_text(size = 15, margin = margin(t = 10)),
    axis.title.y = element_text(size = 15, colour = "black", face = "bold"),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(12, 14, 10, 10),
    legend.position = "none"
  )

## --- Save outputs -------------------------------------------------------------
ggsave(
  "output/ptrs/ptrs_plot.pdf",
  ptrs_plot,
  width = 7,
  height = 8,
  units = "in",
  dpi = 600,
  device = cairo_pdf
)

ggsave(
  "output/ptrs/proto_effect_plot.pdf",
  proto_effect_plot,
  width = 7,
  height = 3.5,
  units = "in",
  dpi = 600,
  device = cairo_pdf
)
