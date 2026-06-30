"""get_wastewater_moments.py — Compute regional wastewater-treatment-weighted population moments.

Loads the cleaned wastewater treatment dataset and prints summary statistics used
to calibrate the number of wastewater surveillance units in the model. Computes
treatment-weighted population by region and scales relative to US units.

Inputs:  data/clean/wastewater_treatment.csv
Outputs: printed to stdout

Run from the repository root:
    python scripts/get_wastewater_moments.py
"""

import math

import pandas as pd


if __name__ == "__main__":
    ww = pd.read_csv("./data/clean/wastewater_treatment.csv")

    # --- Regional population with wastewater treatment ---

    # Threshold of 30% treatment rate to identify countries with meaningful coverage.
    ww_filtered = ww[ww['wwt_percent'] > 30].copy()
    regional_pop = ww_filtered.groupby('region')['pop'].sum().sort_values(ascending=False)
    regional_pop_millions = regional_pop / 1_000_000

    print("Total population (millions) by region for countries with >30% wastewater treatment:")
    print(regional_pop_millions)

    # --- Treatment-weighted population by region ---

    # Weight each country's population by its treatment rate to get an effective
    # "covered population" figure for each region.
    ww_filtered['pop_weighted'] = ww_filtered['pop'] * ww_filtered['wwt_percent'] / 100
    regional_pop_weighted = ww_filtered.groupby('region')['pop_weighted'].sum().sort_values(ascending=False)
    regional_pop_weighted_millions = regional_pop_weighted / 1_000_000

    print("\nPopulation weighted by treatment rate (millions) by region:")
    print(regional_pop_weighted_millions)

    # --- Scale regions relative to US surveillance unit count ---

    us_weighted_pop = ww_filtered[ww_filtered['country'] == 'United States']['pop_weighted'].values[0] if 'United States' in ww['country'].values else None
    us_weighted_pop_millions = us_weighted_pop / 1_000_000 if us_weighted_pop is not None else None
    print(f"\nUS treatment population: {us_weighted_pop_millions:.2f} million")

    # Candidate US unit counts — scale each region proportionally and round up.
    us_units = [5, 13, 2]
    results = []

    for units in us_units:
        
        # Multiply by population weighted by treatment rate for each region
        scaled_values = (regional_pop_weighted_millions / us_weighted_pop_millions) * units
        
        # Round upward
        rounded_values = scaled_values.apply(math.ceil)
        
        # Sum the results
        total = rounded_values.sum()
        
        print(f"Scaled and rounded values by region:")
        print(rounded_values)
        print(f"Sum: {total}")
        
        results.append({'divisor': units, 'sum': total})

    print("\n" + "="*50)
    print("Summary:")
    for r in results:
        print(f"Divisor {r['divisor']}: Sum = {r['sum']}")
