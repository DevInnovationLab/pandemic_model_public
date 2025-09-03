#' Create a CSV with pathogen, time_to_vaccine, and has_prototype columns for the optimistic scenario.
#'
#' This script reads pathogen names from data/raw/pathogen_info.csv and outputs
#' a CSV with columns 'pathogen', 'time_to_vaccine', and 'has_prototype'.
#' For each pathogen, two rows are created: one with has_prototype = TRUE and time_to_vaccine = 1,
#' and one with has_prototype = FALSE and time_to_vaccine = 2.

library(readr)
library(dplyr)
library(tidyr)

# Read pathogen info
pathogen_info <- read_csv("data/raw/pathogen_info.csv", show_col_types = FALSE)

# Create all combinations of pathogen and has_prototype, then assign time_to_vaccine
optimistic_rd <- pathogen_info %>%
  select(pathogen) %>%
  crossing(has_prototype = c(TRUE, FALSE)) %>%
  mutate(time_to_vaccine = if_else(has_prototype, 1, 2)) %>%
  select(pathogen, time_to_vaccine, has_prototype) %>%
  mutate(has_prototype = as.numeric(has_prototype)) %>%
  arrange(pathogen, desc(has_prototype))

# Write to CSV
write_csv(optimistic_rd, "output/rd_timelines/optimistic_rd_timelines.csv")
