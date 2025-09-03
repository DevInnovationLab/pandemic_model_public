#' Create a dataset with pathogen, time_to_vaccine, has_prototype, and 95% confidence intervals.
#'
#' Reads marginal_timeline_preds.csv and creates a data frame where
#' time_to_vaccine is the mean_hat value if has_prototype is TRUE,
#' and double that value if has_prototype is FALSE.
#' 95% confidence intervals (lo95, hi95) are also included and doubled for the
#' has_prototype == FALSE rows.
#'
#' The resulting data frame is written to output/rd_timelines/timelines_from_predictions.csv.

library(readr)
library(dplyr)
library(tidyr)

# Read the marginal timeline predictions
timeline_preds <- read_csv("output/rd_timelines/marginal_timeline_preds.csv", show_col_types = FALSE)

# For each pathogen, create two rows: one with has_prototype TRUE, one with FALSE, including 95% CIs
timeline_by_prototype <- timeline_preds %>%
  select(pathogen, mean_hat, lo95, hi95) %>%
  mutate(
    has_prototype = TRUE,
    time_to_vaccine = mean_hat,
    lo95 = lo95,
    hi95 = hi95
  ) %>%
  bind_rows(
    timeline_preds %>%
      select(pathogen, mean_hat, lo95, hi95) %>%
      mutate(
        has_prototype = FALSE,
        time_to_vaccine = mean_hat * 2,
        lo95 = lo95 * 2,
        hi95 = hi95 * 2
      )
  ) %>%
  select(pathogen, time_to_vaccine, lo95, hi95, has_prototype) %>%
  mutate(has_prototype = as.numeric(has_prototype)) %>%
  arrange(pathogen, desc(has_prototype))

# Write the result to CSV
write_csv(timeline_by_prototype, "output/rd_timelines/timelines_from_predictions.csv")
