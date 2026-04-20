"""
fit_econ_loss_model.py — Fit and visualize Poisson regression of pandemic severity against total GDP loss.

Loads curated pandemic economic loss data, fits a Poisson GLM of total GDP loss share versus log(severity),
exports robust regression results as a LaTeX table, and produces a labeled diagnostic plot.

Inputs:
    data/raw/Economic damages source review.xlsx (sheet "Updated numbers")
Outputs:
    data/clean/econ_loss_model_sev_poisson.csv
    data/clean/econ_loss_model_sev_poisson.yaml
    output/econ_loss_model_sev_poisson.pdf
    output/econ_loss_model_sev_poisson.tex
"""

from pathlib import Path

import numpy as np
import pandas as pd
import yaml
import matplotlib.pyplot as plt
import statsmodels.api as sm
from pandemic_model.plot_style import (
    apply_paper_axis_style,
    apply_paper_rc,
    get_paper_style,
    save_paper_figure,
)

STEM = "econ_loss_model_sev_poisson"
DATA_CLEAN_DIR = Path("data/clean")
OUTPUT_DIR = Path("output")

if __name__ == "__main__":
    DATA_CLEAN_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    path_curated = DATA_CLEAN_DIR / f"{STEM}.csv"
    path_model_yaml = DATA_CLEAN_DIR / f"{STEM}.yaml"
    path_fig = OUTPUT_DIR / f"{STEM}.pdf"
    path_tex = OUTPUT_DIR / f"{STEM}.tex"

    # --- Load and clean data --------------------------------------------------
    econ_loss_raw = pd.read_excel(
        "./data/raw/Economic damages source review.xlsx",
        sheet_name="Updated numbers"
    ).rename(columns={
        'Annual fraction GPD losses': 'annual_share_gdp_loss',
        'Fraction output loss over total horizon': 'total_share_gdp_loss',
        'Intensity (SMU)': 'intensity',
        'Mortality (SMU)': 'severity',
        'Disease': 'disease',
    })

    econ_loss_raw['total_pct_gdp_loss'] = econ_loss_raw['total_share_gdp_loss'] * 100
    econ_loss = econ_loss_raw[[
        'total_share_gdp_loss',
        'total_pct_gdp_loss',
        'severity', 'disease'
    ]]

    econ_loss_clean = econ_loss.dropna(axis=0)
    econ_loss_clean.to_csv(path_curated, index=False)

    # --- Fit Poisson regression (total GDP loss ~ log severity) ----------------
    col_poisson = "blue"
    X_sev = np.log(econ_loss_clean[['severity']])
    y_total = econ_loss_clean['total_share_gdp_loss']
    X_sev_sm = sm.add_constant(X_sev)

    pm_sev = sm.GLM(y_total, X_sev_sm, family=sm.families.Poisson())
    pm_sev_results = pm_sev.fit(cov_type='HC0')
    n_obs = int(pm_sev_results.nobs)

    # Collect results for YAML and LaTeX output
    params = pm_sev_results.params
    std_errors = pm_sev_results.bse
    deviance = pm_sev_results.deviance

    # --- Write LaTeX summary table (PTRS style) -------------------------------
    latex_str = (
        "\\begin{table}[h]\n"
        "\\centering\n"
        "\\caption{Poisson regression of total pandemic GDP loss fraction on log severity. "
        "See Eq.~\\ref{eq:econ-loss-power-law}. All standard errors HC0 robust.}\n"
        f"\\label{{tab:{STEM}}}\n"
        "\\begin{tabular}{lc}\n"
        "\\hline \\hline\n"
        "Parameter & Coefficient \\\\\n"
        "\\hline\n"
        f"$\\log$(Severity) & {params.iloc[1]:.3f} \\\\\n"
        f"          & ({std_errors.iloc[1]:.3f}) \\\\\n"
        f"Intercept & {params.iloc[0]:.3f} \\\\\n"
        f"          & ({std_errors.iloc[0]:.3f}) \\\\\n"
        "\\hline\n"
        f"Deviance & {deviance:.3f} \\\\\n"
        f"N & {n_obs} \\\\\n"
        "\\hline\n"
        "\\multicolumn{2}{l}{\\footnotesize HC0 robust standard errors in parentheses.} \\\\\n"
        "\\end{tabular}\n"
        "\\end{table}\n"
    )
    with open(path_tex, "w", encoding="utf-8") as f:
        f.write(latex_str)

    # --- Plot Poisson fit and annotate ----------------------------------------
    log_sev_range = np.linspace(np.log(1e-5), np.log(1e4), 1000).reshape(-1, 1)
    y_pred = pm_sev_results.predict(sm.add_constant(log_sev_range)) * 100

    style = get_paper_style("double_col_standard")
    apply_paper_rc(style)

    fig, ax = plt.subplots(figsize=(style.width_in, style.height_in))
    ax.scatter(
        econ_loss_clean['severity'],
        econ_loss_clean['total_pct_gdp_loss'],
        color="black",
        s=60,
        alpha=0.7,
    )

    # Annotate each disease (layout chosen for readability of six main diseases in set)
    for i, disease in enumerate(econ_loss_clean['disease']):
        x = econ_loss_clean['severity'].iloc[i]
        y = econ_loss_clean['total_pct_gdp_loss'].iloc[i]
        d = str(disease).strip()
        if d.lower() == 'covid-19':
            ax.text(x * 0.88, y * 1.06, d, fontsize=style.legend_size, ha='right', va='bottom', color='black')
        elif d.lower() in ('hong kong flu', '1918 flu'):
            ax.text(x * 1.08, y - 0.5, d, fontsize=style.legend_size, ha='left', va='top', color='black')
        else:
            ax.text(x * 1.15, y - 0.4, d, fontsize=style.legend_size, ha='left', va='top', color='black')

    ax.set_xlabel("Severity (deaths per 10,000 people)", fontsize=style.axis_label_size)
    ax.set_ylabel("Total GDP loss (%)", fontsize=style.axis_label_size)
    apply_paper_axis_style(ax, style)
    ax.set_xscale('log')

    ax.plot(
        np.exp(log_sev_range).flatten(),
        y_pred,
        linewidth=style.primary_lw,
        color=col_poisson,
    )

    # Label fitted line just above y at 10^3 severity
    x_label = 1e3
    x_vals = np.exp(log_sev_range).flatten()
    y_at_1e3 = np.interp(x_label, x_vals, y_pred)
    y_offset = (ax.get_ylim()[1] - ax.get_ylim()[0]) * 0.12
    ax.text(
        x_label - 5e2,
        y_at_1e3 + y_offset,
        "Fitted\nPoisson\nregression",
        fontfamily=style.font_family,
        fontsize=style.legend_size,
        ha="center",
        va="bottom",
        color=col_poisson,
    )
    plt.tight_layout()
    save_paper_figure(fig, path_fig, dpi=600)
    plt.close(fig)

    # --- Export model params as YAML -------------------------------------------
    poisson_sev_dict = {
        'family': 'poisson',
        'params': {
            'intercept': float(params.iloc[0]),
            'coefs': [float(params.iloc[1])],
        },
        'meta': {
            'input_variable': 'severity',
            'input_units': 'SMU (deaths per 10,000 people, total over pandemic)',
            'output_variable': 'total_share_gdp_loss',
            'output_units': 'share_of_gdp',
        },
    }
    with open(path_model_yaml, "w", encoding="utf-8") as f:
        yaml.dump(poisson_sev_dict, f)