# write_adv_rd_costing_inputs.R — Compute vaccine R&D cost parameters from published literature.
#
# Extracts stage-level costs from Gouglas et al. (2018), WHO (2016), and Wilson (2010),
# averages across sources, and combines with published stage transition probabilities to
# compute expected per-candidate cost and the number of candidates needed to reach the
# target success probability. Results are printed to stdout for use as model inputs.
#
# Sources: HHS report on preventive vaccine development (Table 5)
#   https://aspe.hhs.gov/sites/default/files/documents/8617396c6b5ad0efcd5d3b8d60b04da3/preventive-vaccine-development.pdf
# Outputs: printed to stdout
#
# Run from the repository root.

library(tidyverse)

TARGET_PROB <- 0.9

## --- Stage costs from published literature ------------------------------------
# All figures in 2018 USD millions; inflated to 2024 below.

# Extract published estimates from Table 5 (in 2018 $ Million)
stage_costs_tbl5 <- tribble(
  ~source, ~type,         ~preclinical, ~phase_1, ~phase_2, ~phase_3, ~approval, ~phase_4,
  "Gouglas et al (2018)", "High",        26.28,    14.21,    28.00,    NA,              NA,           NA,
  "Gouglas et al (2018)", "Low",         7.88,     6.81,     16.78,    NA,              NA,           NA,
  "WHO (2016)",           "Simple",      6.91,     2.27,     13.61,     114.58,          NA,           NA,
  "WHO (2016)",           "Complex",     17.12,    2.58,     14.34,    137.48,          NA,           NA,
  "Wilson (2010)",        "Low",         6.17,     4.94,     4.94,     61.74,           2.47,         NA,
  "Wilson (2010)",        "High",        18.52,    12.35,    12.53,    148.17,          3.70,         NA
)
  
## --- Compute expected cost per candidate --------------------------------------
stage_costs_long <- stage_costs_tbl5 %>%
  pivot_longer(
    cols = c(preclinical, phase_1, phase_2, phase_3, approval, phase_4),
    names_to = "stage", values_to = "cost"
  )

# Compute average (excluding NA)
avg_stage_costs <- stage_costs_long %>%
  filter(stage %in% c("preclinical", "phase_1", "phase_2", "phase_3", "approval")) %>%
  group_by(stage) %>%
  summarise(mean_cost_2018M = mean(cost, na.rm = TRUE), .groups = "drop")

# Create transition probability tibble
transition_probs_tbl <- tibble(
  stage = c("preclinical", "phase_1", "phase_2", "phase_3", "approval"),
  transition_prob = c(0.444, 0.646, 0.458, 0.759, 0.942)
)

inflation_adjustment <- 1.24 # 2018 to 2024 US CPI from BLS

# Merge to ensure matching by stage name
adv_rd_inputs <- avg_stage_costs %>%
  right_join(transition_probs_tbl, by = "stage") %>%
  arrange(factor(stage, levels = transition_probs_tbl$stage)) %>%
  mutate(
    cost = mean_cost_2018M * 1e6 * inflation_adjustment,
    entry_prob = lag(cumprod(transition_prob), default = 1),
    expected_cost = cost * entry_prob
  )

total_expected_cost <- sum(adv_rd_inputs$expected_cost)
prob_candidate_success <- prod(adv_rd_inputs$transition_prob)
candidates_to_reach_target <- log(1 - TARGET_PROB) / log(1 - prob_candidate_success)
total_expected_funding <- total_expected_cost * candidates_to_reach_target

print(paste("Probability a candidate succeeds:", signif(prob_candidate_success, 3)))
print(paste("Expected cost for one candidate(million USD):", round(total_expected_cost / 1e6)))
print(paste("Candidates to reach target:", round(candidates_to_reach_target)))
print(paste("Total expected funding (million USD):", round(total_expected_funding / 1e6)))

