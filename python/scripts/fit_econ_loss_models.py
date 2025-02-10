# Estimate relationship between severity and percentage economic losses
from pathlib import Path

import numpy as np
import pandas as pd
import yaml
import matplotlib.pyplot as plt
from sklearn.linear_model import PoissonRegressor

from pandemic_model.stats import mcf_pseudo_r2


# Set consistent figure style
plt.style.use('seaborn-v0_8-white')
plt.rcParams.update({
    'font.size': 14,
    'axes.labelsize': 15,
    'axes.titlesize': 18,
    'xtick.labelsize': 14,
    'ytick.labelsize': 14,
    'xtick.bottom': True,
    'xtick.major.size': 8,
    'xtick.major.width': 1,
    'ytick.left': True,
    'ytick.major.size': 5,
    'ytick.major.width': 1,
})

# Clean up if you later fit more models
if __name__ == "__main__":

    # ------ Clean -----------------------------------
    econ_loss_raw = pd.read_excel("./data/raw/Economic damages source review.xlsx", sheet_name="Updated numbers")

    # Rename and preprocess columns
    econ_loss = econ_loss_raw.rename(columns={'Fraction GDP losses': 'pct_gdp_loss',
                                              'Mortality (SMU)': 'mortality_smu',
                                              'Disease': 'disease'})
    econ_loss[['pct_gdp_loss']] = econ_loss[['pct_gdp_loss']] * 100
    econ_loss = econ_loss[['pct_gdp_loss', 'mortality_smu', 'disease']]
    econ_loss_clean = econ_loss.dropna(axis=0) # Drop rows with missing values

    # ------ Fit models --------------------------------


    X = np.log(econ_loss_clean[['mortality_smu']]) # Log transform
    y = econ_loss_clean['pct_gdp_loss']
    
    pm = PoissonRegressor(alpha=0) # No regularization
    pm.fit(X, y)
    mcf_poisson = mcf_pseudo_r2(y, pm.predict(X))

    # ------ Plot models -----------------------------------
    
    # Set colors
    col_poisson = '#2ca02c'

    # Plot data 
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.scatter(econ_loss_clean['mortality_smu'], econ_loss_clean['pct_gdp_loss'], color="steelblue", s=80, alpha=0.7, label="Data Points")

    # Annotate each point with the disease name
    for i, disease in enumerate(econ_loss_clean['disease']):
        ax.text(econ_loss_clean['mortality_smu'].iloc[i] * 1.22,
                econ_loss_clean['pct_gdp_loss'].iloc[i] * 0.98, 
                disease, 
                fontsize=12,
                ha='left',
                va='top',
                color='darkblue')

    # Labels and title
    ax.set_title(r"Pandemic deaths per 10,000 vs percent GDP loss")
    ax.set_xlabel("Mortality (Deaths per 10,000)")
    ax.set_ylabel(r"% GDP Loss")
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    # Log scale and tight layout 
    ax.set_xscale('log')
    plt.tight_layout()

    # Fitted lines for linear scale
    log_xrange = np.linspace(
        np.log(econ_loss_clean['mortality_smu'].min() / 2),
        np.log(econ_loss_clean['mortality_smu'].max()), 100
    ).reshape(-1, 1)

    y_pred_poisson = pm.predict(log_xrange)

    # Plot poisson curve and save
    ax.plot(np.exp(log_xrange), y_pred_poisson, linewidth=2.5, color=col_poisson, label='Poisson')
    ax.text(0.80, 0.10, rf"$R^2_{{\mathrm{{McF}}}} = {mcf_poisson:.3f}$", 
            transform=ax.transAxes, verticalalignment='top', color=col_poisson)

    # Save figure
    outdir = Path("./output/econ_loss_models").resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    figpath = outdir / "poisson_model.png"
    plt.savefig(figpath, dpi=400)

    poisson_dict = {
        'family': 'poisson',
        'params': {
            'intercept': float(pm.intercept_),
            'coefs': [float(beta) for beta in pm.coef_]
        }
    }

    outpath = outdir / "poisson_model.yaml"
    with open(outpath, "w") as f:
        yaml.dump(poisson_dict, f)
