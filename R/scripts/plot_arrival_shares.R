# plot_arrival_shares.R — Plot pathogen pandemic arrival shares with 95% CIs.
#
# Produces a horizontal dot-and-errorbar chart of expected pathogen pandemic
# shares, coloured by whether a prototype vaccine exists.
#
# Inputs:  data/clean/arrival_rates_all.csv
# Outputs: output/pathogen_pandemic_share_all.pdf

library(forcats)
library(ggplot2)
library(snakecase)
library(tidyverse)

## --- Load and prep data -------------------------------------------------------

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


## --- Build plot ---------------------------------------------------------------

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
    name = NULL,
    values = prototype_colors
  ) +
  scale_x_continuous(
    limits = c(-.01, 0.5),
    labels = scales::percent_format(accuracy = 1),
    breaks = seq(0, 0.5, by = 0.10)
  ) +
  labs(
    x = "Share of expected pandemic outbreaks",
    y = "Pathogen",
    caption = NULL
  ) +
  theme_classic(base_size = 8, base_family = "Arial") +
  theme(
    axis.text.y = element_text(family = "Arial", size = 13, color = "black"),
    axis.text.x = element_text(family = "Arial", size = 13, color = "black"),
    axis.title.x = element_text(family = "Arial", size = 15,  margin = margin(t = 10)),
    axis.title.y = element_text(size = 15, color = "black", face = "bold"),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    legend.position = c(0.96, 0.5), # inside, center-right
    legend.justification = c("right", "center"),
    legend.direction = "vertical",
    legend.background = element_rect(fill = alpha("white", 0.9), color = NA),
    legend.title = element_blank(),
    legend.text = element_text(family = "Arial", size = 14),
    legend.key.size = unit(1.1, "lines"),
    legend.box.margin = margin(0, 0, 0, 0),
    plot.margin = margin(0, 0, 0, 0)
  )

## --- Save output --------------------------------------------------------------
ggsave(
  "./output/pathogen_pandemic_share_all.pdf",
  plot = p,
  width = 10,
  height = 7.5,
  units = "in",
  dpi = 600,
  device = cairo_pdf
)
