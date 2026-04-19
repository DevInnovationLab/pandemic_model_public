"""Batch lognormal duration fits for filtered epidemic CSVs (orchestrates fit_mle_duration.py)."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import click

from pandemic_statistics.pipeline_names import split_filtered_stem

_SCRIPTS_DIR = Path(__file__).resolve().parent
_DURATION_FIT = _SCRIPTS_DIR / "fit_duration_dist.py"

_BASE_TRUNC_YEARS = 10
_EXTRA_TRUNC_FOR_STANDARD = (5, 50)

_SAMPLE_SIZES = (50_000, 1_000_000)
_BASELINE_FILTER_SLUGS = frozenset({"all_int_0d01_1900"})


def _run_fit_duration(args: list[str]) -> None:
    """Invoke fit_duration_dist.py via subprocess."""
    cmd = [sys.executable, str(_DURATION_FIT), *args]
    subprocess.run(cmd, check=True)


@click.command()
@click.option(
    "--input-dir",
    type=click.Path(exists=True, file_okay=False, dir_okay=True, path_type=Path),
    default=Path("data/derived/epidemics_filtered"),
    help="Directory containing filtered epidemic CSVs.",
)
@click.option(
    "--outdir",
    type=click.Path(file_okay=False, path_type=Path),
    default=Path("data/clean/duration_distributions"),
    help="Directory for duration parameter sample CSVs.",
)
@click.option(
    "--fig-outdir",
    type=click.Path(file_okay=False, path_type=Path),
    default=Path("output/duration_dist_figs"),
    help="Directory for PMF PDFs (50k sample runs only).",
)
@click.option(
    "--seed",
    type=int,
    default=42,
    help="Random seed for all duration fits.",
)
@click.option(
    "--base-trunc-years",
    type=int,
    default=_BASE_TRUNC_YEARS,
    help="Truncation horizon (years) for every filtered CSV.",
)
def main(
    input_dir: Path,
    outdir: Path,
    fig_outdir: Path,
    seed: int,
    base_trunc_years: int,
) -> None:
    """
    For each CSV in input-dir: fit duration with base trunc-years and n_samples
    50,000 and 1,000,000 (matching arrival batch). For filter slug
    ``all_int_0d01_1900`` (standard all-risk baseline),
    also run trunc-years 5 and 50.
    """
    input_dir = Path(input_dir).resolve()
    outdir = Path(outdir).resolve()
    fig_outdir = Path(fig_outdir).resolve()
    csv_paths = sorted(input_dir.glob("*.csv"))

    if not csv_paths:
        raise FileNotFoundError(f"No CSV files found in directory: {input_dir}")

    for fp in csv_paths:
        print(f"\n=== {fp.name} ===")

        try:
            _, filter_slug = split_filtered_stem(fp.stem)
        except ValueError:
            filter_slug = ""
        trunc_set: list[int] = [base_trunc_years]
        if filter_slug in _BASELINE_FILTER_SLUGS:
            trunc_set = sorted(set(trunc_set + list(_EXTRA_TRUNC_FOR_STANDARD)))

        for trunc_years in trunc_set:
            for n_samples in _SAMPLE_SIZES:
                create_fig = n_samples == 50_000
                args = [
                    str(fp),
                    "--outdir",
                    str(outdir),
                    "--trunc-years",
                    str(trunc_years),
                    "--n-samples",
                    str(n_samples),
                    "--seed",
                    str(seed),
                ]
                if create_fig:
                    args.extend(["--fig-outdir", str(fig_outdir), "--create-fig"])
                else:
                    args.append("--no-fig")

                _run_fit_duration(args)

    print("\nDone with batch run of fit_duration_dist.py")


if __name__ == "__main__":
    main()
