"""Batch runs of filter_epidemics for several parameter sets."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import click

_SCRIPTS_DIR = Path(__file__).resolve().parent
_VENDOR_FILTER = (
    _SCRIPTS_DIR.parent / "vendor" / "pandemic-statistics" / "scripts" / "filter_epidemics.py"
)


def _run_filter_epidemics(args: list[str]) -> None:
    """Invoke the pandemic-statistics CLI via subprocess."""
    cmd = [sys.executable, str(_VENDOR_FILTER), *args]
    subprocess.run(cmd, check=True)


@click.command()
@click.option(
    "--input",
    "fp",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    default=Path("data/derived/epidemics_241210_clean_upcov.csv"),
    help="Marani-cleaned CSV under data/derived.",
)
@click.option(
    "--fig-outdir",
    type=click.Path(file_okay=False, path_type=Path),
    default=Path("output/epidemics_filter_figures"),
    help="Directory for Sankey PDFs.",
)
@click.option(
    "--data-outdir",
    type=click.Path(file_okay=False, path_type=Path),
    default=Path("data/derived/epidemics_filtered"),
    help="Directory for filtered CSVs (skipped for --figure-only runs).",
)
def main(
    fp: Path,
    fig_outdir: Path,
    data_outdir: Path,
) -> None:
    """
    Run filter_epidemics.py with several parameter sets.
    """
    fp = Path(fp).resolve()
    fig_outdir = Path(fig_outdir).resolve()
    data_outdir = Path(data_outdir).resolve()

    fig_outdir.mkdir(parents=True, exist_ok=True)
    data_outdir.mkdir(parents=True, exist_ok=True)

    fig_s = str(fig_outdir)
    data_s = str(data_outdir)
    fp_s = str(fp)

    runs: list[tuple[str, list[str]]] = [
        ("Standard", [fp_s, "--fig-outdir", fig_s, "--data-outdir", data_s, "--write-sankey"]),
        (
            "Threshold 1",
            [fp_s, "--thresh", "1", "--fig-outdir", fig_s, "--data-outdir", data_s],
        ),
        (
            "Year min 1950",
            [fp_s, "--year-min", "1950", "--fig-outdir", fig_s, "--data-outdir", data_s],
        ),
        (
            "Include unidentified",
            [fp_s, "--incl-unid", "--fig-outdir", fig_s, "--data-outdir", data_s],
        ),
        (
            "Year and threshold only",
            [fp_s, "--year-thresh-only", "--fig-outdir", fig_s, "--data-outdir", data_s],
        ),
        (
            "Airborne only",
            [fp_s, "--airborne-only", "--fig-outdir", fig_s, "--data-outdir", data_s],
        ),
    ]

    for name, args in runs:
        print(f"\n=== {name} ===")
        _run_filter_epidemics(args)

    print("\nDone with batch run of filter_epidemics.py")


if __name__ == "__main__":
    main()
