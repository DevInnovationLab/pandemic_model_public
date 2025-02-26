# Fit exceedance functions and pandemic duration distributions
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import yaml
from scipy.stats import genpareto, lognorm, truncpareto

from pandemic_model.stats.pareto import fit_trunc_pareto, trunc_pareto_neg_log_likelihood


def fit_truncated_pareto(data,
                         lower_bound,
                         upper_bound=1e4,
                         init_values=None,
                         verbose=False):
    """Fit truncated Pareto distribution to data using multiple initializations.
    
    Args:
        data (np.ndarray): Data to fit distribution to
        lower_bound (float): Lower bound for truncation
        upper_bound (float): Upper bound for truncation, defaults to 1e4
        verbose (bool): If True, print results from each initialization attempt
        
    Returns:
        tuple: Best fit parameters (b, loc, scale) and parameters dictionary for MATLAB
    """
    if init_values is None:
        init_values = [
            (2.0, lower_bound * 0.1),  # (b_init, loc_init at 10% of lower bound)
            (1.5, lower_bound * 0.01),  # 1% of lower bound
            (3.0, lower_bound * 0.001)  # 0.1% of lower bound
        ]

    best_fit = None
    best_nll = float('inf')

    for b_init, loc_init in init_values:
        try:
            b, loc, scale = fit_trunc_pareto(
                data,
                lower_bound=lower_bound,
                upper_bound=upper_bound,
                b_init=b_init,
                loc_init=loc_init
            )
            
            # Calculate negative log likelihood to compare fits
            nll = trunc_pareto_neg_log_likelihood(
                [b, loc],
                data,
                lower_bound,
                upper_bound
            )
            
            if verbose:
                print(f"Init values b={b_init}, loc={loc_init}:")
                print(f"  Fitted parameters: b={b:.4f}, loc={loc:.4f}, scale={scale:.4f}")
                print(f"  Negative log likelihood: {nll:.4f}\n")
            
            if nll < best_nll:
                best_fit = (b, loc, scale)
                best_nll = nll
                
        except RuntimeError as e:
            if verbose:
                print(f"Fitting failed for init values b={b_init}, loc={loc_init}: {str(e)}\n")
            continue
    
    if best_fit is None:
        raise RuntimeError("Failed to fit truncated Pareto distribution with any initialization")
        
    b, loc, scale = best_fit

    if verbose:
        print(f"Best fit parameters: b={b:.4f}, loc={loc:.4f}, scale={scale:.4f}")

    # Create parameter dictionary for MATLAB
    params_dict = {
        'dist_family': 'TruncatedPareto',
        'params': {
            'b': float(b),
            'c': float((upper_bound - loc) / scale),
            'loc': float(loc),
            'scale': float(scale),
        }
    }
    
    return best_fit, params_dict


def plot_truncpareto_exceedance(df: pd.DataFrame,
                                dist: dict,
                                title: str = "Severity exceedance probability") -> plt.Figure:
    """
    Plot severity exceedance probability distribution with empirical data points
    
    Parameters:
    -----------
    df : pd.DataFrame
        DataFrame containing severity data with columns 'severity_smu' and 'disease'
    params : dict
        Distribution dict detailing distribution family and parameters.
    title : str, optional
        Plot title, defaults to "Severity exceedance probability"
        
    Returns:
    --------
    matplotlib.figure.Figure
        The plotted figure
    """
    # Calculate empirical exceedance probabilities
    df = df.sort_values('severity_smu', ascending=False)
    params = dist['params']
    arrival_rate = dist['arrival_rate']
    df['exceed_empirical'] = (np.arange(1, len(df) + 1) / len(df)) * arrival_rate
    
    # Get distribution exceedance
    if dist['dist_family'] == 'TruncatedPareto':  # Truncated Pareto case
        # Use scipy's truncpareto for CDF calculation
        b, c, loc, scale = params['b'], params['c'], params['loc'], params['scale']
        lower_bound = params['scale'] + params['loc']
        upper_bound = params['c'] * params['scale'] + params['loc']
        pd = truncpareto(b=b, c=c, loc=loc, scale=scale)

        x = np.logspace(np.log10(lower_bound), np.log10(upper_bound), 1000)
        exceedance = (1 - pd.cdf(x)) * arrival_rate
    else:  # Original power law case
        raise ValueError(f"{dist['dist_family']} not implemented for plotting yet.")
    
    # Create plot
    plt.figure(figsize=(10, 6))
    
    # Plot theoretical curve and data points
    plt.plot(x, exceedance, color='red', linestyle='--', label='Exceedance function')
    plt.scatter(df['severity_smu'], df['exceed_empirical'], 
               marker='o', color='red', facecolor='none', label='Data points')
    
    # Add text labels for diseases
    for _, r in df.iterrows():
        plt.text(r['severity_smu'] * 1.15, r['exceed_empirical'], r['disease'])
    
    # Style figure
    plt.xscale('log')
    plt.xlim(lower_bound, upper_bound)
    plt.xlabel("Deaths / 10,000 Population")
    plt.ylabel("Exceedance probability")
    plt.title(title)
    plt.gca().spines['top'].set_visible(False)
    plt.gca().spines['right'].set_visible(False)
    plt.legend()
    plt.tight_layout()
    
    return plt.gcf()


# Set meta variables ---------------------------------

YRMIN = 1900
SMU_THRESH = 0.01
LAST_OBS_YEAR = 2024
WINDOW = 20
WINDOW_START = LAST_OBS_YEAR - WINDOW + 1

if __name__ == "__main__":
    # Load and clean data ---------------------------

    ## Read epidemic data from Marani et al. 
    df = pd.read_excel("./data/raw/epidemics_marani_240816.xlsx")
    df = df.sort_values(by='year_start', ascending=True).reset_index(drop=True)

    ## Subset data to 1900-present and to threshold-exceeding pandemics
    df = df[(df["year_start"] >= YRMIN)].reset_index(drop=True)
    df = df[(df["severity_smu"] >= SMU_THRESH)]

    ## Get original COVID-19 severity and replace with ex ante estimate
    original_covid_severity = df.loc[df['disease'] == 'covid-19', 'severity_smu'].values[0]

    with open("./data/clean/inverted_covid_severity.yaml") as f:
        estimated_covid_severity = yaml.safe_load(f)

    ex_ante_covid_severity = estimated_covid_severity['ex_ante_severity']
    df.loc[df['disease'] == 'covid-19', 'severity_smu'] = ex_ante_covid_severity

    ## Subset to all novel viral pandemics amd to respiratory viruses
    df_all = df[df['disease'].isin(['influenza', 'covid-19', 'ebola', 'hiv/aids'])
            ].reset_index(drop=True)

    df_resp = df[df['disease'].isin(['influenza', 'covid-19'])
                ].reset_index(drop=True)

    # Get empirical exceedance for ex ante COVID severity
    df_all = df_all.sort_values('severity_smu', ascending=False)
    df_all['exceed_empirical'] = np.arange(1, len(df_all) + 1) / len(df_all)
    arrival_rate_all_risk = df_all['year_start'].between(WINDOW_START, LAST_OBS_YEAR, inclusive='both').sum() / WINDOW
    original_covid_exceed = df_all.loc[df_all['disease'] == 'covid-19', 'exceed_empirical'].values[0] * arrival_rate_all_risk

    df_resp = df_resp.sort_values('severity_smu', ascending=False)
    df_resp['exceed_empirical'] = np.arange(1, len(df_resp) + 1) / len(df_resp)
    arrival_rate_resp = df_resp['year_start'].between(WINDOW_START, LAST_OBS_YEAR, inclusive='both').sum() / WINDOW
    original_covid_exceed_resp = df_resp.loc[df_resp['disease'] == 'covid-19', 'exceed_empirical'].values[0] * arrival_rate_resp

    # Fit distributions --------------------------------

    ## Response threshold -------------------------------
    response_threshold = (ex_ante_covid_severity / df.loc[df['disease'] == 'covid-19', 'duration'].values)[0] / 2
    outdict = {'response_threshold': float(response_threshold)}

    with open("./output/response_threshold.yaml", 'w') as f:
        yaml.dump(outdict, f)

    ## Severity distributions ----------------------------------------

    ### Create outdir and save distribution params
    severity_dist_root = Path("./output/severity_distributions").resolve()
    severity_dist_root.mkdir(parents=True, exist_ok=True)

    # Create figures directory
    fig_dir = severity_dist_root / "figures"
    fig_dir.mkdir(parents=True, exist_ok=True)


    ### Fit for all risks
    _, truncpareto_all_risk_params = fit_truncated_pareto(df_all['severity_smu'].values, SMU_THRESH, verbose=True)
    truncpareto_all_risk_params['arrival_rate'] = float(arrival_rate_all_risk)
    
    outpath = severity_dist_root / "truncpareto_all_risk.yaml"
    with open(outpath, 'w') as f:
        yaml.dump(truncpareto_all_risk_params, f)
    

    ### Half arrival rate
    truncpareto_all_risk_params_half_arrival = truncpareto_all_risk_params.copy()
    truncpareto_all_risk_params_half_arrival['arrival_rate'] = truncpareto_all_risk_params_half_arrival['arrival_rate'] / 2

    outpath = severity_dist_root / "truncpareto_all_risk_half_arrival.yaml"
    with open(outpath, 'w') as f:
        yaml.dump(truncpareto_all_risk_params_half_arrival, f)


    ### Double arrival rate
    truncpareto_all_risk_params_double_arrival = truncpareto_all_risk_params.copy()
    truncpareto_all_risk_params_double_arrival['arrival_rate'] = truncpareto_all_risk_params_double_arrival['arrival_rate'] * 2

    outpath = severity_dist_root / "truncpareto_all_risk_double_arrival.yaml"
    with open(outpath, 'w') as f:
        yaml.dump(truncpareto_all_risk_params_double_arrival, f)


    ### Truncate at half extinction
    _, truncpareto_all_risk_half_ext = fit_truncated_pareto(df_all['severity_smu'].values, lower_bound=SMU_THRESH, upper_bound=5e3, verbose=True)
    truncpareto_all_risk_half_ext['arrival_rate'] = float(arrival_rate_all_risk)

    outpath = severity_dist_root / "truncpareto_all_risk_truncate_half.yaml"
    with open(outpath, 'w') as f:
        yaml.dump(truncpareto_all_risk_half_ext, f)


    ### Fit for respiratory risks
    _, truncpareto_resp_params = fit_truncated_pareto(df_resp['severity_smu'].values, SMU_THRESH, verbose=True)
    truncpareto_resp_params['arrival_rate'] = float(arrival_rate_resp)
    
    outpath = severity_dist_root / "truncpareto_resp.yaml"
    with open(outpath, 'w') as f:
        yaml.dump(truncpareto_resp_params, f)


    ### Fit Generalized Pareto params to compare with old approach
    shape, loc, scale = genpareto.fit(df_all['severity_smu'], floc=SMU_THRESH)

    genpareto_all_risk_params = {
        'dist_family': 'GeneralizedPareto', # makedist() format (MATLAB)
        'min_severity': float(loc),
        'arrival_rate': float(arrival_rate_all_risk),
        'max_severity': float(df_all['severity_smu'].max()), # Truncate at Spanish flu
        'params': {
            'k': float(shape), # Shape
            'theta': float(loc), # Location
            'sigma': float(scale) # Scale
        }
    }

    outpath = severity_dist_root / "genpareto_all_risk_trunc_spflu.yaml"
    with open(outpath, 'w') as f:
        yaml.dump(genpareto_all_risk_params, f)


    ## Plot severity distributions
    def add_original_covid_point(is_resp=False):
        """Add the original COVID-19 severity point and connecting line to current plot."""
        exceed_val = original_covid_exceed_resp if is_resp else original_covid_exceed
        plt.scatter(original_covid_severity, exceed_val, 
                   marker='o', color='gray', alpha=0.5, 
                   label='Original COVID-19 severity (not used in fit)')
        plt.plot([original_covid_severity, ex_ante_covid_severity], 
                 [exceed_val, exceed_val], 
                 'gray', linestyle='--', alpha=0.5)
        plt.legend()

    # Plot severity distributions
    fig_all = plot_truncpareto_exceedance(df_all, truncpareto_all_risk_params, 
                                          title="Severity exceedance probability - All risks")
    add_original_covid_point()
    
    # Plot half arrival rate
    fig_half = plot_truncpareto_exceedance(df_all, truncpareto_all_risk_params_half_arrival,
                                           title="Severity exceedance probability - Half arrival rate")
    add_original_covid_point()

    # Plot double arrival rate
    fig_double = plot_truncpareto_exceedance(df_all, truncpareto_all_risk_params_double_arrival,
                                             title="Severity exceedance probability - Double arrival rate")
    add_original_covid_point()

    # Plot half extinction truncation
    fig_trunc = plot_truncpareto_exceedance(df_all, truncpareto_all_risk_half_ext,
                                            title="Severity exceedance probability - Half extinction truncation")
    add_original_covid_point()
    
    fig_resp = plot_truncpareto_exceedance(df_resp, truncpareto_resp_params,
                                           title="Severity exceedance probability - Respiratory risks")
    add_original_covid_point(is_resp=True)

    # Save plots
    fig_all.savefig(fig_dir / "severity_exceedance_all_risks.jpg", dpi=400)
    fig_half.savefig(fig_dir / "severity_exceedance_half_arrival.jpg", dpi=400)
    fig_double.savefig(fig_dir / "severity_exceedance_double_arrival.jpg", dpi=400)
    fig_trunc.savefig(fig_dir / "severity_exceedance_half_truncation.jpg", dpi=400)
    fig_resp.savefig(fig_dir / "severity_exceedance_respiratory.jpg", dpi=400)

    ## Duration distributions ---------------------------------

    ### Set up minimum duration truncation
    duration_min = 0

    ### Fit log-normal distribution for all-viral and respiratory durations
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

    ## Save
    outroot = Path("./output/duration_distributions").resolve()
    outroot.mkdir(parents=True, exist_ok=True)

    outpath = outroot / "all_risk.yaml"
    with open(outpath, 'w') as f:
        yaml.dump(all_risk_dur_params, f)

    outpath = outroot / "resp.yaml"
    with open(outpath, 'w') as f:
        yaml.dump(resp_dur_params, f)
