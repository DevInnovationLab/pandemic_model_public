library(forcats)
library(ggplot2)
library(snakecase)
library(tidyverse)
library(patchwork)

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

## Baseline vaccine PTRS
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
  scale_x_continuous(
    limits = c(0, 1),
    labels = scales::percent_format(accuracy = 1, suffix = ""),
    breaks = seq(0, 1, by = 0.1)
  ) +
  labs(
    x = "Probability of vaccine success",
    y = NULL
  ) +
  theme_classic(base_size = 8) +
  theme(
    plot.title = element_text(size = 22, face = "bold", hjust = 0),
    axis.text.y = element_text(size = 14, colour = "black"),
    axis.text.x = element_text(size = 12, colour = "black"),
    axis.title.x = element_text(size = 15, margin = margin(t = 10)),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray85", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(10, 0, 10, 10)
  )

# Prototype R&D investment effect plot (second panel)
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
    x = "Increase in probability of vaccine success from prototype",
    y = NULL
  ) +
  theme_classic(base_size = 8) +
  theme(
    plot.title = element_text(size = 22, face = "bold", hjust = 0),
    axis.text.y = element_text(size = 14, colour = "black"),
    axis.text.x = element_text(size = 12, colour = "black"),
    axis.title.x = element_text(size = 15, margin = margin(t = 10)),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray85", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(10, 0, 10, 10)
  )

# Arrange two panels with shared legend on the left, 70/30 vertical split
combined_plot <- (
  ptrs_plot /
    proto_effect_plot
) +
  plot_layout(
    heights = c(0.7, 0.3),
    guides = "collect"
  ) &
  theme(
    legend.position = "right",
    legend.direction = "vertical",
    legend.title = element_blank(),
    legend.text = element_text(size = 12)
  )

# Save the two-panel figure with extra vertical space
ggsave("output/ptrs/marginal_ptrs_by_pathogen.png", combined_plot, width = 8, height = 9, dpi = 600)
