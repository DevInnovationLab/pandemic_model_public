library(DirichletReg)
library(here)
library(ggplot2)
library(ggtext)
library(janitor)
library(snakecase)
library(tidyverse)

# Load virus arrival rates
arrival_rates_virus <- read.csv("./data/clean/arrival_rates_virus_clean.csv")
pathogen_data <- read.csv("./data/clean/pathogen_data_arrival_all.csv")

# Calculate mean and standard error for each pathogen's arrival risk
# Assume arrival_rates_virus is in wide format: columns are pathogen names

# Convert to long format: pathogen, risk
arrival_long <- arrival_rates_virus %>%
  pivot_longer(cols = everything(), names_to = "pathogen", values_to = "risk")

# Summarize mean, SE, and 95% CI (mean ± 1.96*SE), including pathogens with all-zero risk
# This ensures pathogens with all-zero risk are included with SE = 0 and CI = 0
arrival_risk_summary <- arrival_long %>%
  group_by(pathogen) %>%
  summarize(
    estimate = mean(risk, na.rm = TRUE),
    se = ifelse(all(risk == 0, na.rm = TRUE), 0, sd(risk, na.rm = TRUE) / sqrt(sum(!is.na(risk)))),
    .groups = "drop"
  ) %>%
  # Add in any pathogens from pathogen_data that are missing (i.e., have all-zero risk)
  left_join(pathogen_data, by = "pathogen") %>%
  mutate(
    estimate = ifelse(is.na(estimate), 0, estimate),
    se = ifelse(is.na(se), 0, se),
    ci_lower = estimate - 1.96 * se,
    ci_upper = estimate + 1.96 * se,
    has_prototype = ifelse(is.na(has_prototype), FALSE, has_prototype),
    pathogen = to_sentence_case(gsub("_", " ", pathogen)),
    pathogen = ifelse(pathogen == "Totally unknown virus", "Unknown virus", pathogen),
    pathogen = ifelse(grepl("crimean", pathogen, ignore.case = TRUE), "CCHF", pathogen)
  )

# Add a factor for legend labeling
arrival_risk_summary <- arrival_risk_summary %>%
  mutate(
    prototype_status = factor(
      ifelse(has_prototype == 1 | has_prototype == TRUE, "Has prototype", "No prototype"),
      levels = c("Has prototype", "No prototype")
    )
  )

# Define more professional colors for prototype status
prototype_colors <- c("Has prototype" = "#005185", "No prototype" = "#A50021") # slightly darker solid blue and red

p <- ggplot(arrival_risk_summary, aes(
  x = estimate,
  y = reorder(pathogen, estimate),
  color = prototype_status
)) +
  geom_point(size = 4) +
  geom_errorbarh(aes(xmin = ci_lower, xmax = ci_upper, color = prototype_status),
                 height = 0.2,
                 linewidth = 0.6,
                 alpha = 0.8) +
  # Color y-axis text by has_prototype
  scale_color_manual(
    name = "Prototype vaccine",
    values = prototype_colors
  ) +
  scale_x_continuous(
    limits = c(-.01, max(arrival_risk_summary$ci_upper) * 1.15),
    labels = scales::percent_format(accuracy = 1),
    breaks = seq(0, 0.5, by = 0.05)
  ) +
  labs(
    x = "Share of expected pandemic outbreaks",
    y = NULL,
    color = "Prototype vaccine"
  ) +
  theme_classic(base_size = 8) +
  theme(
    plot.title = element_text(size = 22, face = "bold", hjust = 0),
    plot.subtitle = element_text(size = 14, color = "gray40", hjust = 0, margin = margin(b = 10)),
    plot.caption = element_text(size = 10, color = "gray50", hjust = 0, margin = margin(t = 5)),
    axis.text.y = ggtext::element_markdown(
      size = 14,
      face = "plain",
      color = arrival_risk_summary %>%
        arrange(estimate) %>%
        mutate(color = ifelse(has_prototype == 1 | has_prototype == TRUE, prototype_colors["Has prototype"], prototype_colors["No prototype"])) %>%
        pull(color)
    ),
    axis.text.x = element_text(size = 12, color = "black"),
    axis.title.x = element_text(size = 18, face = "bold", margin = margin(t = 10)),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5),
    panel.grid.major.x = element_line(color = "gray85", linewidth = 0.5),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    legend.position = "right",
    legend.title = element_text(size = 16, face = "bold"),
    legend.text = element_text(size = 14),
    legend.key.size = unit(1.5, "lines"),
    legend.box.margin = margin(0, 10, 0, 0),
    plot.margin = margin(10, 0, 10, 10)
  )

# Make the figure a little wider (e.g., width = 9 inches instead of default 7)
ggsave("./output/pathogen_pandemic_share_all.png", plot = p, width = 9, height = 7, dpi = 300)
