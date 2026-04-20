"""
Create a single-panel figure of GPD exceedance functions: all epidemics versus novel viral only.

Both series are plotted on the same axes. X extent is 0.01–200 (deaths per 10,000).
Uncertainty is shown as 95% confidence intervals from the delta method (MLE + asymptotic
variance of the survival function via parameter covariance from samples).
Uses a single figure-level legend. Output is a manuscript-ready PDF by default.
"""

from pathlib import Path

import click
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from pandemic_statistics.pareto import ArrivalGPD
from pandemic_model.plot_style import (
    apply_paper_axis_style,
    apply_paper_rc,
    get_paper_style,
    save_paper_figure,
)


# Series to plot on the same axes (lineage e241210c_upcov = clean + inverted COVID severity; see docs/naming_convention.md)
_SER = "e241210c_upcov__filt__"
SERIES = [
    (
        "All epidemics",
        _SER
        + "all_int_0d01_1900_yearthreshonly__arr__gpd_severity_poisson_sharp_u200_n50000_s42",
    ),
    (
        "Novel viral only",
        _SER + "all_int_0d01_1900__arr__gpd_severity_poisson_sharp_u200_n50000_s42",
    ),
]

# Axes extent (severity: deaths per 10,000)
X_MIN = 0.01
X_MAX = 200
Y_MIN = 1e-4
Y_MAX = 1.0
N_POINTS = 1000
N_SAMPLES_CI = 10_000

# Colors for the two series (line and band): all epidemics (red), preferred sample (blue)
COLORS = ["#d62728", "#1f77b4"]

# 95% confidence interval: z such that P(-z <= Z <= z) = 0.95
Z_95 = 1.96


def _sf_gradient_wrt_theta(
    model: ArrivalGPD,
    x: np.ndarray,
    a_param: float,
    xi: float,
    sigma: float,
    eps: float = 1e-7,
) -> np.ndarray:
    """
    Compute the gradient of the survival function with respect to (a_param, xi, sigma) at each x.

    Uses central finite differences. Returns shape (len(x), 3) with columns [d(sf)/da, d(sf)/d(xi), d(sf)/d(sigma)].
    """
    sf0 = model._sf_core(x, a_param, xi, sigma)
    if model.y_max is not None and np.isfinite(model.y_max):
        sf0 = np.where(x <= model.y_max, sf0, 0.0)

    ha = max(eps * (1 + abs(a_param)), 1e-12)
    hxi = max(eps * (1 + abs(xi)), 1e-12)
    hsig = max(eps * (1 + abs(sigma)), 1e-12)

    sf_a_plus = model._sf_core(x, a_param + ha, xi, sigma)
    sf_a_minus = model._sf_core(x, a_param - ha, xi, sigma)
    if model.y_max is not None and np.isfinite(model.y_max):
        sf_a_plus = np.where(x <= model.y_max, sf_a_plus, 0.0)
        sf_a_minus = np.where(x <= model.y_max, sf_a_minus, 0.0)
    d_sf_da = (sf_a_plus - sf_a_minus) / (2 * ha)

    sf_xi_plus = model._sf_core(x, a_param, xi + hxi, sigma)
    sf_xi_minus = model._sf_core(x, a_param, xi - hxi, sigma)
    if model.y_max is not None and np.isfinite(model.y_max):
        sf_xi_plus = np.where(x <= model.y_max, sf_xi_plus, 0.0)
        sf_xi_minus = np.where(x <= model.y_max, sf_xi_minus, 0.0)
    d_sf_dxi = (sf_xi_plus - sf_xi_minus) / (2 * hxi)

    sf_sig_plus = model._sf_core(x, a_param, xi, sigma + hsig)
    sf_sig_minus = model._sf_core(x, a_param, xi, sigma - hsig)
    if model.y_max is not None and np.isfinite(model.y_max):
        sf_sig_plus = np.where(x <= model.y_max, sf_sig_plus, 0.0)
        sf_sig_minus = np.where(x <= model.y_max, sf_sig_minus, 0.0)
    d_sf_dsigma = (sf_sig_plus - sf_sig_minus) / (2 * hsig)

    return np.column_stack([d_sf_da, d_sf_dxi, d_sf_dsigma])


def _delta_method_ci_95(
    model: ArrivalGPD,
    x: np.ndarray,
    cov_theta: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Return (lower, upper) 95% delta-method confidence limits for the survival function at x.

    cov_theta is the 3x3 covariance matrix of (a_param, xi, sigma).
    """
    grad = _sf_gradient_wrt_theta(model, x, model.arrival_param, model.xi, model.sigma)
    # Variance at each x: grad[i] @ cov_theta @ grad[i]
    var_sf = np.einsum("ij,jk,ik->i", grad, cov_theta, grad)
    se_sf = np.sqrt(np.maximum(var_sf, 0.0))
    sf_mle = model.sf_mle(x)
    if model.y_max is not None and np.isfinite(model.y_max):
        sf_mle = np.where(x <= model.y_max, sf_mle, 0.0)
    lower = np.clip(sf_mle - Z_95 * se_sf, 0.0, 1.0)
    upper = np.clip(sf_mle + Z_95 * se_sf, 0.0, 1.0)
    return lower, upper


def _find_model_dir(root: Path, folder_stem: str) -> Path:
    """Return path to directory containing hyperparams.yaml for this model."""
    for parent in (root,):
        if not parent.exists():
            continue
        candidate = parent / folder_stem
        if (candidate / "hyperparams.yaml").exists():
            return candidate
    raise FileNotFoundError(f"Model directory not found: {folder_stem} under {root}")


@click.command()
@click.option(
    "--root",
    type=click.Path(exists=True, file_okay=False, path_type=Path),
    default=Path("data/clean/arrival_distributions"),
    help="Root directory containing GPD model folder stems (lineage distinguishes sources).",
)
@click.option(
    "--out",
    type=click.Path(path_type=Path),
    default=Path("output/exceedance_comparison_limited.pdf"),
    help="Output path for the figure.",
)
@click.option("--dpi", type=int, default=600, help="Resolution for the saved figure.")
def plot_exceedance_two_panel(root: Path, out: Path, dpi: int) -> None:
    """Plot exceedance functions for all epidemics and a preferred sample of novel viral epidemics on one axes (x extent 0.01–200)."""
    x = np.logspace(np.log10(X_MIN), np.log10(X_MAX), N_POINTS)
    style = get_paper_style("double_col_standard")
    apply_paper_rc(style)
    fig, ax = plt.subplots(figsize=(style.width_in, style.height_in))

    for (title, folder_stem), color in zip(SERIES, COLORS):
        model_dir = _find_model_dir(root, folder_stem)
        model = ArrivalGPD.load(model_dir)

        mle_sf = model.sf_mle(x)
        if model.y_max is not None and np.isfinite(model.y_max):
            mle_sf = np.where(x <= model.y_max, mle_sf, 0.0)

        samples_path = model_dir / "param_samples.csv"
        if samples_path.exists():
            param_samples = pd.read_csv(samples_path)
            theta = param_samples.to_numpy()
            if theta.shape[0] > N_SAMPLES_CI:
                step = max(theta.shape[0] // N_SAMPLES_CI, 1)
                theta = theta[::step]
            cov_theta = np.cov(theta, rowvar=False)
            lower, upper = _delta_method_ci_95(model, x, cov_theta)
            ax.fill_between(
                x,
                lower,
                upper,
                color=color,
                alpha=style.ci_alpha,
            )

        ax.plot(
            x,
            mle_sf,
            "-",
            linewidth=style.primary_lw,
            color=color,
            alpha=0.8,
            label=title,
        )

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(X_MIN, X_MAX)
    ax.set_ylim(Y_MIN, Y_MAX)
    apply_paper_axis_style(ax, style)
    ax.set_xlabel("Severity (deaths per 10,000)", fontsize=style.axis_label_size, fontfamily=style.font_family)
    ax.set_ylabel("Annual exceedance probability", fontsize=style.axis_label_size, fontfamily=style.font_family)

    # Remove legend and instead label curves directly near the y-axis.
    x_label_pos = 0.03
    idx_label = int(np.argmin(np.abs(x - x_label_pos)))

    for (title, folder_stem), color in zip(SERIES, COLORS):
        model_dir = _find_model_dir(root, folder_stem)
        model = ArrivalGPD.load(model_dir)
        mle_sf = model.sf_mle(x)
        if model.y_max is not None and np.isfinite(model.y_max):
            mle_sf = np.where(x <= model.y_max, mle_sf, 0.0)

        y_on_curve = mle_sf[idx_label]

        if title == "All epidemics":
            label_text = "All epidemics"
            y_label = y_on_curve * 1.3
            va = "bottom"
        else:
            label_text = "Preferred sample\n(Novel viral only)"
            y_label = y_on_curve / 1.3
            va = "top"

        ax.text(
            x_label_pos,
            y_label,
            label_text,
            color="black",
            fontsize=style.legend_size,
            ha="left",
            va=va,
            fontfamily=style.font_family,
        )

    plt.tight_layout()
    save_paper_figure(fig, out, dpi=dpi)
    plt.close(fig)
    click.echo(f"Saved {out}")


if __name__ == "__main__":
    plot_exceedance_two_panel()
