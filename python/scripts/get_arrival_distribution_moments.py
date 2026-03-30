"""Compute arrival-rate moments at selected severity thresholds.

This script loads a fitted arrival distribution (ArrivalGPD folder output) and
computes summary moments of annual exceedance probability for a set of severity
thresholds using parameter-sample uncertainty.

Run from repository root:
    cd python && poetry run python scripts/get_arrival_distribution_moments.py \
        --distribution output/arrival_distributions/<distribution_folder>

Unless ``--n-samples`` is set, ``n`` is taken from the folder name segment
``..._n_<N>_seed_<seed>`` (see ``fit_arrival_distributions.py``).
"""

from __future__ import annotations

import re
from pathlib import Path

import click
import numpy as np
import pandas as pd

from pandemic_statistics.pareto import ArrivalGPD

DEFAULT_SEVERITIES = (9.17, 44.4, 171.0)
DEFAULT_SEED = 42


def build_moment_table(
    model: ArrivalGPD,
    severities: tuple[float, ...],
    n_samples: int,
    seed: int,
) -> pd.DataFrame:
    """Build a table of moments for annual exceedance probabilities.

    Parameters
    ----------
    model
        Loaded arrival model.
    severities
        Severity thresholds at which to evaluate exceedance probabilities.
    n_samples
        Number of parameter samples used for uncertainty propagation.
    seed
        Random seed for sampling parameters.

    Returns
    -------
    pd.DataFrame
        One row per severity with mean, standard deviation, variance, and
        selected quantiles of annual exceedance probability.
    """
    x = np.asarray(severities, dtype=float)
    sample_probs = model._sf_core(x, n_samples=n_samples, seed=seed)

    summary = pd.DataFrame(
        {
            "severity": x,
            "mean": sample_probs.mean(axis=0),
            "std": sample_probs.std(axis=0, ddof=1),
            "variance": sample_probs.var(axis=0, ddof=1),
            "q05": np.quantile(sample_probs, 0.05, axis=0),
            "median": np.quantile(sample_probs, 0.50, axis=0),
            "q95": np.quantile(sample_probs, 0.95, axis=0),
            "mle": model.sf_mle(x),
        }
    )
    return summary


@click.command()
@click.option(
    "--distribution",
    type=click.Path(path_type=Path, exists=True, file_okay=False, dir_okay=True),
    default="output/arrival_distributions/modified/gpd_all_excl_unid_filt_intensity_fit_severity_0d01_1900_poisson_sharp_upper_200_n_1000000_seed_42",
    required=True,
    help=(
        "Path to the fitted distribution folder containing hyperparams.yaml "
        "and central_est.yaml."
    ),
)
@click.option(
    "--severity",
    type=float,
    multiple=True,
    default=DEFAULT_SEVERITIES,
    show_default=True,
    help="Severity threshold at which to evaluate arrival moments. Repeatable.",
)
@click.option(
    "--n-samples",
    type=int,
    default=None,
    help=(
        "Override number of parameter draws for uncertainty propagation. "
        "Default: parse N from folder name ..._n_<N>_seed_<seed>."
    ),
)
@click.option(
    "--seed",
    type=int,
    default=DEFAULT_SEED,
    show_default=True,
    help="Random seed for parameter sampling.",
)
def main(
    distribution: Path,
    severity: tuple[float, ...],
    n_samples: int | None,
    seed: int,
) -> None:
    """Load a fitted arrival model and print moment summaries."""
    distribution_path = distribution.resolve()

    model = ArrivalGPD.load(distribution_path)

    if n_samples is not None:
        effective_n = n_samples
    else:
        m = re.search(r"_n_(\d+)_seed_", distribution_path.name)
        if not m:
            raise ValueError(
                "Pass --n-samples or use a distribution folder whose name includes "
                f"_n_<N>_seed_<seed> (got {distribution_path.name!r})."
            )
        effective_n = int(m.group(1))

    click.echo(f"Loaded distribution: {distribution_path}")
    click.echo(f"Parameter draws (n_samples): {effective_n}")
    click.echo(
        "Hyperparameters: "
        f"arrival_type={model.arrival_type}, "
        f"trunc_method={model.trunc_method}, "
        f"y_min={model.y_min}, y_max={model.y_max}"
    )
    click.echo()

    result = build_moment_table(
        model=model,
        severities=severity,
        n_samples=effective_n,
        seed=seed,
    )
    with pd.option_context("display.float_format", lambda v: f"{v:0.6g}"):
        click.echo(result.to_string(index=False))


if __name__ == "__main__":
    main()
