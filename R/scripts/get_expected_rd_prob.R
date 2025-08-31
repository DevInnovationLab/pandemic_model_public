library(readr)
library(dplyr)
library(stringr)
library(tidyr)

# Load pathogen data (includes arrival rate estimates)
pathogen_data <- read_csv("data/clean/pathogen_data_all.csv", show_col_types = FALSE)

# Load PTRS predictions for each platform
model_preds <- read_csv("output/ptrs/pathogen_model_preds.csv", show_col_types = FALSE)

# Clean up pathogen names for joining
model_preds <- model_preds %>%
  mutate(
    pathogen = str_to_sentence(str_replace_all(pathogen, "_", " ")),
    pathogen = ifelse(pathogen == "Crimean congo hemorrhagic fever", "CCHF", pathogen)
  )

# Pivot predictions to wide format: one row per pathogen, columns for each platform
model_preds_wide <- model_preds %>%
  select(pathogen, platform, mu_hat) %>%
  mutate(platform = recode(platform,
                           mrna_only = "mRNA",
                           traditional_only = "Traditional")) %>%
  pivot_wider(names_from = platform, values_from = mu_hat)

# Join with pathogen data to ensure all pathogens are included
joined <- pathogen_data %>%
  left_join(model_preds_wide, by = "pathogen")

# Calculate expected probability that at least one platform works for each pathogen,
# and keep the separate probabilities for mRNA and Traditional platforms
joined <- joined %>%
  mutate(
    prob_mrna = coalesce(mRNA, 0),
    prob_traditional = coalesce(Traditional, 0),
    prob_vaccine_works = 1 - (1 - prob_mrna) * (1 - prob_traditional)
  )

# Calculate the overall expected probability, weighted by arrival rate estimates
# (assume 'estimate' column is the arrival rate for each pathogen)
overall_expected_prob <- sum(joined$estimate * joined$prob_vaccine_works, na.rm = TRUE)
overall_expected_prob_mrna <- sum(joined$estimate * joined$prob_mrna, na.rm = TRUE)
overall_expected_prob_traditional <- sum(joined$estimate * joined$prob_traditional, na.rm = TRUE)

# Print the results
cat("Expected probability that a vaccine will work for the next pandemic (weighted by arrival rates):\n")
cat("  At least one platform: ", round(overall_expected_prob, 4), "\n")
cat("  mRNA only:             ", round(overall_expected_prob_mrna, 4), "\n")
cat("  Traditional only:      ", round(overall_expected_prob_traditional, 4), "\n")
