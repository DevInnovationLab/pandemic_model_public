library(readr)
library(dplyr)
library(stringr)
library(tidyr)

# Load data
arrival_rates <- read_csv("data/clean/arrival_rates_all.csv", show_col_types = FALSE)
ptrs_preds <- read_csv("output/ptrs/marginal_ptrs_preds.csv", show_col_types = FALSE)
timeline_preds <- read_csv("output/rd_timelines/marginal_timeline_preds.csv", show_col_types = FALSE)

# Pivot PTRS predictions to wide format (one row per pathogen)
ptrs_preds_wide <- ptrs_preds %>%
  select(pathogen, platform, mu_hat) %>%
  mutate(
    platform = recode(platform,
                      mrna_only = "mRNA",
                      traditional_only = "Traditional")
  ) %>%
  pivot_wider(names_from = platform, values_from = mu_hat)

# Join PTRS predictions with pathogen data
ptrs_joined <- ptrs_preds_wide %>%
  left_join(arrival_rates, by = "pathogen") %>%
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

# Timeline predictions, doubling for pathogens without a prototype
timeline_joined <- timeline_preds %>%
  left_join(arrival_rates, by = "pathogen") %>%
  mutate(
    timeline = ifelse(is.na(mean_hat), NA_real_, mean_hat),
    timeline_adjusted = ifelse(has_prototype, timeline * 2, timeline)
  )

overall_expected_timeline <- sum(timeline_joined$estimate * timeline_joined$timeline_adjusted, na.rm = TRUE)

cat("Weighted mean timeline (years): ", round(overall_expected_timeline, 2), "\n")


