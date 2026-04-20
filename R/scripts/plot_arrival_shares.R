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
source("R/scripts/paper_figure_style.R")

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
  theme_paper(width_in = get_paper_size("double_col_tall")["width"], base_family = "Arial") +
  theme(
    legend.position = c(0.94, 0.5), # inside, center-right
    legend.justification = c("right", "center"),
    legend.direction = "vertical",
    legend.background = element_rect(fill = alpha("white", 0.9), color = NA),
    legend.key.size = unit(1.1, "lines"),
    legend.box.margin = margin(0, 0, 0, 0),
    plot.margin = margin(0, 0, 0, 0)
  )

## --- Save output --------------------------------------------------------------
save_paper_plot(
  plot = p,
  path = "output/pathogen_pandemic_share_all.pdf",
  preset = "double_col_tall",
  dpi = 600
)
