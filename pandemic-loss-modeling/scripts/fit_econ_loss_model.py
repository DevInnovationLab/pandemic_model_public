# Estimate relationship between severity and percentage economic losses
import numpy as np
import pandas as pd
import yaml
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score


# Set a consistent styling for academic figures
plt.style.use('seaborn-v0_8-white')
plt.rcParams.update({
    'font.size': 14,
    'axes.labelsize': 16,
    'axes.titlesize': 18,
    'xtick.labelsize': 14,
    'ytick.labelsize': 14
})

# Clean up if you later fit more models
if __name__ == "__main__":
    # --------- Clean --------------------------
    econ_loss_raw = pd.read_excel("data/raw/Economic damages source review.xlsx", sheet_name="Updated numbers")

    # Rename and preprocess columns
    econ_loss = econ_loss_raw.rename(columns={'Fraction GDP losses': 'pct_gdp_loss',
                                              'Mortality (SMU)': 'mortality_smu',
                                              'Disease': 'disease'})
    econ_loss[['pct_gdp_loss']] = econ_loss[['pct_gdp_loss']] * 100
    econ_loss = econ_loss[['pct_gdp_loss', 'mortality_smu', 'disease']]

    # Drop rows with missing values
    econ_loss_clean = econ_loss.dropna(axis=0)

    # ------ Fit --------------------------------

    # Fit regression on log-transformed data
    model = LinearRegression()
    X = np.log(econ_loss_clean[['mortality_smu']])
    y = np.log(econ_loss_clean['pct_gdp_loss'])
    model.fit(X, y)

    # Save model results
    results = {'intercept': float(model.intercept_),
               'coef': float(model.coef_[0])}
    
    print(f"""Economic model parameter estimates\n
              Intercept: {results['intercept']}\n
              Coefficient: {results['coef']}""")

    with open("output/econ_loss_models/default_model.yaml", "w") as f:
        yaml.dump(results, f)
    
    # ------ Plot ----------------------------------

    # Calculate R^2 in log space
    r_squared_log = model.score(X, y)
    print(f"R^2 in log space: {r_squared_log}")

    # Calculate R^2 in linear space
    y_pred_log = model.predict(X)                      # Log-space predictions
    y_pred_linear = np.exp(y_pred_log)                 # Transform predictions back to linear space
    r_squared_linear = r2_score(econ_loss_clean['pct_gdp_loss'], y_pred_linear)
    print(f"R^2 in linear space: {r_squared_linear}")

    # Plot data and fitted line (linear scale)
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.scatter(econ_loss_clean['mortality_smu'], econ_loss_clean['pct_gdp_loss'], color="steelblue", s=80, alpha=0.7, label="Data Points")

    # Annotate each point with the disease name
    for i, disease in enumerate(econ_loss_clean['disease']):
        ax.text(econ_loss_clean['mortality_smu'].iloc[i] * 1.05,
                econ_loss_clean['pct_gdp_loss'].iloc[i] * 1.02, 
                disease, 
                fontsize=12,
                ha='right',
                va='bottom',
                color='darkblue')

    # Fitted line for linear scale
    x_range = np.linspace(econ_loss_clean['mortality_smu'].min(), econ_loss_clean['mortality_smu'].max(), 100)
    y_pred = np.exp(results['intercept'] + results['coef'] * np.log(x_range))
    ax.plot(x_range, y_pred, color="crimson", linewidth=2.5, label="Fitted Model")

    # Labels and title
    ax.set_xlabel("Mortality (SMU)")
    ax.set_ylabel(r"% GDP Loss")
    ax.set_title("Relationship between Mortality Severity and Economic Losses (Linear Scale)", fontweight='bold')

    # Add R^2 values to the plot
    ax.text(0.05, 0.90, rf"$R^2_{{\mathrm{{log\ space}}}} = {r_squared_log:.3f}$", 
            transform=ax.transAxes, verticalalignment='top', color="green")
    ax.text(0.05, 0.85, rf"$R^2_{{\mathrm{{linear\ space}}}} = {r_squared_linear:.3f}$", 
            transform=ax.transAxes, verticalalignment='top', color="blue")

    # Save the plot
    plt.tight_layout()
    plt.savefig("output/econ_loss_models/default_model_linear.png", dpi=400)

    # Plot data and fitted line (log scale)
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.scatter(econ_loss_clean['mortality_smu'], econ_loss_clean['pct_gdp_loss'], color="steelblue", s=80, alpha=0.7, label="Data Points")

    # Annotate each point with the disease name
    for i, disease in enumerate(econ_loss_clean['disease']):
        ax.text(econ_loss_clean['mortality_smu'].iloc[i] * 1.05, 
                econ_loss_clean['pct_gdp_loss'].iloc[i] * 1.02,
                disease, 
                fontsize=12, 
                ha='right',
                va='bottom',
                color='darkblue')

    # Fitted line for log scale
    ax.plot(x_range, y_pred, color="crimson", linewidth=2.5, label="Fitted Model")

    # Logarithmic scales for both axes
    ax.set_xscale('log')
    ax.set_yscale('log')

    # Labels and title
    ax.set_xlabel("Mortality (SMU)")
    ax.set_ylabel(r"% GDP Loss")
    ax.set_title("Relationship between Mortality Severity and Economic Losses (Log Scale)", fontweight='bold')

    # Add R^2 values to the plot
    ax.text(0.05, 0.90, rf"$R^2_{{\mathrm{{log\ space}}}} = {r_squared_log:.3f}$", 
            transform=ax.transAxes, verticalalignment='top', color="green")
    ax.text(0.05, 0.85, rf"$R^2_{{\mathrm{{linear\ space}}}} = {r_squared_linear:.3f}$", 
            transform=ax.transAxes, verticalalignment='top', color="blue")

    # Save the log-scale plot
    plt.tight_layout()
    plt.savefig("output/econ_loss_models/default_model_logscale.png", dpi=400)
