"""
Create a panel figure of GPD exceedance functions for selected model variants.

The top-left panel is the base case (all, excl_unid, threshold 0.01, year 1900,
upper 200). Other panels show one variant each with short titles. Uses common
axes and a single figure-level legend. Output is a manuscript-ready PDF by default.
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
from pandemic_model.utils import get_measure_units


# Panels: (subplot title, folder name stem). Lineage e241210c_upcov (clean_inputs uses *_clean_upcov); n=50000, seed=42.
_L = "e241210c_upcov__filt__"
PANELS = [
    ("Base case", _L + "all_int_0d01_1900__arr__gpd_severity_poisson_sharp_u200_n50000_s42"),
    (
        "Airborne only",
        _L + "airborne_int_0d01_1900__arr__gpd_severity_poisson_sharp_u200_n50000_s42",
    ),
    (
        "Lower severity threshold = 1 SU",
        _L + "all_int_1d0_1900__arr__gpd_severity_poisson_sharp_u200_n50000_s42",
    ),
    (
        "Outbreaks after 1950 only",
        _L + "all_int_0d01_1950__arr__gpd_severity_poisson_sharp_u200_n50000_s42",
    ),
    (
        "Max severity 1,000",
        _L + "all_int_0d01_1900__arr__gpd_severity_poisson_sharp_u1000_n50000_s42",
    ),
    (
        "Max severity 10,000",
        _L + "all_int_0d01_1900__arr__gpd_severity_poisson_sharp_u10000_n50000_s42",
    ),
    (
        "Include unidentified pathogens",
        _L + "all_int_0d01_1900_incl_unid__arr__gpd_severity_poisson_sharp_u200_n50000_s42",
    ),
    (
        "Year-threshold-only, incl. unidentified",
        _L + "all_int_0d01_1900_yearthreshonly__arr__gpd_severity_poisson_sharp_u200_n50000_s42",
    ),
]

# Common axes for all panels (severity: deaths per 10,000)
X_MIN = 0.01
X_MAX = 12_000
Y_MIN = 1e-4
Y_MAX = 1.0
N_POINTS = 1000
# Number of parameter samples for 90% CI (match saved samples or subset for speed)
N_SAMPLES_CI = 10_000


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
    default=Path("output/graphs/exceedance_panel.pdf"),
    help="Output path for the panel figure.",
)
@click.option("--dpi", type=int, default=600, help="Resolution for the saved figure.")
def plot_exceedance_panel(root: Path, out: Path, dpi: int) -> None:
    """Plot a 2x4 panel of exceedance functions for selected GPD variants."""
    x = np.logspace(np.log10(X_MIN), np.log10(X_MAX), N_POINTS)
    style = get_paper_style("grid_2xn", n_cols=4)
    apply_paper_rc(style)

    fig, axes = plt.subplots(2, 4, figsize=(style.width_in, style.height_in), sharex=True, sharey=True)
    axes = axes.flatten()

    # So we can add one legend for the whole figure, plot the first curve with a label
    # and use the same style for all; then add legend once.
    legend_handles = None
    legend_labels = None

    for ax, (title, folder_stem) in zip(axes, PANELS):
        model_dir = _find_model_dir(root, folder_stem)
        model = ArrivalGPD.load(model_dir)

        # MLE survival function
        mle_sf = model.sf_mle(x)
        if model.y_max is not None and np.isfinite(model.y_max):
            mle_sf = np.where(x <= model.y_max, mle_sf, 0.0)

        # Percentile band from saved parameter samples, if available
        band = None
        samples_path = model_dir / "param_samples.csv"
        if samples_path.exists():
            param_samples = pd.read_csv(samples_path)
            theta = param_samples.to_numpy()
            if theta.shape[0] > N_SAMPLES_CI:
                step = max(theta.shape[0] // N_SAMPLES_CI, 1)
                theta = theta[::step]
            a_param, xi, sigma = np.hsplit(theta, 3)
            survivals = model._sf_core(x, a_param, xi, sigma)
            if model.y_max is not None and np.isfinite(model.y_max):
                survivals[:, x > model.y_max] = 0.0
            percentiles = np.percentile(survivals, [10, 50, 90], axis=0)
            band = ax.fill_between(
                x,
                percentiles[0],
                percentiles[2],
                color="blue",
                alpha=style.ci_alpha_light,
                label="10/90% percentile band",
            )

        # Shade 90% CI then MLE line (same style as single-panel figure)
        (line,) = ax.plot(
            x,
            mle_sf,
            "--",
            linewidth=style.primary_lw,
            color="blue",
            alpha=0.5,
            label="MLE",
        )
        if legend_handles is None:
            legend_handles = [line]
            legend_labels = ["MLE"]
            if band is not None:
                legend_handles.append(band)
                legend_labels.append("10/90 percentile band")

        ax.set_xscale("log")
        ax.set_yscale("log")
        ax.set_xlim(X_MIN, X_MAX)
        ax.set_ylim(Y_MIN, Y_MAX)
        apply_paper_axis_style(ax, style)
        ax.set_title(title, fontsize=style.title_size, fontname=style.font_family)

    # Shared axis labels (sentence case, similar font size to single-panel).
    # Place them close to the axes; put the legend just below the x-axis label.
    fig.supxlabel(
        get_measure_units("severity").capitalize(),
        fontsize=style.suptitle_size,
        fontname=style.font_family,
        y=0.08,
    )
    fig.supylabel("Annual exceedance probability", fontsize=style.suptitle_size, fontname=style.font_family)

    # Tight layout with a bit more bottom margin reserved for labels and legend.
    plt.tight_layout(rect=(0.02, 0.06, 0.98, 0.96))

    fig.legend(
        legend_handles,
        legend_labels,
        loc="lower center",
        ncol=1 if len(legend_handles) == 1 else 2,
        bbox_to_anchor=(0.5, 0.01),
        frameon=True,
        fontsize=style.legend_size,
    )
    for text in fig.legends[0].get_texts():
        text.set_fontfamily(style.font_family)

    save_paper_figure(fig, out, dpi=dpi)
    plt.close(fig)
    click.echo(f"Saved {out}")


if __name__ == "__main__":
    plot_exceedance_panel()
