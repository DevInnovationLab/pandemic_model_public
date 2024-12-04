# Fit exceedance functions and pandemic duration distributions
import yaml

import numpy as np
import pandas as pd
from scipy.stats import lognorm, genpareto 


# Set meta variables ---------------------------------

YRMIN = 1900
SMU_THRESH = 0.01
LAST_OBS_YEAR = 2024
WINDOW = 20
WINDOW_START = LAST_OBS_YEAR - WINDOW + 1

# Being lazy. Can refactor into functions later.

if __name__ == "__main__":
    # Load and clean data ---------------------------

    ## Read epidemic data from Marani et al. 
    df = pd.read_excel("data/epidemics_marani_240816.xlsx")
    df = df.sort_values(by='year_start', ascending=True).reset_index(drop=True)

    ## Subset data to 1900-present and to threshold-exceeding pandemics
    df = df[(df["year_start"] >= YRMIN)].reset_index(drop=True)
    df = df[(df["severity_smu"] >= SMU_THRESH)]

    ## Subset to all novel viral pandemics amd to respiratory viruses
    df_all = df[df['disease'].isin(['influenza', 'covid-19', 'ebola', 'hiv/aids'])
            ].reset_index(drop=True)

    df_resp = df[df['disease'].isin(['influenza', 'covid-19'])
                ].reset_index(drop=True)

    # Fit distributions --------------------------------

    ## All risk ----------------------------------------

    ### Fit generalized Pareto distribution on severities
    params_all_risk = genpareto.fit(df_all['severity_smu'], floc=SMU_THRESH)

    ### Get base arrival rate
    arrival_rate_all_risk = df_all[df_all['year_start'].between(WINDOW_START, LAST_OBS_YEAR, inclusive='both')
                                ].shape[0] / WINDOW

    ### All risk disribution parameters
    all_risk_distr_params = {
        'dist_family': 'GeneralizedPareto', # makedist() format (MATLAB)
        'min_severity': float(params_all_risk[1]),
        'min_severity_exceedance_prob': float(arrival_rate_all_risk),
        'max_severity': float(df_all['severity_smu'].max()),
        'params': {
            'k': float(params_all_risk[0]), # Shape
            'theta': float(params_all_risk[1]), # Location
            'sigma': float(params_all_risk[2]) # Scale

        }
    }

    with open("./output/arrival_distributions/all_risk_default.yaml", 'w') as f:
        yaml.dump(all_risk_distr_params, f)


    ## Respiratory pandemic distribution -------------------------
    params_resp = genpareto.fit(df_resp['severity_smu'], floc=SMU_THRESH)
    arrival_rate_resp = df_resp[df_resp['year_start'].between(WINDOW_START, LAST_OBS_YEAR, inclusive='both')
                                ].shape[0] / WINDOW

    resp_distr_params = {
        'dist_family': 'GeneralizedPareto', # makedist() format (MATLAB)
        'min_severity': float(params_resp[1]),
        'min_severity_exceedance_prob': float(arrival_rate_resp),
        'max_severity': float(df_resp['severity_smu'].max()),
        'params': {
            'k': float(params_resp[0]), # Shape
            'theta': float(params_resp[1]), # Location
            'sigma': float(params_resp[2]) # Scale

        }
    }

    with open("./output/arrival_distributions/resp_default.yaml", 'w') as f:
        yaml.dump(resp_distr_params, f)

    # Duration distributions ---------------------------------

    ## Set up minimum duration truncation
    duration_min = 0

    ## Fit log-normal distribution for all-viral and respiratory durations
    params_all_risk = lognorm.fit(df_all['duration'], floc = duration_min) 
    params_resp = lognorm.fit(df_resp['duration'], floc = duration_min) 

    all_risk_dur_params = {
        'dist_family': "Lognormal",
        'params': {
            'mu': float(np.log(params_all_risk[2])),
            'sigma': float(params_all_risk[0])
        }
    }

    resp_dur_params = {
        'dist_family': "Lognormal",
        'params': {
            'mu': float(np.log(params_resp[2])),
            'sigma': float(params_resp[0])
        }
    }

    # Save
    with open("./output/duration_distributions/all_risk_default.yaml", 'w') as f:
        yaml.dump(all_risk_dur_params, f)

    with open("./output/duration_distributions/resp_default.yaml", 'w') as f:
        yaml.dump(resp_dur_params, f)
