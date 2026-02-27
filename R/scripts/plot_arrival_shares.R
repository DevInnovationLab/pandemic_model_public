library(forcats)
library(ggplot2)
library(snakecase)
library(tidyverse)

arrival_risk_summary_all <- readr::read_csv("./data/clean/arrival_rates_all.csv")

# Prepare data for plotting: clean up labels and prototype status
arrival_risk_plot <- arrival_risk_summary_all %>%
  mutate(
    has_prototype = ifelse(is.na(has_prototype), FALSE, has_prototype),
    has_prototype = ifelse(has_prototype, "Has prototype", "No prototype"),
    pathogen = to_sentence_case(gsub("_", " ", pathogen)),
    pathogen = ifelse(grepl("crimean", pathogen, ignore.case = TRUE), "CCHF", pathogen)
  )

prototype_colors <- c("Has prototype" = "#005185", "No prototype" = "#A50021") # blue and red


# Reduce the vertical spacing by shrinking the plot height and point size
p <- ggplot(arrival_risk_plot, aes(
  x = estimate,
  y = reorder(pathogen, estimate),
  color = has_prototype
)) +
  geom_point(size = 4) +
  geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper, color = has_prototype),
                 height = 0.2,
                 linewidth = 0.6,
                 alpha = 0.8) +
  scale_color_manual(
    name = "Prototype vaccine",
    values = prototype_colors
  ) +
  scale_x_continuous(
    limits = c(0, 0.5),
    labels = scales::percent_format(accuracy = 1),
    breaks = seq(0, 0.5, by = 0.05)
  ) +
  labs(
    x = "Share of expected pandemic outbreaks",
    y = NULL,
    color = "Prototype vaccine",
    caption = NULL
  ) +
  theme_classic(base_size = 8) +
  theme(
    plot.title = element_text(size = 22, face = "bold", hjust = 0),
    plot.subtitle = element_text(size = 14, color = "gray40", hjust = 0, margin = margin(b = 10)),
    plot.caption = element_text(size = 10, color = "gray50", hjust = 0, margin = margin(t = 5)),
    axis.text.y = ggtext::element_markdown(
      size = 14,
      face = "plain",
      color = arrival_risk_plot %>%
        arrange(estimate) %>%
        mutate(color = ifelse(has_prototype == "Has prototype", prototype_colors["Has prototype"], prototype_colors["No prototype"])) %>%
        pull(color)
    ),
    axis.text.x = element_text(size = 12, color = "black"),
    axis.title.x = element_text(size = 16,  margin = margin(t = 10)),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray85", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    legend.position = c(0.5, 0.2), # place legend inside, top right above grid
    legend.justification = c("left", "top"),
    legend.direction = "horizontal",
    legend.background = element_rect(fill = alpha("white", 0.9), color = NA),
    legend.title = element_text(size = 14, face = "bold"),
    legend.text = element_text(size = 12),
    legend.key.size = unit(1.1, "lines"),
    legend.box.margin = margin(0, 0, 0, 0),
    plot.margin = margin(10, 0, 10, 10)
  ) +
  guides(color = guide_legend(title.position = "top", title.hjust = 0.5, nrow = 1, byrow = TRUE, override.aes = list(size = 3)))

# Reduce the plot height to bring points closer together
ggsave("./output/pathogen_pandemic_share_all.png", plot = p, width = 10, height = 6, dpi = 600)

# Also produce a similar plot without coloring by `has_prototype`
p_nocolor <- ggplot(arrival_risk_plot, aes(
  x = estimate,
  y = reorder(pathogen, estimate)
)) +
  geom_point(size = 4, color = "black") +
  geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper),
                 height = 0.2,
                 linewidth = 0.6,
                 alpha = 0.8,
                 color = "black") +
  scale_x_continuous(
    limits = c(0, 0.5),
    labels = scales::percent_format(accuracy = 1),
    breaks = seq(0, 0.5, by = 0.05)
  ) +
  labs(
    x = "Share of expected pandemic outbreaks",
    y = NULL,
    caption = NULL
  ) +
  theme_classic(base_size = 8) +
  theme(
    plot.title = element_text(size = 22, face = "bold", hjust = 0),
    plot.subtitle = element_text(size = 14,, hjust = 0, margin = margin(b = 10)),
    plot.caption = element_text(size = 10, hjust = 0, margin = margin(t = 5)),
    axis.text.y = ggtext::element_markdown(
      size = 14,
      color = "black"
    ),
    axis.text.x = element_text(size = 12, color = "black"),
    axis.title.x = element_text(size = 16,  margin = margin(t = 10)),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray85", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    legend.position = "none",
    plot.margin = margin(10, 0, 10, 10)
  )

ggsave("./output/pathogen_pandemic_share_all_nocolor.png", plot = p_nocolor, width = 10, height = 6, dpi = 600)

