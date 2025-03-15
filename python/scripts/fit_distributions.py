# Fit exceedance functions and pandemic duration distributions
from pathlib import Path
from typing import Literal

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import yaml
from scipy.stats import genpareto, lognorm

from pandemic_model.constants import NON_RESP_VIRUSES, RECURRING_VIRUSES
from pandemic_model.stats.mevd import MEVD
from pandemic_model.stats.pareto import TruncatedGPD
from pandemic_model.utils import get_annual_arrival_counts


def get_pareto_dist(df: pd.DataFrame,
                    col: Literal['severity', 'intensity'],
                    disttype: Literal['gpd', 'trunc'],
                    lower_bound: float = 1e-2,
                    upper_bound: float = 1e4):
    """Get exceedance distribution."""
    fit_df = df.copy()

    # Drop observations below lower bound
    fit_df = fit_df[fit_df[col] >= lower_bound]
            
    if disttype == 'gpd':
        c, loc, scale = genpareto.fit(fit_df[col], floc=lower_bound)
        dist = genpareto(c=c, loc=loc, scale=scale)                         
    else:
        ub = max(upper_bound, fit_df[col].max())
        dist = TruncatedGPD.fit(data=fit_df[col], fixed={'loc': lower_bound, 'upper': ub})

    return dist

# Set meta variables ---------------------------------

YRMIN = 1900
SMU_THRESH = 0.01
LAST_OBS_YEAR = 2024
ARRIVAL_WINDOW = [1900, 2024]
UPPER_BOUND = {'severity': 172, 'intensity': 58}

if __name__ == "__main__":
    # Load and clean data ---------------------------

    ## Read all epidemics data
    all_epidemics_ds = pd.read_excel("./data/raw/epidemics_marani_240816.xlsx")
    all_epidemics_ds = all_epidemics_ds.rename(columns={'severity_smu': 'severity'}) # Name change simplifies code later

    bernstein_intersect_ds = pd.read_excel("./data/raw/novel_resp_241228.xlsx")
    bernstein_intersect_ds = bernstein_intersect_ds.rename(columns={'severity_smu': 'severity'})  # Name change simplifies code later

    ## Filter down to recent respiratory viruses
    modern_viral_ds = all_epidemics_ds[(all_epidemics_ds['year_start'] >= 1900) & (all_epidemics_ds['type'].str.contains('viral', case=False))]
    modern_resp_ds = modern_viral_ds[~modern_viral_ds['disease'].isin(RECURRING_VIRUSES + NON_RESP_VIRUSES)]

    ## Get original COVID-19 severity and replace with ex ante estimate
    original_covid_severity = all_epidemics_ds.loc[all_epidemics_ds['disease'] == 'covid-19', 'severity'].values[0]

    with open("./data/clean/inverted_covid_severity.yaml") as f:
        estimated_covid_severity = yaml.safe_load(f)

    ex_ante_covid_severity = estimated_covid_severity['ex_ante_severity']

    for df in [bernstein_intersect_ds, modern_resp_ds]:
        df.loc[df['disease'] == 'covid-19', 'severity'] = ex_ante_covid_severity
        df.loc[df['disease'] == 'hiv/aids', 'duration'] = 46 # Double length of time to peak


    bernstein_intersect_ds['intensity'] = bernstein_intersect_ds['severity'] / bernstein_intersect_ds['duration']
    modern_resp_ds['intensity'] = modern_resp_ds['severity'] / modern_resp_ds['duration']

    # Fit distributions --------------------------------

    ## Response threshold -------------------------------
    response_threshold = (ex_ante_covid_severity / df.loc[df['disease'] == 'covid-19', 'duration'].values)[0] / 2
    outdict = {'response_threshold': float(response_threshold)}

    with open("./output/response_threshold.yaml", 'w') as f:
        yaml.dump(outdict, f)

    ## Severity distributions ----------------------------------------

    ### Create outdir and save distribution params
    arrival_dist_root = Path("./output/severity_distributions").resolve()
    arrival_dist_root.mkdir(parents=True, exist_ok=True)

    # Create figures directory
    fig_dir = arrival_dist_root / "figures"
    fig_dir.mkdir(parents=True, exist_ok=True)

    ## Fit all models
    dfs = {'modern_resp': modern_resp_ds, 'bernstein': bernstein_intersect_ds}
    fig, axs = plt.subplots(1, 2, figsize=(16, 8))

    for ds_name, df in dfs.items():
        for metric in ['intensity', 'severity']:
            for lower_bound in [0.01, 1]:
                upper_bound = UPPER_BOUND[metric]
                dist_family = 'gpd'
                base_dist = get_pareto_dist(df, metric, dist_family, lower_bound, upper_bound)
                shape = base_dist.kwds['c']  # shape (k)
                loc = base_dist.kwds['loc']      # location (theta) 
                scale = base_dist.kwds['scale']  # scale (sigma)

                arrival_count_df = df[df[metric] >= lower_bound]
                arrival_counts = get_annual_arrival_counts(arrival_count_df, *ARRIVAL_WINDOW)
                arrival_counts_list = arrival_counts.tolist()

                dist_config = {
                    'metric': metric,
                    'lower_bound': lower_bound,
                    'upper_bound': upper_bound,
                    'base_dist_family': 'GeneralizedPareto',
                    'truncation': 'sharp' if dist_family == 'gpd' else 'formal',
                    'base_dist_params': { # Will have to revise this if we use other distributions
                        'k': float(shape),
                        'theta': float(loc),
                        'sigma': float(scale)
                    },
                    'arrival_counts': arrival_counts_list
                }

                outpath = arrival_dist_root / f"{ds_name}_{metric}_{dist_family}_{lower_bound}.yaml"
                with open(outpath, 'w') as f:
                    yaml.dump(dist_config, f)

                # Plot survival functions for sanity check
                mevd = MEVD(arrival_counts, base_dist)

                # Plot MEVD survival function with extended domain
                x_min = lower_bound / 10  # One order below lower bound
                x_max = upper_bound * 10  # One order above upper bound
                x = np.logspace(np.log10(x_min), np.log10(x_max), 1000)
                
                # Calculate survival but force to 0 above upper bound
                survival = 1 - mevd.cdf(x)
                survival[x > upper_bound] = 0

                ax_idx = 0 if metric == 'severity' else 1
                axs[ax_idx].semilogx(x, survival, label=f'{ds_name}, lb={lower_bound}')
                axs[ax_idx].set_xlabel(metric.capitalize())
                axs[ax_idx].set_ylabel('Exceedance probability')
                axs[ax_idx].grid(True)
                axs[ax_idx].legend()
                axs[ax_idx].set_title(f'MEVD Survival Function - {metric.capitalize()}')
                axs[ax_idx].set_ylim(0, 0.3)

    plt.tight_layout()
    plt.savefig(fig_dir / 'mevd_survival_functions.png')
    plt.close()

    ## Duration distributions ---------------------------------

    ### Set up minimum duration truncation and plotting
    fig, ax = plt.subplots(figsize=(10, 6))
    outroot = Path("./output/duration_distributions").resolve()
    outroot.mkdir(parents=True, exist_ok=True)
    
    max_duration = 10

    for ds_name, df in dfs.items():
        for metric in ['intensity', 'severity']:
            for lower_bound in [0.01, 1]:
                # Filter data above lower bound
                fit_df = df[df[metric] >= lower_bound]
                
                # Fit lognormal distribution
                params = lognorm.fit(fit_df['duration'], floc=0)
                
                # Create distribution config
                dur_params = {
                    'dist_family': "Lognormal",
                    'max_duration': max_duration,
                    'params': {
                        'mu': float(np.log(params[2])),
                        'sigma': float(params[0]),
                        'lower_bound': lower_bound
                    }
                }
                
                # Save config               
                outpath = outroot / f"{ds_name}_duration_lb_{lower_bound}_{metric}.yaml"
                with open(outpath, 'w') as f:
                    yaml.dump(dur_params, f)
                    
                # Plot fitted distribution
                x = np.linspace(0, max_duration + 1, 1000)
                fitted_dist = lognorm(params[0], loc=params[1], scale=params[2])
                survival = fitted_dist.sf(x)
                survival[x > max_duration] = 0
                
                ax.plot(x, survival, label=f'{ds_name}, lb={lower_bound}, metric={metric}')
    
    ax.set_xlabel('Duration (years)')
    ax.set_ylabel('Exceedance probability') 
    ax.grid(True)
    ax.legend()
    ax.set_title('Duration Distribution Survival Functions')
    
    plt.tight_layout()
    plt.savefig(fig_dir / 'duration_survival_functions.png')
    plt.close()
