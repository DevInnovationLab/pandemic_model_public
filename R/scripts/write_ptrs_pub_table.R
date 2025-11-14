library(readr)
library(dplyr)
library(stringr)

# Read in PTRS table with prototype effect included
ptrs <- read_csv("output/ptrs/ptrs_table.csv", show_col_types = FALSE)

# Factors for technology display
platform_levels <- c("mrna_only", "traditional_only")
platform_labels <- c("mRNA", "Traditional")
names(platform_labels) <- platform_levels

# Clean pathogen display names
ptrs <- ptrs %>%
  mutate(
    Pathogen = str_to_title(gsub("_", " ", pathogen)),
    Platform = platform_labels[platform]
  )

# Enforce alphabetical order by pathogen
pathogen_levels <- sort(unique(ptrs$Pathogen))
platform_order <- platform_labels[platform_levels]

# Pre-format PTRS (2 digits), blanks if missing
ptrs_wide <- ptrs %>%
  mutate(
    ptrs = sprintf("%.2f", ptrs),
    has_prototype = as.integer(has_prototype)
  ) %>%
  select(Pathogen, Platform, has_prototype, ptrs) %>%
  tidyr::pivot_wider(
    names_from = has_prototype, values_from = ptrs,
    names_prefix = "PTRS_"
  ) %>%
  # Ensure both columns exist even if not all values present
  mutate(
    PTRS_0 = coalesce(PTRS_0, ""),
    PTRS_1 = coalesce(PTRS_1, "")
  )

# Add explicit row order for pathogen and then platform
ptrs_wide <- ptrs_wide %>%
  mutate(
    Pathogen = factor(Pathogen, levels = pathogen_levels),
    Platform = factor(Platform, levels = platform_order)
  ) %>%
  arrange(Pathogen, Platform)

# LaTeX caption: no vertical space between title and text, not centered.
latex_caption <- paste0(
  "\\textbf{Estimated probability of technical and regulatory success (PTRS) for vaccines by virus, technology platform, and prototype vaccine status.} ",
  "Central estimate for each row is the probability that a vaccine candidate will achieve technical and regulatory success. For pathogens that do not have an approved prototype vaccine, estimates are provided for both the case where a prototype is not available and where a prototype becomes available (using modeled effect). For pathogens that already have a prototype, only the 'With Prototype' column is populated. mRNA and traditional platforms are displayed for each pathogen."
)

# Table header: no column heading bold, double \hline at top and bottom; caption not centered
table_header <- paste0(
  "\\begin{table}[!htbp]\n",
  "\\caption{", latex_caption, "}\n",
  "\\label{tab:ptrs-for-sims}\n",
  "\\begin{tabular}{llcc}\n",
  "\\hline\\hline\n",
  "Pathogen & Platform & PTRS (no prototype) & PTRS (with prototype) \\\\\n",
  "\\hline"
)

# Function to build rows WITHOUT \multirow; only show pathogen name in the first row, blank in subsequent platform rows
make_table_rows <- function(tbl) {
  res <- character(0)
  for (path in pathogen_levels) {
    rows <- tbl %>% filter(Pathogen == path)
    num_platforms <- nrow(rows)
    for (i in seq_len(num_platforms)) {
      # Only display pathogen name in the first row for block
      pathogen_cell <- if (i == 1) as.character(rows$Pathogen[i]) else ""
      res <- c(res, sprintf(
        "%s & %s & %s & %s \\\\",
        pathogen_cell,
        rows$Platform[i],
        rows$PTRS_0[i],
        rows$PTRS_1[i]
      ))
    }
  }
  res
}

# Write LaTeX table rows
table_rows <- make_table_rows(ptrs_wide)

# Table footer: double \hline at bottom
table_footer <- paste0(
  "\\hline\\hline\n",
  "\\end{tabular}\n",
  "\\end{table}\n"
)

# Compose LaTeX
tex_out <- paste0(
  table_header, "\n",
  paste0(table_rows, collapse = "\n"),
  "\n", table_footer
)

writeLines(tex_out, "output/ptrs/ptrs_pub_table.tex")
