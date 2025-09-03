library(tidyverse)

# Read PTRS predictions
ptrs <- readr::read_csv("output/ptrs/marginal_ptrs_preds.csv", show_col_types = FALSE)

# Read pathogen info (including has_prototype)
pathogen_info <- readr::read_csv("data/raw/pathogen_info.csv", show_col_types = FALSE) 

# Merge PTRS with prototype info
ptrs_table <- ptrs %>%
  left_join(pathogen_info, by = "pathogen") %>%
  select(pathogen, platform, has_prototype, mu_hat) %>%
  mutate(has_prototype = as.numeric(has_prototype)) %>%
  rename(ptrs = mu_hat)

# Save the merged table as a CSV
readr::write_csv(ptrs_table, "output/ptrs/ptrs_table.csv")

