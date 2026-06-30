"""Compute arrival-rate moments at selected severity thresholds.

Loads a fitted arrival distribution (ArrivalGPD folder output) and summarizes
annual exceedance probabilities per parameter-sample row (one row per simulation
when param_samples.csv matches num_simulations). Also reports simulation-level
"quiet" fractions: no response-threshold exceedance in any active year, using the
same i.i.d. year approximation as the MATLAB horizon (optional first year forced
to zero).
"""

from __future__ import annotations

from pathlib import Path

import click
import numpy as np
import pandas as pd
import yaml

from pandemic_statistics.pareto import ArrivalGPD

# Half COVID severity threshold (half_covid_severity.yaml)
DEFAULT_RESPONSE_THRESHOLD = 6.139
DEFAULT_SEVERITIES = (
    DEFAULT_RESPONSE_THRESHOLD,
    12.3,
    44.4,
    171.0,
)


def annual_exceedance_probs(
    model: ArrivalGPD,
    severities: np.ndarray,
    param_samples: pd.DataFrame,
) -> np.ndarray:
    """Annual P(severity > x) for each parameter row and severity column.

    Args:
        model: Loaded arrival model.
        severities: Severity thresholds, shape (n_severities,).
        param_samples: Parameter samples with columns used by ArrivalGPD.

    Returns:
        Array of shape (n_samples, n_severities).
    """
    samples = param_samples.to_numpy(dtype=float)
    return model._sf_core(
        severities,
        samples[:, [0]],
        samples[:, [1]],
        samples[:, [2]],
    )


def summarize_distribution(values: np.ndarray, severities: np.ndarray, mle: np.ndarray) -> pd.DataFrame:
    """Summarize a per-sample distribution across parameter rows.

    Args:
        values: Array of shape (n_samples, n_severities).
        severities: Severity thresholds, shape (n_severities,).
        mle: MLE point estimates per severity, shape (n_severities,).

    Returns:
        One row per severity with moment columns.
    """
    return pd.DataFrame(
        {
            "severity": severities,
            "mean": values.mean(axis=0),
            "std": values.std(axis=0, ddof=1),
            "variance": values.var(axis=0, ddof=1),
            "q05": np.quantile(values, 0.05, axis=0),
            "median": np.quantile(values, 0.50, axis=0),
            "q95": np.quantile(values, 0.95, axis=0),
            "mle": mle,
        }
    )


def build_annual_moment_table(
    model: ArrivalGPD,
    severities: tuple[float, ...],
    param_samples: pd.DataFrame,
) -> pd.DataFrame:
    """Build a table of moments for annual exceedance probabilities.

    Args:
        model: Loaded arrival model.
        severities: Severity thresholds at which to evaluate exceedance.
        param_samples: One row per simulation parameter draw.

    Returns:
        One row per severity with distribution summaries of annual exceedance.
    """
    x = np.asarray(severities, dtype=float)
    sample_probs = annual_exceedance_probs(model, x, param_samples)
    return summarize_distribution(sample_probs, x, model.sf_mle(x))


def build_horizon_quiet_table(
    model: ArrivalGPD,
    severities: tuple[float, ...],
    param_samples: pd.DataFrame,
    active_years: int,
) -> pd.DataFrame:
    """Build moments for simulation-level quiet probability (no exceedance in horizon).

    For each parameter row i with annual exceedance p_i, uses
    quiet_prob_i = (1 - p_i) ** active_years (i.i.d. years, no overlap adjustment).

    Args:
        model: Loaded arrival model.
        severities: Severity thresholds (response threshold at minimum severity).
        param_samples: One row per simulation parameter draw.
        active_years: Number of years with stochastic severity draws.

    Returns:
        One row per severity with distribution summaries of quiet_prob_i.
    """
    x = np.asarray(severities, dtype=float)
    annual_p = annual_exceedance_probs(model, x, param_samples)
    quiet_probs = (1.0 - annual_p) ** active_years
    mle_annual = model.sf_mle(x)
    mle_quiet = (1.0 - mle_annual) ** active_years
    return summarize_distribution(quiet_probs, x, mle_quiet)


def load_response_threshold(path: Path | None) -> float | None:
    """Load response_threshold from a YAML file if provided.

    Args:
        path: Path to response threshold YAML.

    Returns:
        Threshold value, or None if path is None.
    """
    if path is None:
        return None
    with path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return float(data["response_threshold"])


@click.command()
@click.option(
    "--distribution",
    type=click.Path(path_type=Path, exists=True, file_okay=False, dir_okay=True),
    default=(
        "data/clean/arrival_distributions/e241210c_upcov__filt__all_int_0d01_1900__arr__"
        "gpd_severity_poisson_sharp_u200_n50000_s42"
    ),
    help="Path to the fitted distribution folder containing hyperparams.yaml.",
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
    "--response-threshold-yaml",
    type=click.Path(path_type=Path, exists=True, dir_okay=False),
    default=None,
    help="Optional YAML with response_threshold; prepended to --severity list if set.",
)
@click.option(
    "--sim-periods",
    type=int,
    default=200,
    show_default=True,
    help="Simulation horizon in years (matches run_config sim_periods).",
)
@click.option(
    "--exclude-first-year/--include-first-year",
    default=True,
    show_default=True,
    help="Match MATLAB: year 1 forced to zero severity in get_base_simulation_table.",
)
def main(
    distribution: Path,
    severity: tuple[float, ...],
    response_threshold_yaml: Path | None,
    sim_periods: int,
    exclude_first_year: bool,
) -> None:
    """Load a fitted arrival model and print annual and horizon quiet summaries."""
    distribution_path = distribution.resolve()

    model, param_samples = ArrivalGPD.load(distribution_path, include_sample=True)
    if param_samples is None:
        raise click.ClickException(
            f"No param_samples.csv found under {distribution_path}"
        )

    thresh_from_yaml = load_response_threshold(response_threshold_yaml)
    severity_list = list(severity)
    if thresh_from_yaml is not None and thresh_from_yaml not in severity_list:
        severity_list = [thresh_from_yaml, *severity_list]
    severities = tuple(severity_list)

    active_years = sim_periods - (1 if exclude_first_year else 0)
    if active_years < 1:
        raise click.ClickException("active_years must be at least 1")

    click.echo(f"Loaded distribution: {distribution_path}")
    click.echo(f"Parameter samples: {param_samples.shape[0]} rows (one per simulation when aligned)")
    click.echo(
        "Hyperparameters: "
        f"arrival_type={model.arrival_type}, "
        f"trunc_method={model.trunc_method}, "
        f"y_min={model.y_min}, y_max={model.y_max}"
    )
    click.echo(
        f"Horizon: sim_periods={sim_periods}, "
        f"active_years={active_years} "
        f"(exclude_first_year={exclude_first_year})"
    )
    click.echo(
        "Quiet sim: i.i.d. (1 - p_i)^active_years per param row; "
        "no overlap or false-positive adjustment."
    )
    click.echo()

    annual_table = build_annual_moment_table(model, severities, param_samples)
    quiet_table = build_horizon_quiet_table(
        model, severities, param_samples, active_years
    )

    float_fmt = lambda v: f"{v:0.6g}"
    with pd.option_context("display.float_format", float_fmt):
        click.echo("Annual exceedance P(severity > threshold) per year (per param sample):")
        click.echo(annual_table.to_string(index=False))
        click.echo()
        click.echo(
            f"Simulation quiet P(no exceedance in {active_years} active years) "
            f"per param sample:"
        )
        click.echo(quiet_table.to_string(index=False))


if __name__ == "__main__":
    main()
