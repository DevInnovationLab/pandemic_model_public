# write_vaccine_always_succeed.R — Write PTRS sensitivity table with all vaccines succeeding.
#
# Reads the assembled PTRS table and sets ptrs = 1 for every
# pathogen–platform–prototype combination. Used as the ptrs_pathogen input in
# sensitivity configs that assume perfect vaccine development success.
#
# Inputs:  output/ptrs/ptrs_table.csv
# Outputs: output/ptrs/ptrs_table_always_succeed.csv
#
# Run from the repository root.

library(tidyverse)

ptrs_table <- readr::read_csv("output/ptrs/ptrs_table.csv", show_col_types = FALSE)

ptrs_always_succeed <- ptrs_table %>%
  mutate(ptrs = 1)

out_dir <- "output/ptrs"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
readr::write_csv(ptrs_always_succeed, file.path(out_dir, "ptrs_table_always_succeed.csv"))
