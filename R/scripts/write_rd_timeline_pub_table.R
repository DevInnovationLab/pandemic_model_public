library(readr)
library(dplyr)
library(stringr)
library(snakecase)

# Read in timeline predictions
timeline_preds <- read_csv("output/rd_timelines/timelines_from_predictions.csv", show_col_types = FALSE)

# Read in pathogen info to determine which pathogens have a prototype
pathogen_info <- read_csv("data/raw/pathogen_info.csv", show_col_types = FALSE)

# Merge prototype info into timeline_preds
timeline_merged <- timeline_preds %>%
  left_join(pathogen_info %>% select(pathogen, has_prototype_info = has_prototype), by = "pathogen")

# Prepare base table: one row per pathogen per prototype status
timeline_tbl <- timeline_merged %>%
  mutate(
    Pathogen = to_sentence_case(gsub("_", " ", pathogen)),
    Pathogen = ifelse(Pathogen == "Crimean congo hemorrhagic fever", "CCHF", Pathogen),
    Prototype_Status = ifelse(has_prototype, "With Prototype", "No Prototype"),
    Months = sprintf("%.0f", time_to_vaccine * 12)
  ) %>%
  filter(
    (has_prototype_info & has_prototype) | (!has_prototype_info)
  )

# Pivot to wide format: columns for no prototype and with prototype
timeline_wide <- timeline_tbl %>%
  mutate(
    Prototype_Col = ifelse(Prototype_Status == "No Prototype", "Months_No_Prototype", "Months_With_Prototype")
  ) %>%
  select(Pathogen, Prototype_Col, Months) %>%
  tidyr::pivot_wider(names_from = Prototype_Col, values_from = Months) %>%
  distinct() %>%
  arrange(Pathogen)

# LaTeX caption
latex_caption <- paste0(
  "\\textbf{Estimated timelines (in months) for vaccine development by pathogen and prototype vaccine status.} ",
  "Central estimate is reported for each pathogen for both cases: when no prototype vaccine is available and when a prototype vaccine is available. ",
  "For pathogens that already have a prototype, only the 'With Prototype' column is populated."
)

# Table header: base LaTeX, no packages
table_header <- paste0(
  "\\begin{table}[!htbp]\n",
  "\\caption{", latex_caption, "}\n",
  "\\label{tab:rd-timelines}\n",
  "\\begin{tabular}{lcc}\n",
  "\\hline\\hline\n",
  "Pathogen & Timeline (no prototype, mo) & Timeline (with prototype, mo) \\\\\n",
  "\\hline"
)

# Build table rows (blank cell if value missing)
make_rows <- function(tbl) {
  res <- character(0)
  for (i in seq_len(nrow(tbl))) {
    row <- tbl[i, ]
    pathogen <- as.character(row$Pathogen)
    no_proto <- ifelse(is.na(row$Months_No_Prototype), "", row$Months_No_Prototype)
    with_proto <- ifelse(is.na(row$Months_With_Prototype), "", row$Months_With_Prototype)
    res <- c(res, sprintf("%s & %s & %s \\\\", pathogen, no_proto, with_proto))
  }
  res
}

table_rows <- make_rows(timeline_wide)

table_footer <- paste0(
  "\\hline\\hline\n",
  "\\end{tabular}\n",
  "\\end{table}\n"
)

tex_out <- paste0(
  table_header, "\n",
  paste0(table_rows, collapse = "\n"),
  "\n", table_footer
)

writeLines(tex_out, "output/rd_timelines/timeline_pub_table.tex")
