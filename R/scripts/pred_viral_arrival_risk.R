# pred_viral_arrival_risk.R — Compute pathogen arrival risk summaries from expert survey responses.
#
# Normalises virus arrival rate responses to relative shares (all viruses and
# airborne-only subsets), summarises across respondents, and saves the resulting
# tables for use in downstream PTRS and timeline analyses.
#
# Inputs:  data/derived/arrival_rate_responses_virus_clean.csv
#          data/clean/pathogen_info.csv
# Outputs: data/clean/arrival_rates_all.csv
#          data/clean/arrival_rates_airborne.csv
#
# Run from the repository root.

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
#' @param pathogen_info Data frame with pathogen metadata (must include 'pathogen').
#' @return A data frame with columns: pathogen, estimate, se, ci_lower, ci_upper, has_prototype, and other metadata.
summarize_arrival_risk <- function(arrival_long, pathogen_info) {
  arrival_long %>%
    group_by(pathogen) %>%
    summarize(
      estimate = mean(risk, na.rm = TRUE),
      se = ifelse(all(risk == 0, na.rm = TRUE), 0, sd(risk, na.rm = TRUE) / sqrt(sum(!is.na(risk)))),
      .groups = "drop"
    ) %>%
    left_join(pathogen_info, by = "pathogen") %>%
    mutate(
      estimate = ifelse(is.na(estimate), 0, estimate),
      se = ifelse(is.na(se), 0, se),
      ci_lower = estimate - 1.96 * se,
      ci_upper = estimate + 1.96 * se
    )
}

# Load virus arrival rates and pathogen metadata
arrival_rates_virus <- read.csv("./data/derived/arrival_rate_responses_virus_clean.csv")
pathogen_info <- read.csv("./data/clean/pathogen_info.csv")

# --- All viruses: absolute and relative arrival rates ---
# Relative risk: for each respondent, normalize risks to sum to 1 (relative to only viruses)
arrival_rates_virus_rel <- arrival_rates_virus %>%
  mutate(across(everything(), ~ .x / rowSums(across(everything()), na.rm = TRUE))) %>%
  pivot_longer(cols = everything(), names_to = "pathogen", values_to = "risk")

arrival_risk_summary_all <- summarize_arrival_risk(arrival_rates_virus_rel, pathogen_info)

# --- Airborne viruses only: absolute and relative arrival rates ---

# Identify airborne or unknown pathogens
airborne_pathogens <- pathogen_info %>%
  filter(airborne) %>%
  pull(pathogen)

arrival_rates_airborne_rel <- arrival_rates_virus %>%
  select(all_of(airborne_pathogens)) %>%
  mutate(across(everything(), ~ .x / rowSums(across(everything()), na.rm = TRUE))) %>%
  pivot_longer(cols = everything(), names_to = "pathogen", values_to = "risk")

arrival_risk_summary_airborne <- summarize_arrival_risk(arrival_rates_airborne_rel, pathogen_info)

# --- Save all summary tables ---
write.csv(arrival_risk_summary_all, "./data/clean/arrival_rates_all.csv", row.names = FALSE)
write.csv(arrival_risk_summary_airborne, "./data/clean/arrival_rates_airborne.csv", row.names = FALSE)
