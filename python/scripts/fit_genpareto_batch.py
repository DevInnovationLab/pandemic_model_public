"""Batch GPD fits for filtered epidemic CSVs."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import click

from pandemic_statistics.pipeline_names import split_filtered_stem

_SCRIPTS_DIR = Path(__file__).resolve().parent
_VENDOR_FIT = (
    _SCRIPTS_DIR.parent / "vendor" / "pandemic-statistics" / "scripts" / "fit_genpareto_mle.py"
)


def _run_fit_genpareto(args: list[str]) -> None:
    """Invoke the pandemic-statistics GPD CLI via subprocess (cwd should be repository root)."""
    cmd = [sys.executable, str(_VENDOR_FIT), *args]
    subprocess.run(cmd, check=True)


@click.command()
@click.option(
    "--input-dir",
    type=click.Path(exists=True, file_okay=False, dir_okay=True, path_type=Path),
    default=Path("data/derived/epidemics_filtered"),
    help="Directory containing filtered epidemic CSVs to fit GPD models on.",
)
@click.option(
    "--outdir",
    type=click.Path(file_okay=False, path_type=Path),
    default=Path("data/clean/arrival_distributions"),
    help="Directory for arrival distribution outputs.",
)
@click.option(
    "--fit-measure",
    type=click.Choice(["intensity", "severity"]),
    default="severity",
    help="Mortality measure to fit distribution on.",
)
@click.option(
    "--trunc-method",
    type=click.Choice(["sharp", "smooth", "taleb"]),
    default="sharp",
    help="Truncation method for upper tail.",
)
@click.option(
    "--seed",
    type=int,
    default=42,
    help="Random seed for all fits.",
)
def main(
    input_dir: Path,
    outdir: Path,
    fit_measure: str,
    trunc_method: str,
    seed: int,
) -> None:
    """
    Run generalized Pareto fits for all datasets in a directory.

    For each CSV in input-dir, runs the GPD fitting routine for the default upper
    bound (200) with 50,000 and 1,000,000 samples. For filter slug
    ``all_int_0d01_1900`` (baseline all-risk screening),
    also runs extra uppers 1,000 and 10,000.

    Run from the repository root: poetry --directory python run python scripts/fit_genpareto_batch.py
    """
    input_dir = Path(input_dir).resolve()
    outdir = Path(outdir).resolve()
    csv_paths = sorted(input_dir.glob("*.csv"))

    if not csv_paths:
        raise FileNotFoundError(f"No CSV files found in directory: {input_dir}")

    base_sample_sizes = (50_000, 1_000_000)
    default_upper = 200.0
    _BASELINE_FILTER_SLUGS = frozenset({"all_int_0d01_1900"})

    for fp in csv_paths:
        print(f"\n=== {fp.name} ===")

        try:
            _, filter_slug = split_filtered_stem(fp.stem)
        except ValueError:
            filter_slug = ""
        extra_uppers = filter_slug in _BASELINE_FILTER_SLUGS

        for n_samples in base_sample_sizes:
            create_fig = n_samples == 50_000

            args = [
                str(fp),
                "--fit-measure",
                fit_measure,
                "--trunc-method",
                trunc_method,
                "--upper-bound",
                str(default_upper),
                "--n-samples",
                str(n_samples),
                "--seed",
                str(seed),
                "--outdir",
                str(outdir),
            ]
            args.append("--create-fig" if create_fig else "--no-fig")

            _run_fit_genpareto(args)

        if extra_uppers:
            for upper in (1000.0, 10000.0):
                for n_samples in base_sample_sizes:
                    create_fig = n_samples == 50_000

                    args = [
                        str(fp),
                        "--fit-measure",
                        fit_measure,
                        "--trunc-method",
                        trunc_method,
                        "--upper-bound",
                        str(upper),
                        "--n-samples",
                        str(n_samples),
                        "--seed",
                        str(seed),
                        "--outdir",
                        str(outdir),
                    ]
                    args.append("--create-fig" if create_fig else "--no-fig")

                    _run_fit_genpareto(args)

    print("\nDone with batch run of fit_genpareto_mle.py")


if __name__ == "__main__":
    main()
