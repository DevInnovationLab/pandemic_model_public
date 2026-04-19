"""clean_madhav_severity_exceedance.py — Clean Madhav et al. severity exceedance digitization.

Reads the digitized Figure 4 from Madhav et al. (2023) and writes a clean CSV
with standardised column names.

Inputs:
    data/raw/madhav_et_al_figure_4_digitized.csv  (2-row header)
Outputs:
    data/clean/madhav_et_al_severity_exceedance.csv

Run from the repository root:
    python python/scripts/clean_madhav_severity_exceedance.py
"""
import pandas as pd

df = pd.read_csv("./data/raw/madhav_et_al_figure_4_digitized.csv", skiprows=2, header=None)
df.columns = [
    "severity_central", "exceedance_central",
    "severity_upper",   "exceedance_upper",
    "severity_lower",   "exceedance_lower",
]

output_path = "./data/clean/madhav_et_al_severity_exceedance.csv"
df.to_csv(output_path, index=False)
print(f"Saved cleaned Madhav exceedance data to {output_path}")
