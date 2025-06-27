import pandas as pd
import yaml
from scipy.stats import genpareto

THRESH = 1e-2

if __name__ == "__main__":

  marani_raw = pd.read_excel("data/raw/epidemics_marani_240816.xlsx")

  ds = marani_raw[~marani_raw['disease'].isin(['covid-19', 'hiv/aids'])] # Remove new diseases we added
  ds = ds[ds['death_thousand'] >= 0] # Remove pandemics below death detectability threshold.
  ds = ds[ds['year_end'].between(1600, 1945)] # Subset to Marani's time window.

  ds['intensity'] = ds['severity_smu'] / ds['duration']

  # Save cleaned dataset for reference
  ds.to_csv("data/clean/marani_quasi_original.csv", index=False)

  # Fit Pareto to severity data
  # Fit generalized Pareto with floc=sev_min
  sev_ds = ds[ds['severity_smu'] >= THRESH]
  sev_fit = genpareto.fit(sev_ds['severity_smu'].values, floc=THRESH)
  
  # Save severity distribution parameters
  sev_config = {
    'dist_family': 'GeneralizedPareto',
    'params': {
      'k': float(sev_fit[0]),  # shape
      'sigma': float(sev_fit[2]),  # scale
      'theta': float(THRESH)  # location threshold
    }
  }

  with open('output/arrival_distributions/genpareto_quasi_original_marani_sev.yaml', 'w') as f:
    yaml.dump(sev_config, f)

  # Fit generalized Pareto with floc=int_min
  int_ds = ds[ds['intensity'] >= THRESH]
  int_fit = genpareto.fit(int_ds['intensity'].values, floc=THRESH)
  
  # Save intensity distribution parameters
  int_config = {
    'dist_family': 'GeneralizedPareto',
    'params': {
      'k': float(int_fit[0]),  # shape
      'sigma': float(int_fit[2]),  # scale
      'theta': float(THRESH)  # location threshold
    }
  }

  with open('output/arrival_distributions/genpareto_quasi_original_marani_int.yaml', 'w') as f:
      yaml.dump(int_config, f)


