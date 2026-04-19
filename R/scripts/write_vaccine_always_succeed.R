# write_vaccine_always_succeed.R — Write PTRS sensitivity table with all vaccines succeeding.
#
# Reads the assembled PTRS table and sets ptrs = 1 for every
# pathogen–platform–prototype combination. Used as the ptrs_pathogen input in
# sensitivity configs that assume perfect vaccine development success.
#
# Inputs:  data/clean/ptrs_table.csv
# Outputs: data/clean/ptrs_table_always_succeed.csv
#
# Run from the repository root.

library(readr)
library(tidyverse)

ptrs_table <- readr::read_csv("data/clean/ptrs_table.csv", show_col_types = FALSE)

ptrs_always_succeed <- ptrs_table %>%
  mutate(ptrs = 1)
write_csv(ptrs_always_succeed, file.path("data/cleanptrs_table_always_succeed.csv"))
