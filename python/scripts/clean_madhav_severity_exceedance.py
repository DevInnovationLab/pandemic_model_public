"""clean_madhav_severity_exceedance.py — Clean Madhav et al. severity exceedance digitization.

Reads the digitized Figure 2.2 from Madhav et al. (2026) and writes a clean CSV
with standardised column names.

Inputs:
    data/raw/madhav_et_al_2026_figure_2d2_digitized.csv  (2-row header)
Outputs:
    data/clean/madhav_et_al_severity_exceedance.csv
"""

import numpy as np
import pandas as pd

df = pd.read_csv("./data/raw/madhav_et_al_2026_figure_2d2_digitized.csv", skiprows=2, header=None)
df.columns = [
    "deaths_millions_central", "exceedance_central",
    "deaths_millions_upper",   "exceedance_upper",
    "deaths_millions_lower",   "exceedance_lower",
]

# Convert deaths to severity (deaths per 10,000)
for spline in ["central", "upper", "lower"]:
    df[f"severity_{spline}"] = df[f"deaths_millions_{spline}"] * 1e6 / (7.8e9 / 10000) # They use 7.8 billion population estimate

# Add lowest two data points from Table 2.4
df = pd.concat([df, pd.DataFrame({
    "severity_central": [0.001, 0.002],
    "exceedance_central": [20.0, 10.0],
    "severity_upper": [np.nan, np.nan],
    "exceedance_upper": [np.nan, np.nan],
    "severity_lower": [np.nan, np.nan],
    "exceedance_lower": [np.nan, np.nan],
})])

# Divide all exceedance values by 100 to get annual exceedance risk
for spline in ["central", "upper", "lower"]:
    df[f"exceedance_{spline}"] = df[f"exceedance_{spline}"] / 100

output_path = "./data/clean/madhav_et_al_severity_exceedance.csv"
df.to_csv(output_path, index=False)
print(f"Saved cleaned Madhav exceedance data to {output_path}")
