# Estimate relationship between severity and percentage economic losses
import numpy as np
import pandas as pd
import yaml
import matplotlib.pyplot as plt
from scipy.special import gammaln
from sklearn.linear_model import LinearRegression, PoissonRegressor
from sklearn.metrics import r2_score, log_loss


# Set a consistent styling for academic figures
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
    econ_loss_raw = pd.read_excel("data/raw/Economic damages source review.xlsx", sheet_name="Updated numbers")

    # Rename and preprocess columns
    econ_loss = econ_loss_raw.rename(columns={'Fraction GDP losses': 'pct_gdp_loss',
                                              'Mortality (SMU)': 'mortality_smu',
                                              'Disease': 'disease'})
    econ_loss[['pct_gdp_loss']] = econ_loss[['pct_gdp_loss']] * 100
    econ_loss = econ_loss[['pct_gdp_loss', 'mortality_smu', 'disease']]
    econ_loss_clean = econ_loss.dropna(axis=0) # Drop rows with missing values

    # ------ Fit models --------------------------------

    lm = LinearRegression()
    pm = PoissonRegressor(alpha=0) # Presumably don't want regularization

    X = np.log(econ_loss_clean[['mortality_smu']]) # Log transform
    y = econ_loss_clean['pct_gdp_loss']
    
    lm.fit(X, y)
    pm.fit(X, y)

    # ------ Plot models -----------------------------------



    # McFadden's Pseudo R^2
    def mcf_pseudo_r2(y, y_pred):
        # Log-likelihood of the fitted model
        ll_model = np.sum(y * np.log(y_pred) - y_pred - gammaln(y + 1))
    
        # Log-likelihood of the null model (mean response)
        mean_response = np.mean(y)
        ll_null = np.sum(y * np.log(mean_response) - mean_response - gammaln(y + 1))

        return 1 - (ll_model / ll_null)
    
    # Set colors
    col_linear = '#ff7f0e'
    col_poisson = '#2ca02c'

    # Calculate goodness of fit scores
    r2_linear = r2_score(y, lm.predict(X))
    r2_poisson = mcf_pseudo_r2(y, pm.predict(X))

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

    # Fitted line for linear scale
    log_xrange = np.linspace(np.log(econ_loss_clean['mortality_smu'].min() / 2), np.log(econ_loss_clean['mortality_smu'].max()), 100).reshape(-1, 1)
    y_pred_linear = lm.predict(log_xrange)
    y_pred_poisson = pm.predict(log_xrange)
    ax.plot(np.exp(log_xrange), y_pred_linear, linewidth=2.5, color=col_linear, label='Linear')
    ax.plot(np.exp(log_xrange), y_pred_poisson, linewidth=2.5, color=col_poisson, label='Poisson')
    ax.set_xscale('log')

    # Labels and title
    ax.set_title(r"Pandemic deaths per 10,000 vs percent GDP loss")
    ax.set_xlabel("Mortality (Deaths per 10,000)")
    ax.set_ylabel(r"% GDP Loss")
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    # Add R^2 and Deviance values to the plot
    ax.text(0.80, 0.15, rf"$R^2_{{\mathrm{{linear}}}} = {r2_linear:.3f}$", 
            transform=ax.transAxes, verticalalignment='top', color=col_linear)
    ax.text(0.80, 0.10, rf"$R^2_{{\mathrm{{poisson}}}} = {r2_poisson:.3f}$", 
            transform=ax.transAxes, verticalalignment='top', color=col_poisson)
    
    # Add line labels
    ax.text(0.45, 0.43, "Linear", transform=ax.transAxes, color=col_linear)
    ax.text(0.55, 0.25, "Poisson", transform=ax.transAxes, color=col_poisson)

    # Save the plot
    plt.tight_layout()
    plt.savefig("output/econ_loss_models/default_models.png", dpi=400)

    # ------ Save models -----------------------------------

    # Linear model
    lm_dict = {
        'family': 'linear',
        'params': {
            'intercept': float(lm.intercept_),
            'coefs': [float(beta) for beta in lm.coef_]
        }
    }

    with open("output/econ_loss_models/linear_model.yaml", "w") as f:
        yaml.dump(lm_dict, f)

    # Poisson model
    poisson_dict = {
        'family': 'poisson',
        'params': {
            'intercept': float(pm.intercept_),
            'coefs': [float(beta) for beta in lm.coef_]
        }
    }

    with open("output/econ_loss_models/poisson_model.yaml", "w") as f:
        yaml.dump(poisson_dict, f)
