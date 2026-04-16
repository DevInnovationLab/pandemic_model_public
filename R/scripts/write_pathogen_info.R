# write_pathogen_info.R — Write manually curated pathogen reference table.
#
# Defines and exports a static lookup table of all modelled pathogens with
# viral family, prototype vaccine status, and airborne transmission flag.
#
# Inputs:  none (data hardcoded in script)
# Outputs: data/raw/pathogen_info.csv
#
# Run from the repository root.

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
