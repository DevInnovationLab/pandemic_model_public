# get_expected_rd_outcomes.R — Compute arrival-rate-weighted expected vaccine outcomes.
#
# Joins PTRS predictions, pathogen arrival rates, and R&D timeline predictions
# to compute the overall expected probability that a vaccine works for the next
# pandemic and the expected time to vaccine, both weighted by pathogen arrival rates.
#
# Inputs:  data/clean/arrival_rates_all.csv
#          output/ptrs/ptrs_table.csv
#          output/rd_timelines/timelines_from_predictions.csv
#          data/raw/pathogen_info.csv
# Outputs: printed to stdout

library(readr)
library(dplyr)
library(stringr)
library(tidyr)

## --- Load data ----------------------------------------------------------------
arrival_rates <- read_csv("data/clean/arrival_rates_all.csv", show_col_types = FALSE)
ptrs_preds <- read_csv("output/ptrs/ptrs_table.csv", show_col_types = FALSE)
timeline_preds <- read_csv("output/rd_timelines/timelines_from_predictions.csv", show_col_types = FALSE)
pathogen_info <- read_csv("data/raw/pathogen_info.csv")

## --- Compute expected probability vaccine works -------------------------------

# Join PTRS predictions to arrival rates
ptrs_preds_wide <- arrival_rates %>%
  select(pathogen, estimate) %>%
  left_join(ptrs_preds, by = "pathogen")

# Add mRNA-only and Traditional-only rows for unknown_virus and other_known_virus;
# assign minimum platform PTRS as a conservative assumption for uncharacterised pathogens.
ptrs_preds_wide <- ptrs_preds_wide %>%
  filter(!(pathogen %in% c("unknown_virus", "other_known_virus")))

for (v in c("unknown_virus", "other_known_virus")) {
  for (p in c("mrna_only", "traditional_only")) {
    est <- arrival_rates$estimate[arrival_rates$pathogen == v][1]

    ptrs_preds_wide <- bind_rows(
      ptrs_preds_wide,
      tibble(pathogen = v, estimate = est, platform = p, has_prototype = 0, ptrs = NaN),
    )
  }
}

ptrs_joined <- ptrs_preds_wide %>%
  group_by(platform) %>%
  mutate(ptrs = ifelse(is.na(ptrs), min(ptrs, na.rm = TRUE), ptrs)) %>%
  ungroup() %>%
  mutate(
    platform = recode(platform,
                      mrna_only = "mRNA",
                      traditional_only = "Traditional")
  ) %>%
  pivot_wider(names_from = platform, values_from = ptrs) %>%
  mutate(
    prob_mrna = coalesce(mRNA, 0),
    prob_traditional = coalesce(Traditional, 0),
    prob_vaccine_works = 1 - (1 - prob_mrna) * (1 - prob_traditional)
  )

# Calculate overall expected probabilities, weighted by arrival rates
overall_expected_prob <- sum(ptrs_joined$estimate * ptrs_joined$prob_vaccine_works, na.rm = TRUE)
overall_expected_prob_mrna <- sum(ptrs_joined$estimate * ptrs_joined$prob_mrna, na.rm = TRUE)
overall_expected_prob_traditional <- sum(ptrs_joined$estimate * ptrs_joined$prob_traditional, na.rm = TRUE)

# Print results
cat("Expected probability that a vaccine will work for the next pandemic (weighted by arrival rates):\n")
cat("  At least one platform: ", round(overall_expected_prob, 4), "\n")
cat("  mRNA only:             ", round(overall_expected_prob_mrna, 4), "\n")
cat("  Traditional only:      ", round(overall_expected_prob_traditional, 4), "\n")

## --- Compute expected timeline ------------------------------------------------
timeline_joined <- arrival_rates %>%
  select(pathogen, estimate) %>%
  left_join(pathogen_info, by = "pathogen") %>%
  left_join(timeline_preds, by = c("pathogen", "has_prototype")) %>%
  mutate(time_to_vaccine = ifelse(is.na(time_to_vaccine), max(time_to_vaccine, na.rm = TRUE), time_to_vaccine))

# Need to add in unnkown virus
overall_expected_timeline <- sum(timeline_joined$estimate * timeline_joined$time_to_vaccine, na.rm = TRUE)

cat("Weighted mean timeline (years): ", round(overall_expected_timeline, 2))
