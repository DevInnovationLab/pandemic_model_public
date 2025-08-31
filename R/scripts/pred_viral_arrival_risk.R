library(DirichletReg)
library(here)
library(ggplot2)
library(ggtext)
library(janitor)
library(snakecase)
library(tidyverse)

#' Calculate mean, standard error, and 95% CI for pathogen arrival risk.
#'
#' This function takes a long-format data frame of arrival risks and a pathogen metadata table,
#' and returns a summary table with mean, SE, and 95% CI for each pathogen, including those with all-zero risk.
#'
#' @param arrival_long Long-format data frame with columns 'pathogen' and 'risk'.
#' @param pathogen_data Data frame with pathogen metadata (must include 'pathogen').
#' @return A data frame with columns: pathogen, estimate, se, ci_lower, ci_upper, has_prototype, and other metadata.
summarize_arrival_risk <- function(arrival_long, pathogen_data) {
  arrival_long %>%
    group_by(pathogen) %>%
    summarize(
      estimate = mean(risk, na.rm = TRUE),
      se = ifelse(all(risk == 0, na.rm = TRUE), 0, sd(risk, na.rm = TRUE) / sqrt(sum(!is.na(risk)))),
      .groups = "drop"
    ) %>%
    left_join(pathogen_data, by = "pathogen") %>%
    mutate(
      estimate = ifelse(is.na(estimate), 0, estimate),
      se = ifelse(is.na(se), 0, se),
      ci_lower = estimate - 1.96 * se,
      ci_upper = estimate + 1.96 * se,
      has_prototype = ifelse(is.na(has_prototype), FALSE, has_prototype),
      has_prototype = ifelse(has_prototype, "Has prototype", "No prototype"),
      pathogen = to_sentence_case(gsub("_", " ", pathogen)),
      pathogen = ifelse(pathogen == "Totally unknown virus", "Unknown virus", pathogen),
      pathogen = ifelse(grepl("crimean", pathogen, ignore.case = TRUE), "CCHF", pathogen)
    )
}

# Load virus arrival rates and pathogen metadata
arrival_rates_virus <- read.csv("./data/clean/arrival_rates_virus_clean.csv")
pathogen_data <- read.csv("./data/clean/pathogen_data_arrival_all.csv")

# --- All viruses: absolute and relative arrival rates ---
# Relative risk: for each respondent, normalize risks to sum to 1 (relative to only viruses)
arrival_rates_virus_rel <- arrival_rates_virus %>%
  mutate(across(everything(), ~ .x / rowSums(across(everything()), na.rm = TRUE))) %>%
  pivot_longer(cols = everything(), names_to = "pathogen", values_to = "risk")

arrival_risk_summary_all <- summarize_arrival_risk(arrival_rates_virus_rel, pathogen_data)

# --- Airborne viruses only: absolute and relative arrival rates ---

# Identify airborne or unknown pathogens
airborne_pathogens <- pathogen_data %>%
  filter(tolower(airborne) %in% c("yes")) %>%
  pull(pathogen)

arrival_rates_airborne_rel <- arrival_rates_virus %>%
  select(all_of(airborne_pathogens)) %>%
  mutate(across(everything(), ~ .x / rowSums(across(everything()), na.rm = TRUE))) %>%
  pivot_longer(cols = everything(), names_to = "pathogen", values_to = "risk")

arrival_risk_summary_airborne <- summarize_arrival_risk(arrival_rates_airborne_rel, pathogen_data_airborne)

# --- Plot for all viruses (absolute risk) ---

prototype_colors <- c("Has prototype" = "#005185", "No prototype" = "#A50021") # blue and red

p <- ggplot(arrival_risk_summary_all, aes(
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
      color = arrival_risk_summary_all %>%
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
    legend.position = "right",
    legend.title = element_text(size = 16, face = "bold"),
    legend.text = element_text(size = 14),
    legend.key.size = unit(1.5, "lines"),
    legend.box.margin = margin(0, 10, 0, 0),
    plot.margin = margin(10, 0, 10, 10)
  )

ggsave("./output/pathogen_pandemic_share_all.png", plot = p, width = 9, height = 7, dpi = 300)

# --- Save all summary tables ---
write.csv(arrival_risk_summary_all, "./data/clean/pathogen_data_all.csv", row.names = FALSE)
write.csv(arrival_risk_summary_airborne, "./data/clean/pathogen_data_airborne.csv", row.names = FALSE)
