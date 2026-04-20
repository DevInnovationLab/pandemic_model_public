"""Shared paper figure style helpers for plotting scripts.

Typography uses fixed point sizes (``BASE_FONT_PT``) with no width-based scaling.
Use :func:`adjust_font_sizes` to shift all font sizes together (e.g. +1 pt on busy
ggplot-style figures is handled in R via ``theme_paper(font_delta = 1)`` in
``plot_ptrs.R`` and ``plot_arrival_shares.R``).
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

import matplotlib.pyplot as plt

FIGURE_SIZE_PRESETS = {
    "single_col": (3.35, 2.40),
    "double_col_standard": (6.90, 4.80),
    "double_col_wide": (6.90, 4.20),
    "tall_panel": (3.35, 3.40),
    "double_col_tall": (6.90, 7),
    "grid_2x4": (6.90, 4.80),
}

BASE_FONT_PT = {
    "tick": 9,
    "axis_label": 10,
    "legend": 10,
    "title": 12,
    "suptitle": 11,
}

STROKE = {
    "primary": 1.6,
    "secondary": 1.2,
    "reference": 0.6,
    "ci_alpha": 0.20,
    "ci_alpha_light": 0.17,
}


@dataclass(frozen=True)
class PaperFigureStyle:
    """Container for paper typography and stroke settings."""

    width_in: float
    height_in: float
    font_family: str
    tick_size: float
    axis_label_size: float
    legend_size: float
    title_size: float
    suptitle_size: float
    primary_lw: float
    secondary_lw: float
    reference_lw: float
    ci_alpha: float
    ci_alpha_light: float


def get_figure_size(preset: str, *, n_cols: int = 4) -> tuple[float, float]:
    """Return (width, height) in inches for a named paper-size preset."""
    if preset == "grid_2xn":
        width_per_col = FIGURE_SIZE_PRESETS["double_col_standard"][0] / 4.0
        width = max(FIGURE_SIZE_PRESETS["single_col"][0], n_cols * width_per_col)
        return width, 2 * FIGURE_SIZE_PRESETS["single_col"][1]
    if preset in FIGURE_SIZE_PRESETS:
        return FIGURE_SIZE_PRESETS[preset]
    raise ValueError(f"Unknown figure preset: {preset}")


def get_paper_style(preset: str, *, font_family: str = "Arial", n_cols: int = 4) -> PaperFigureStyle:
    """Build a style object for a given preset using fixed base font sizes."""
    width_in, height_in = get_figure_size(preset, n_cols=n_cols)
    return PaperFigureStyle(
        width_in=width_in,
        height_in=height_in,
        font_family=font_family,
        tick_size=float(BASE_FONT_PT["tick"]),
        axis_label_size=float(BASE_FONT_PT["axis_label"]),
        legend_size=float(BASE_FONT_PT["legend"]),
        title_size=float(BASE_FONT_PT["title"]),
        suptitle_size=float(BASE_FONT_PT["suptitle"]),
        primary_lw=STROKE["primary"],
        secondary_lw=STROKE["secondary"],
        reference_lw=STROKE["reference"],
        ci_alpha=STROKE["ci_alpha"],
        ci_alpha_light=STROKE["ci_alpha_light"],
    )


def adjust_font_sizes(style: PaperFigureStyle, delta: float) -> PaperFigureStyle:
    """Return a copy of ``style`` with all font sizes shifted by ``delta`` (points)."""
    return replace(
        style,
        tick_size=style.tick_size + delta,
        axis_label_size=style.axis_label_size + delta,
        legend_size=style.legend_size + delta,
        title_size=style.title_size + delta,
        suptitle_size=style.suptitle_size + delta,
    )


def apply_paper_axis_style(ax: Any, style: PaperFigureStyle) -> None:
    """Apply standardized paper styling to a Matplotlib axes."""
    ax.grid(True, alpha=0.3, linewidth=style.reference_lw)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.tick_params(axis="both", which="both", labelsize=style.tick_size)
    for label in ax.get_xticklabels() + ax.get_yticklabels():
        label.set_fontfamily(style.font_family)


def apply_paper_rc(style: PaperFigureStyle) -> None:
    """Set rcParams so figures default to the shared paper style."""
    plt.rcParams.update(
        {
            "font.family": style.font_family,
            "axes.titlesize": style.title_size,
            "axes.labelsize": style.axis_label_size,
            "xtick.labelsize": style.tick_size,
            "ytick.labelsize": style.tick_size,
            "legend.fontsize": style.legend_size,
            "axes.linewidth": style.reference_lw,
            "grid.linewidth": style.reference_lw,
        }
    )


def save_paper_figure(
    fig: Any,
    out: Path,
    *,
    dpi: int = 600,
    facecolor: str = "white",
) -> None:
    """Save figure with manuscript-friendly defaults (tight box, small padding)."""
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=dpi, bbox_inches="tight", pad_inches=0.02, facecolor=facecolor)
