library(forcats)
library(ggplot2)
library(snakecase)
library(tidyverse)

# Read in prototype effect estimates
proto_effect <- readr::read_csv("output/ptrs/prototype_effect_preds.csv", show_col_types = FALSE)

# Clean up platform names for plotting
proto_effect <- proto_effect %>%
  mutate(
    platform = recode_factor(
      platform,
      mrna_only = "mRNA",
      traditional_only = "Traditional"
    ),
    platform = factor(platform, levels = c("Traditional", "mRNA"))
  )

# Set color palette for platforms
platform_colors <- c("mRNA" = "#0072B2", "Traditional" = "#D55E00")

# Plot the effect of prototype R&D investment by platform
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
    x = "Increase in probability of vaccine success",
    y = "Technology platform"
  ) +
  theme_classic(base_size = 8) +
  theme(
    plot.title = element_text(size = 22, face = "bold", hjust = 0),
    axis.text.y = element_text(size = 14),
    axis.text.x = element_text(size = 12),
    axis.title.x = element_text(size = 16, margin = margin(t = 10)),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray85", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.margin = margin(10, 0, 10, 10),
    legend.position = c(0.98, 0.02),
    legend.justification = c("right", "bottom"),
    legend.background = element_rect(fill = "white", colour = "white"),
    legend.title = element_blank(),
    legend.text = element_text(size = 12)
  )

# Save the plot
ggsave("output/ptrs/prototype_invest_effect.png", proto_effect_plot, width = 7, height = 3.5, dpi = 600)