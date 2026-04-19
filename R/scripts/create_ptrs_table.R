# create_ptrs_table.R — Assemble final PTRS table including prototype-effect adjustments.
#
# Merges marginal PTRS predictions with pathogen metadata. For pathogens that lack
# a prototype at baseline, adds a second row with PTRS adjusted upward by the
# estimated prototype platform effect.
#
# Inputs:  data/derived/marginal_ptrs_preds.csv
#          data/clean/prototype_effect_preds.csv
#          data/clean/pathogen_info.csv
# Outputs: data/clean/ptrs_table.csv
#
# Run from the repository root.

library(tidyverse)

# Read PTRS predictions
ptrs <- readr::read_csv("data/derived/marginal_ptrs_preds.csv", show_col_types = FALSE)

# Read pathogen info (including has_prototype)
pathogen_info <- readr::read_csv("data/clean/pathogen_info.csv", show_col_types = FALSE)

# Read prototype effect predictions
proto_effect <- readr::read_csv("data/clean/prototype_effect_preds.csv", show_col_types = FALSE)

# Merge PTRS with prototype info
ptrs_table <- ptrs %>%
  left_join(pathogen_info, by = "pathogen") %>%
  select(pathogen, platform, has_prototype, mu_hat) %>%
  mutate(has_prototype = as.numeric(has_prototype)) %>%
  rename(ptrs = mu_hat)

# Identify pathogens that do NOT have a prototype at baseline (has_prototype == 0)
no_proto <- pathogen_info %>%
  filter(!has_prototype) %>%
  select(pathogen)

# Create rows for "with prototype" scenario for these pathogens, using the effect by platform
proto_effect_add <- ptrs_table %>%
  filter(pathogen %in% no_proto$pathogen) %>%
  left_join(proto_effect %>% select(platform, effect_mean), by = "platform") %>%
  mutate(
    ptrs = ptrs + effect_mean,
    has_prototype = 1
  ) %>%
  select(pathogen, platform, has_prototype, ptrs)

# Combine base table and the added effect rows
ptrs_table_final <- bind_rows(ptrs_table, proto_effect_add) %>%
  arrange(pathogen, platform, desc(has_prototype))

# Save the merged table as a CSV
readr::write_csv(ptrs_table_final, "data/clean/ptrs_table.csv")
