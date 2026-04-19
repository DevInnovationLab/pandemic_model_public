"""clean_wastewater_treatment.py — Merge wastewater treatment rates with World Bank population data.

Reads raw country-level wastewater treatment percentages and World Bank population
estimates, harmonizes country names across the two sources, and writes a cleaned
CSV for use in the wastewater surveillance analysis.

Inputs:
    data/raw/Wastewater_production/Country_WWctr_Percentage.txt
    data/raw/API_SP.POP.TOTL_DS2_en_csv_v2_174326/API_SP.POP.TOTL_DS2_en_csv_v2_174326.csv
Outputs:
    data/clean/wastewater_treatment.csv

Run from the repository root:
    python scripts/clean_wastewater_treatment.py
"""
import pandas as pd
import numpy as np

# --- 1. Load wastewater dataset ---
ww = pd.read_csv(
    "./data/raw/Wastewater_production/Country_WWctr_Percentage.txt",
    sep="\t"
)

# Ensure numeric
cols = ["WWc_Percent", "WWt_Percent", "WWr_Percent"]
ww[cols] = ww[cols].apply(pd.to_numeric, errors="coerce")


# --- 2. Load population dataset ---
pop = pd.read_csv(
    "./data/raw/API_SP.POP.TOTL_DS2_en_csv_v2_174326/API_SP.POP.TOTL_DS2_en_csv_v2_174326.csv",
    skiprows=4
)

# Drop the trailing empty column
pop = pop.drop(columns=["Unnamed: 69"], errors="ignore")


# --- 3. Keep only country rows (remove regions / aggregates) ---
# World Bank country codes are 3 letters; aggregate regions use longer codes.
pop = pop[pop["Country Code"].str.len() == 3].copy()


# --- 4. Get latest available population (prefer most recent non-null year) ---
year_cols = [c for c in pop.columns if c.isdigit()]

pop["pop"] = pop[year_cols].apply(
    lambda row: row[row.last_valid_index()]
    if row.last_valid_index() in year_cols
    else np.nan,
    axis=1
)

pop = pop[["Country Name", "Country Code", "pop"]]


# --- 5. Harmonize country names ---
country_fix = {
    "Korea Rep": "South Korea",
    "Korea Demo": "North Korea",
    "Congo Rep": "Republic of the Congo",
    "Congo Dem Republic": "Democratic Republic of the Congo",
    "Macedonia FYR": "North Macedonia",
    "Taiwan China": "Taiwan",
    "Iran (Islamic Republic of)": "Iran",
    "Viet Nam": "Vietnam",
    "Russian Federation": "Russia",
    "Bolivia (Plurinational State of)": "Bolivia",
    "Venezuela (Bolivarian Republic of)": "Venezuela",
    "Lao Peoples Democratic Republic": "Laos",
    "Syrian Arab Republic": "Syria",
    "Egypt, Arab Rep.": "Egypt"
}

ww["Country"] = ww["Country"].replace(country_fix)
pop["Country"] = pop["Country Name"].replace(country_fix)


# --- 6. Merge population into wastewater data ---
ww_pop = ww.merge(
    pop[["Country", "pop"]],
    on="Country",
    how="left"
)
ww_pop = ww_pop.rename(columns=lambda s: s.lower())
ww_pop = ww_pop[['country', 'region', 'economic_classification', 'pop', 'wwt_percent']]


# --- 7. Save to clean data file ---
output_path = "data/clean/wastewater_treatment.csv"
ww_pop.to_csv(output_path, index=False)
print(f"Saved cleaned wastewater data to {output_path}")
