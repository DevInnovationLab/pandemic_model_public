library(forcats)
library(ggplot2)
library(snakecase)
library(readr)
library(dplyr)

# Read in timeline predictions from timelines_from_predictions.csv
timeline_preds <- read_csv("output/rd_timelines/timelines_from_predictions.csv", show_col_types = FALSE)

# Read in pathogen info to determine which pathogens have a prototype
pathogen_info <- read_csv("data/raw/pathogen_info.csv", show_col_types = FALSE)

# Merge prototype info into timeline_preds
timeline_merged <- timeline_preds %>%
  left_join(pathogen_info %>% select(pathogen, has_prototype_info = has_prototype), by = "pathogen")

# Only plot both prototype statuses for pathogens that do NOT have a prototype in pathogen_info
# For pathogens that DO have a prototype, only plot the "with prototype" row
timeline_plot_data <- timeline_merged %>%
  mutate(
    # Clean up pathogen names for plotting
    pathogen_plot = to_sentence_case(gsub("_", " ", pathogen)),
    pathogen_plot = ifelse(pathogen_plot == "Crimean congo hemorrhagic fever", "CCHF", pathogen_plot),
    has_prototype_plot = ifelse(has_prototype, "With prototype", "Without prototype"),
    has_prototype_plot = factor(has_prototype_plot, levels = c("With prototype", "Without prototype"))
  ) %>%
  filter(
    # If pathogen_info says it has a prototype, only keep "with prototype" row
    (has_prototype_info & has_prototype) |
      # If pathogen_info says it does NOT have a prototype, keep both rows
      (!has_prototype_info)
  )

# First, order pathogens alphabetically (top to bottom), then within each pathogen,
# "With prototype" comes before "Without prototype" (top to bottom).
timeline_plot_data <- timeline_plot_data %>%
  mutate(
    # Ensure has_prototype_plot is a factor with "With prototype" first
    has_prototype_plot = factor(has_prototype_plot, levels = c("Without prototype", "With prototype"))
  ) %>%
  arrange(pathogen_plot, has_prototype_plot)  # "With prototype" comes first for each pathogen

# Now set the factor levels for pathogen_plot so that the order is top-to-bottom alphabetical
order_pathogens <- sort(unique(timeline_plot_data$pathogen_plot), decreasing = TRUE)
timeline_plot_data$pathogen_plot <- factor(timeline_plot_data$pathogen_plot, levels = order_pathogens)

# Set color palette
prototype_colors <- c("With prototype" = "#005185", "Without prototype" = "#A50021")

# Plot with 95% confidence intervals
timeline_plot <- ggplot(
    timeline_plot_data,
    aes(
      x = time_to_vaccine,
      y = pathogen_plot,
      color = has_prototype_plot,
      shape = has_prototype_plot
    )
  ) +
  geom_errorbarh(
    aes(xmin = lo95, xmax = hi95),
    height = 0.25,
    position = position_dodge(width = 0.6),
    linewidth = 1
  ) +
  geom_point(size = 4, position = position_dodge(width = 0.6)) +
  scale_color_manual(
    values = prototype_colors,
    name = "Prototype status",
    breaks = c("With prototype", "Without prototype")
  ) +
  scale_shape_manual(
    values = c("With prototype" = 16, "Without prototype" = 17),
    name = "Prototype status",
    breaks = c("With prototype", "Without prototype")
  ) +
  scale_x_continuous(
    limits = c(0, NA),
    breaks = scales::pretty_breaks(n = 8)
  ) +
  labs(
    x = "Time to vaccine (years)",
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
ggsave("output/rd_timelines/timelines_from_predictions.png", timeline_plot, width = 8, height = 5.5, dpi = 600)
