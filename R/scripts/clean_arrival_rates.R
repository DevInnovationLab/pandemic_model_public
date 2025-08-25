library(here)
library(janitor)
library(readxl)
library(tidyverse)

arrival_rates_raw <- read_excel("C:/Users/squaade/Box/CEPI Expert Survey (IRB coverage)/CEPI Expert Survey_May 21_2024_Sebastian_Updates.xlsx",
                                sheet = "Arrival rates",
                                range = "B11:O31")

arrival_rates_clean <- arrival_rates_raw %>%
  as.matrix() %>%
  t() %>%
  as.data.frame(stringsAsFactors = FALSE) %>%
  setNames(make.unique(as.character(.[1, ]), sep = "_")) %>%
  slice(-1) %>%
  rownames_to_column("Expert") %>%
  select(-any_of("Comments (regarding previous question)")) %>%
  rename_with(~gsub("\\s*\\([^\\)]+\\)", "", .x), everything()) %>% # Remove things in brackets
  clean_names() %>%
  rename(`crimean-congo_hemorrhagic_fever` = crimean_congo_haemorrhagic_fever)

# Identify which columns should be numeric (disease columns)
id_cols <- c("expert", "employer", "title")
disease_cols <- setdiff(colnames(arrival_rates_clean), id_cols)

# Convert disease columns to numeric, setting non-numeric values to NA
arrival_rates_numeric <- arrival_rates_clean %>%
  mutate(across(
    all_of(disease_cols),
    ~suppressWarnings(as.numeric(.x))
  )) %>%
  filter(!if_all(all_of(disease_cols), is.na)) %>%
  mutate(across((all_of(disease_cols)), ~ ifelse(is.na(.x), 0, .x)))

# Step 3: Collapse "Other known virus" and "Nonviral, nonbacterial" columns
other_virus_cols <- grep(
  "other_known_virus",
  colnames(arrival_rates_numeric),
  ignore.case = TRUE,
  value = TRUE
)

nonviral_cols <- grep(
  "nonviral.*nonbacterial|nonbacterial.*nonviral",
  colnames(arrival_rates_numeric),
  ignore.case = TRUE,
  value = TRUE
)

arrival_rates_collapsed <- arrival_rates_numeric

# Collapse "Other known virus" columns, if present
if (length(other_virus_cols) > 0) {
  arrival_rates_collapsed <- arrival_rates_collapsed %>%
    mutate(
      Other_known_virus = rowMeans(across(all_of(other_virus_cols)), na.rm = TRUE)
    ) %>%
    select(-all_of(other_virus_cols)) %>%
    rename(other_known_virus = Other_known_virus)
}

# Collapse "Nonviral, nonbacterial" columns, if present
if (length(nonviral_cols) > 0) {
  arrival_rates_collapsed <- arrival_rates_collapsed %>%
    mutate(
      Nonviral_nonbacterial = rowMeans(across(all_of(nonviral_cols)), na.rm = TRUE)
    ) %>%
    select(-all_of(nonviral_cols)) %>%
    rename(nonviral_nonbacterial = Nonviral_nonbacterial)
}

# Combine columns that are coronaviruses
arrival_rates_collapsed <- arrival_rates_collapsed %>%
  mutate(coronavirus = covid_19 + mers + other_coronavirus) %>%
  select(-c(mers, other_coronavirus, covid_19)) |>
  select(-expert, -title, -employer) # Remove sensitive data

# Normalize arrival rates
arrival_rates_all <- arrival_rates_collapsed |>
  mutate(across(everything(), ~ .x / rowSums(across(everything()), na.rm = TRUE)))

arrival_rates_virus <- arrival_rates_collapsed |>
  select(-drug_resistant_bacterial_infection, -nonviral_nonbacterial) |>
  mutate(across(everything(), ~ .x / rowSums(across(everything()), na.rm = TRUE)))

# Save output
write.csv(arrival_rates_all, "./data/clean/arrival_rates_all_clean.csv", row.names = FALSE)
write.csv(arrival_rates_virus, "./data/clean/arrival_rates_virus_clean.csv", row.names = FALSE)
