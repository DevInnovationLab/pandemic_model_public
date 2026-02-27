library(tidyverse)

#' Build a marginal PTRS table with probability one for all vaccine candidates.
#'
#' Outputs a CSV with the same structure as marginal_ptrs_preds.csv (pathogen,
#' platform, mu_hat, se_mu, lo95, hi95) but mu_hat, lo95, and hi95 set to 1 and
#' se_mu set to 0, so that every pathogen-platform combination has probability one.
#' The grid of pathogen x platform matches the fit script (mrna_only and traditional_only).

ptrs_raw <- readr::read_csv("data/clean/vaccine_ptrs.csv", show_col_types = FALSE)

grid <- ptrs_raw %>%
  filter(platform %in% c("mrna_only", "traditional_only")) %>%
  distinct(pathogen, platform) %>%
  arrange(pathogen, platform)

ptrs_always_succeed <- grid %>%
  mutate(
    mu_hat = 1,
    se_mu  = 0,
    lo95   = 1,
    hi95   = 1
  )

out_dir <- "output/ptrs"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
readr::write_csv(ptrs_always_succeed, file.path(out_dir, "marginal_ptrs_preds_always_succeed.csv"))
