library(forcats)
library(ggplot2)
library(snakecase)
library(tidyverse)

ptrs_preds <- readr::read_csv("output/ptrs/pathogen_model_preds.csv")

## Baseline vaccine PTRS
ptrs_pred_plot <- ptrs_preds %>%
  mutate(
    pathogen = to_sentence_case(gsub("_", " ", pathogen)),
    pathogen = ifelse(pathogen == "Crimean congo hemorrhagic fever", "CCHF", pathogen),
    platform = recode_factor(platform,
                             mrna_only = "mRNA",
                             traditional_only = "Traditional")
  )

# Set color palette for platforms
platform_colors <- c("mRNA" = "#0072B2", "Traditional" = "#D55E00")

# Order pathogens alphabetically for plotting and set platform factor so mRNA is first (top) in plot and legend
ptrs_pred_plot <- ptrs_pred_plot %>%
  mutate(
    pathogen = factor(pathogen, levels = sort(unique(pathogen), decreasing = TRUE)),
    platform = factor(platform, levels = c("Traditional", "mRNA"))
  )

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
    name = "Platform",
    breaks = c("mRNA", "Traditional")
  ) +
  scale_shape_manual(
    values = c("mRNA" = 16, "Traditional" = 17),
    name = "Platform",
    breaks = c("mRNA", "Traditional")
  ) +
  scale_x_continuous(
    limits = c(0, 1),
    labels = scales::percent_format(accuracy = 1, suffix = ""),
    breaks = seq(0, 1, by = 0.1)
  ) +
  labs(
    x = "Probability of technical and regulatory success (%)",
    y = NULL
  ) +
  theme_classic(base_size = 8) +
  theme(
    plot.title = element_text(size = 22, face = "bold", hjust = 0),
    axis.text.y = element_text(size = 14, color = "black"),
    axis.text.x = element_text(size = 12, color = "black"),
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
    legend.position = "right",
    legend.title = element_text(size = 14),
    legend.text = element_text(size = 12)
  )

# Save the plot
ggsave("output/ptrs/marginal_ptrs_by_pathogen.png", ptrs_plot, width = 8, height = 5.5, dpi = 300)
