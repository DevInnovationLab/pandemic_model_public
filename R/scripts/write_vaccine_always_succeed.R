library(tidyverse)

#' Build a PTRS table where all vaccines succeed.
#'
#' This script reads the PTRS table created by `create_ptrs_table.R`
#' (`output/ptrs/ptrs_table.csv`) and writes a new table with the
#' **same columns and ordering**, but with `ptrs` set to 1 for every
#' pathogen–platform–prototype combination. The output is
#' `output/ptrs/ptrs_table_always_succeed.csv`, suitable for use as
#' `ptrs_pathogen` in sensitivity configs.

ptrs_table <- readr::read_csv("output/ptrs/ptrs_table.csv", show_col_types = FALSE)

ptrs_always_succeed <- ptrs_table %>%
  mutate(ptrs = 1)

out_dir <- "output/ptrs"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
readr::write_csv(ptrs_always_succeed, file.path(out_dir, "ptrs_table_always_succeed.csv"))
