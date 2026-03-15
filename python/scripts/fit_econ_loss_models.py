# Estimate relationship between severity and percentage economic losses
from pathlib import Path

import numpy as np
import pandas as pd
import yaml
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score
import statsmodels.api as sm


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
    econ_loss = econ_loss_raw.rename(
        columns={
            'Annual fraction GPD losses': 'annual_share_gdp_loss',
            'Fraction output loss over total horizon': 'total_share_gdp_loss',
            'Intensity (SMU)': 'intensity',
            'Mortality (SMU)': 'severity',
            'Disease': 'disease',
        }
    )
    econ_loss['annual_pct_gdp_loss'] = econ_loss['annual_share_gdp_loss'] * 100
    if 'total_share_gdp_loss' in econ_loss.columns:
        econ_loss['total_pct_gdp_loss'] = econ_loss['total_share_gdp_loss'] * 100
        econ_loss = econ_loss[
            [
                'annual_share_gdp_loss',
                'annual_pct_gdp_loss',
                'total_share_gdp_loss',
                'total_pct_gdp_loss',
                'intensity',
                'severity',
                'disease',
            ]
        ]
    else:
        econ_loss = econ_loss[
            [
                'annual_share_gdp_loss',
                'annual_pct_gdp_loss',
                'intensity',
                'disease',
            ]
        ]
    econ_loss_clean = econ_loss.dropna(axis=0)  # Drop rows with missing values

    econ_loss_clean.to_csv("./output/econ_loss_models/econ_loss_clean.csv", index=False)

    # ------ Fit poisson model --------------------------------

    X = np.log(econ_loss_clean[['intensity']]) # Log transform
    y = econ_loss_clean['annual_share_gdp_loss']
    
    # Add constant for statsmodels
    X_sm = sm.add_constant(X)
    
    # Fit Poisson model with statsmodels
    pm = sm.GLM(y, X_sm, family=sm.families.Poisson())
    pm_results = pm.fit(cov_type='HC0')

    # Get predictions for plotting
    y_pred = pm_results.predict(X_sm)
    model_deviance = pm_results.deviance

    # ------ Plot poisson model -----------------------------------
    
    # Set colors
    col_poisson = 'blue'

    # Plot data 
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.scatter(
        econ_loss_clean['intensity'],
        econ_loss_clean['annual_pct_gdp_loss'],
        color="black",
        s=80,
        alpha=0.7,
        label="Data points",
    )

    # Annotate each point with the disease name
    for i, disease in enumerate(econ_loss_clean['disease']):
        ax.text(econ_loss_clean['intensity'].iloc[i] * 1.22,
                econ_loss_clean['annual_pct_gdp_loss'].iloc[i] * 0.98, 
                disease, 
                fontsize=12,
                ha='left',
                va='top',
                color='black')

    # Labels
    ax.set_xlabel("Intensity (deaths per 10,000 per year)")
    ax.set_ylabel("Annual GDP loss (%)")
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(True, color="0.8", alpha=0.3)
    
    # Log scale and tight layout 
    ax.set_xscale('log')
    plt.tight_layout()

    # Fitted lines for linear scale (extend to 10^4)
    log_xrange = np.linspace(
        np.log(1e-5),
        np.log(1e4),
        1000
    ).reshape(-1, 1)

    # Add constant to prediction range
    log_xrange_sm = sm.add_constant(log_xrange)
    y_pred_poisson = pm_results.predict(log_xrange_sm) * 100 # Scale to percentage scale

    # Plot poisson curve and save
    ax.plot(np.exp(log_xrange), y_pred_poisson, linewidth=2.5, color=col_poisson, label='Poisson')

    # Save figure
    outdir = Path("./output/econ_loss_models").resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    figpath = outdir / "poisson_model.png"
    plt.savefig(figpath, dpi=600)

    poisson_dict = {
        'family': 'poisson',
        'params': {
            'intercept': float(pm_results.params.iloc[0]),
            'coefs': [float(pm_results.params.iloc[1])],
        },
        'meta': {
            'input_variable': 'intensity',
            'input_units': 'SMU (deaths per 10,000 people per year)',
            'output_variable': 'annual_share_gdp_loss',
            'output_units': 'share_of_gdp',
        },
    }

    outpath = outdir / "poisson_model.yaml"
    with open(outpath, "w") as f:
        yaml.dump(poisson_dict, f)

    # Create LaTeX table summarizing Poisson model results
    # Get robust standard errors, z-scores and p-values from statsmodels results
    std_errors = pm_results.bse
    z_scores = pm_results.tvalues
    p_values = pm_results.pvalues
    n_obs = len(econ_loss_clean)
    # Create and save LaTeX table in PTRS style (single row per parameter, SE in parentheses below)
    latex_table = (
        "\\begin{table}[h]\n"
        "\\centering\n"
        "\\caption{Economic loss model (Poisson regression of annual GDP loss share on pandemic intensity."
        "Log intensity is used as the independent variable so as to give estimated coefficient an elasticity interpretation."
        "See Equation~\\ref{eq:econ-loss-power-law} for the regression specification.).}\n"
        "\\label{tab:econ_loss_model}\n"
        "\\begin{tabular}{lc}\n"
        "\\hline \\hline\n"
        "Parameter & Coefficient \\\\\n"
        "\\hline\n"
        f"Intercept & {pm_results.params.iloc[0]:.3f} \\\\\n"
        f" & ({std_errors.iloc[0]:.3f}) \\\\\n"
        f"ln(Severity) & {pm_results.params.iloc[1]:.3f} \\\\\n"
        f" & ({std_errors.iloc[1]:.3f}) \\\\\n"
        "\\hline\n"
        f"Deviance & {model_deviance:.3f} \\\\\n"
        f"Number of observations & {n_obs} \\\\\n"
        "\\hline\n"
        "\\multicolumn{2}{l}{\\footnotesize HC0 robust standard errors reported in parentheses.} \\\\\n"
        "\\end{tabular}\n"
        "\\end{table}\n"
    )
    # Save LaTeX table
    with open(outdir / "poisson_model_summary.tex", "w") as f:
        f.write(latex_table)

    # ------ Fit poisson model: total GDP vs severity (if available) ---------------

    if {'total_share_gdp_loss', 'severity'}.issubset(econ_loss_clean.columns):

        X_sev = np.log(econ_loss_clean[['severity']])
        y_total = econ_loss_clean['total_share_gdp_loss']

        X_sev_sm = sm.add_constant(X_sev)
        pm_sev = sm.GLM(y_total, X_sev_sm, family=sm.families.Poisson())
        pm_sev_results = pm_sev.fit(cov_type='HC0')

        # Prediction grid over severity up to 10^4
        log_sev_range_poiss = np.linspace(
            np.log(1e-5),
            np.log(1e4),
            1000,
        ).reshape(-1, 1)
        log_sev_range_poiss_sm = sm.add_constant(log_sev_range_poiss)
        y_pred_poiss_sev = pm_sev_results.predict(log_sev_range_poiss_sm) * 100

        # Plot poisson model: total GDP vs severity
        fig, ax = plt.subplots(figsize=(10, 8))
        ax.scatter(
            econ_loss_clean['severity'],
            econ_loss_clean['total_pct_gdp_loss'],
            color="black",
            s=80,
            alpha=0.7,
        )

        # One label per point: use if/elif/else so each disease gets exactly one branch
        for i, disease in enumerate(econ_loss_clean['disease']):
            x_pos = econ_loss_clean['severity'].iloc[i]
            y_pos = econ_loss_clean['total_pct_gdp_loss'].iloc[i]
            d = str(disease).strip()
            d_lower = d.lower()
            if d_lower == 'covid-19':
                # Mirrored: text above and left of dot, end of word at dot
                ax.text(
                    x_pos * 0.88,
                    y_pos * 1.06,
                    disease,
                    fontsize=12,
                    ha='right',
                    va='bottom',
                    color='black',
                )
            elif d_lower == 'hong kong flu' or d_lower == '1918 flu':
                # Hong kong flu, 1918 flu: smaller offset from dot
                ax.text(
                    x_pos * 1.08,
                    y_pos - 0.5,
                    disease,
                    fontsize=12,
                    ha='left',
                    va='top',
                    color='black',
                )
            else:
                # Zika, SARS, Ebola: anchor bottom-right of dot, further down
                ax.text(
                    x_pos * 1.15,
                    y_pos - 0.4,
                    disease,
                    fontsize=12,
                    ha='left',
                    va='top',
                    color='black',
                )

        ax.set_xlabel("Severity (deaths per 10,000 people)")
        ax.set_ylabel("Total GDP loss (%)")
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.grid(True, color="0.8", alpha=0.3, axis="both")
        ax.set_xscale('log')

        ax.plot(
            np.exp(log_sev_range_poiss),
            y_pred_poiss_sev,
            linewidth=2.5,
            color=col_poisson,
        )

        # Label the fitted line at 10^3 severity: above the line, multiline, no overlap
        x_label = 1e3
        x_vals = np.exp(log_sev_range_poiss.flatten())
        y_at_1e3 = np.interp(x_label, x_vals, y_pred_poiss_sev)
        y_lim = ax.get_ylim()
        y_offset = (y_lim[1] - y_lim[0]) * 0.12
        ax.text(
            x_label - 5e2,
            y_at_1e3 + y_offset,
            "Fitted\nPoisson\nregression",
            fontsize=14,
            ha="center",
            va="bottom",
            color=col_poisson,
        )
        plt.tight_layout()

        figpath = outdir / "poisson_model_total_severity.png"
        plt.savefig(figpath, dpi=600)

        poisson_sev_dict = {
            'family': 'poisson',
            'params': {
                'intercept': float(pm_sev_results.params.iloc[0]),
                'coefs': [float(pm_sev_results.params.iloc[1])],
            },
            'meta': {
                'input_variable': 'severity',
                'input_units': 'SMU (deaths per 10,000 people, total over pandemic)',
                'output_variable': 'total_share_gdp_loss',
                'output_units': 'share_of_gdp',
            },
        }
        outpath = outdir / "poisson_model_total_severity.yaml"
        with open(outpath, "w") as f:
            yaml.dump(poisson_sev_dict, f)

    # ------ Fit log log regression --------------------------------
    
    X = np.log(econ_loss_clean[['intensity']])
    y = np.log(econ_loss_clean['annual_share_gdp_loss'])

    llreg = LinearRegression()
    llreg.fit(X, y)

    # ------ Plot log log regression -----------------------------------

    # Plot log-log regression
    fig, ax = plt.subplots(figsize=(8, 6))

    # Define color for log-log model
    col_loglog = '#e74c3c'  # A red color to contrast with the green poisson plot

    # Plot data points
    ax.scatter(econ_loss_clean['intensity'], econ_loss_clean['annual_share_gdp_loss'] * 100,
              alpha=0.6, color=col_loglog)

    # Add labels and title
    ax.set_xlabel('Deaths / 10,000 / year')
    ax.set_ylabel('Annual GDP loss (%)')
    ax.set_title('Economic loss vs. pandemic intensity (log-log model)')

    # Remove top and right spines
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    # Log scale and tight layout
    ax.set_xscale('log')
    plt.tight_layout()

    # Fitted line for log-log regression (extend to 10^4)
    log_xrange = np.linspace(
        np.log(1e-5),
        np.log(1e4),
        1000
    ).reshape(-1, 1)
    log_xrange_df = pd.DataFrame(log_xrange, columns=["intensity"])

    y_pred_loglog = np.exp(llreg.predict(log_xrange_df)) * 100  # Scale to percentage

    # Plot log-log curve
    ax.plot(np.exp(log_xrange), y_pred_loglog, linewidth=2.5, color=col_loglog, label='Log-Log')
    
    # Calculate R^2 in both log and linear space
    r2_log = r2_score(y, llreg.predict(X))
    r2_linear = r2_score(econ_loss_clean['annual_share_gdp_loss'], 
                        np.exp(llreg.predict(X)))
    
    # Display both R^2 values
    ax.text(0.80, 0.20, rf"$R^2_{{\mathrm{{log}}}} = {r2_log:.3f}$",
            transform=ax.transAxes, verticalalignment='top', color=col_loglog)
    ax.text(0.80, 0.10, rf"$R^2_{{\mathrm{{linear}}}} = {r2_linear:.3f}$",
            transform=ax.transAxes, verticalalignment='top', color=col_loglog)

    # Save figure
    figpath = outdir / "loglog_model.png"
    plt.savefig(figpath, dpi=600)

    # Save model parameters
    loglog_dict = {
        'family': 'loglogreg',
        'params': {
            'intercept': float(llreg.intercept_),
            'coefs': [float(beta) for beta in llreg.coef_],
        },
        'meta': {
            'input_variable': 'intensity',
            'input_units': 'SMU (deaths per 10,000 people per year)',
            'output_variable': 'annual_share_gdp_loss',
            'output_units': 'share_of_gdp',
        },
    }

    outpath = outdir / "loglog_model.yaml"
    with open(outpath, "w") as f:
        yaml.dump(loglog_dict, f)

    # ------ Fit cloglog fractional regression: annual GDP vs intensity --------------------

    X_frac_annual = np.log(econ_loss_clean[['intensity']])
    X_frac_annual_sm = sm.add_constant(X_frac_annual)
    y_frac_annual = econ_loss_clean['annual_share_gdp_loss']

    cloglog_link = sm.families.links.cloglog()
    frac_annual_model = sm.GLM(
        y_frac_annual,
        X_frac_annual_sm,
        family=sm.families.Binomial(link=cloglog_link),
    )
    frac_annual_results = frac_annual_model.fit(cov_type='HC0')

    # Prediction grid up to 10^4 in intensity
    log_xrange_frac = np.linspace(np.log(1e-5), np.log(1e4), 1000).reshape(-1, 1)
    log_xrange_frac_sm = sm.add_constant(log_xrange_frac)
    y_pred_frac_annual = frac_annual_results.predict(log_xrange_frac_sm) * 100

    # Plot cloglog fractional model for annual GDP loss vs intensity
    fig, ax = plt.subplots(figsize=(10, 8))
    ax.scatter(
        econ_loss_clean['intensity'],
        econ_loss_clean['annual_pct_gdp_loss'],
        color='black',
        s=80,
        alpha=0.7,
        label='Data points',
    )

    for i, disease in enumerate(econ_loss_clean['disease']):
        ax.text(
            econ_loss_clean['intensity'].iloc[i] * 1.22,
            econ_loss_clean['annual_pct_gdp_loss'].iloc[i] * 0.98,
            disease,
            fontsize=12,
            ha='left',
            va='top',
            color='black',
        )

    ax.set_xlabel('Intensity (deaths per 10,000 per year)')
    ax.set_ylabel('Annual GDP loss (%)')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(True, color='0.8', alpha=0.3)
    ax.set_xscale('log')

    ax.plot(
        np.exp(log_xrange_frac),
        y_pred_frac_annual,
        linewidth=2.5,
        color='#2ecc71',
        label='Cloglog fractional',
    )
    ax.legend()
    plt.tight_layout()

    figpath = outdir / 'cloglog_fractional_annual_intensity.png'
    plt.savefig(figpath, dpi=600)

    cloglog_annual_dict = {
        'family': 'binomial_cloglog_fractional',
        'params': {
            'intercept': float(frac_annual_results.params.iloc[0]),
            'coefs': [float(frac_annual_results.params.iloc[1])],
        },
        'meta': {
            'input_variable': 'intensity',
            'input_units': 'SMU (deaths per 10,000 people per year)',
            'output_variable': 'annual_share_gdp_loss',
            'output_units': 'share_of_gdp',
        },
    }
    outpath = outdir / 'cloglog_fractional_annual_intensity.yaml'
    with open(outpath, 'w') as f:
        yaml.dump(cloglog_annual_dict, f)

    # ------ Fit cloglog fractional regression: total GDP vs severity ----------------------

    if {'total_share_gdp_loss', 'severity'}.issubset(econ_loss_clean.columns):
        X_frac_total = np.log(econ_loss_clean[['severity']])
        X_frac_total_sm = sm.add_constant(X_frac_total)
        y_frac_total = econ_loss_clean['total_share_gdp_loss']

        frac_total_model = sm.GLM(
            y_frac_total,
            X_frac_total_sm,
            family=sm.families.Binomial(link=cloglog_link),
        )
        frac_total_results = frac_total_model.fit(cov_type='HC0')

        # Prediction grid over severity up to 10^4
        log_sev_range = np.linspace(
            np.log(1e-5),
            np.log(1e4),
            1000,
        ).reshape(-1, 1)
        log_sev_range_sm = sm.add_constant(log_sev_range)
        y_pred_frac_total = frac_total_results.predict(log_sev_range_sm) * 100

        fig, ax = plt.subplots(figsize=(10, 8))
        ax.scatter(
            econ_loss_clean['severity'],
            econ_loss_clean['total_share_gdp_loss'] * 100,
            color='black',
            s=80,
            alpha=0.7,
            label='Data points',
        )

        for i, disease in enumerate(econ_loss_clean['disease']):
            ax.text(
                econ_loss_clean['severity'].iloc[i] * 1.05,
                econ_loss_clean['total_share_gdp_loss'].iloc[i] * 100 * 0.98,
                disease,
                fontsize=12,
                ha='left',
                va='top',
                color='black',
            )

        ax.set_xlabel('Severity (deaths per 10,000 people)')
        ax.set_ylabel('Total GDP loss (%)')
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.grid(True, color='0.8', alpha=0.3)
        ax.set_xscale('log')

        ax.plot(
            np.exp(log_sev_range),
            y_pred_frac_total,
            linewidth=2.5,
            color='#1abc9c',
            label='Cloglog fractional',
        )
        ax.legend()
        plt.tight_layout()

        figpath = outdir / 'cloglog_fractional_total_severity.png'
        plt.savefig(figpath, dpi=600)

        cloglog_total_dict = {
            'family': 'binomial_cloglog_fractional',
            'params': {
                'intercept': float(frac_total_results.params.iloc[0]),
                'coefs': [float(frac_total_results.params.iloc[1])],
            },
            'meta': {
                'input_variable': 'severity',
                'input_units': 'SMU (deaths per 10,000 people, total over pandemic)',
                'output_variable': 'total_share_gdp_loss',
                'output_units': 'share_of_gdp',
            },
        }
        outpath = outdir / 'cloglog_fractional_total_severity.yaml'
        with open(outpath, 'w') as f:
            yaml.dump(cloglog_total_dict, f)

    # ------ Plot both models together -----------------------------------
    fig, ax = plt.subplots(figsize=(8, 6))

    # Extended x range for predictions
    log_xrange_extended = np.linspace(np.log(1e-5), np.log(1e4), 1000).reshape(-1, 1)
    
    # Generate predictions
    log_xrange_extended_sm = sm.add_constant(log_xrange_extended)
    y_pred_poisson_ext = pm_results.predict(log_xrange_extended_sm) * 100
    log_xrange_extended_df = pd.DataFrame(log_xrange_extended, columns=["intensity"])
    y_pred_loglog_ext = np.exp(llreg.predict(log_xrange_extended_df)) * 100

    # Plot data points
    ax.scatter(econ_loss_clean['intensity'], econ_loss_clean['annual_share_gdp_loss'] * 100,
              alpha=0.6, color='gray', label='Data')

    # Plot both curves
    ax.plot(np.exp(log_xrange_extended), y_pred_poisson_ext, 
            linewidth=2.5, color=col_poisson, label='Poisson')
    ax.plot(np.exp(log_xrange_extended), y_pred_loglog_ext, 
            linewidth=2.5, color=col_loglog, label='Log-Log')

    # Add labels and title
    ax.set_xlabel('Deaths per 10,000 / year')
    ax.set_ylabel('Annual GDP loss (%)')
    ax.set_title('Economic loss models comparison')

    # Remove top and right spines
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    # Log scale and legend
    ax.set_xscale('log')
    ax.legend()
    plt.tight_layout()

    # Save comparison figure
    figpath = outdir / "model_comparison.png"
    plt.savefig(figpath, dpi=600)