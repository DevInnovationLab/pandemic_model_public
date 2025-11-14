#' Create a dataframe of pathogen characteristics.
#'
#' This dataframe contains information on pathogen group, viral family, prototype vaccine status, and airborne status.
#'  Data taken from https://docs.google.com/spreadsheets/d/1cV7VqPgQZFT5FOPe-9DIRJlVE6JrwhmXDeKjyVxn8dE/edit?gid=1778009623#gid=1778009623
#' @return A tibble with columns: pathogen, viral_family, has_prototype, airborne.
#' @examples
#' pathogen_info
library(tibble)
library(dplyr)

pathogen_info <- tibble::tribble(
  ~pathogen,                          ~viral_family,        ~has_prototype,   ~airborne,
  "coronavirus",                      "coronaviridae",      TRUE,             TRUE,
  "crimean_congo_hemorrhagic_fever",  "nairoviridae",       FALSE,            FALSE,
  "lassa",                            "arenaviridae",       FALSE,            FALSE,
  "nipah",                            "paramyxoviridae",    TRUE,             FALSE,
  "rift_valley_fever",                "phenuiviridae",      FALSE,            FALSE,
  "chikungunya",                      "togaviridae",        TRUE,             FALSE,
  "ebola",                            "filoviridae",        TRUE,             FALSE,
  "zika",                             "flaviviridae",       TRUE,             FALSE,
  "flu",                              "orthomyxoviridae",   TRUE,             TRUE,
  "unknown_virus",                    "unknown",            FALSE,            NA,
  "other_known_virus",                "unknown",            FALSE,            NA
)

readr::write_csv(pathogen_info, "data/raw/pathogen_info.csv")
