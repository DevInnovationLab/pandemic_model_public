"""update_covid_severity.py — Overwrite COVID-19 severity and intensity in one epidemic dataset.

Reads the ex-ante COVID-19 severity from a YAML file and updates matching rows,
writing a CSV whose stem ends with ``_upcov``.

Inputs:  one table (``.xlsx`` or ``.csv``), default ``data/raw/epidemics_241210.xlsx``;
         ``data/derived/inverted_covid_severity.yaml``
Outputs: ``<stem>_upcov.csv`` under ``--outdir`` (or ``--out`` if given).

Usage:
    python scripts/update_covid_severity.py [--input PATH] [--outdir PATH] [--out PATH] [--covid-severity-file PATH]
"""

from pathlib import Path

import click
import pandas as pd
import yaml


def _read_table(path: Path) -> pd.DataFrame:
    """Load a spreadsheet as a dataframe."""
    suf = path.suffix.lower()
    if suf == ".xlsx":
        return pd.read_excel(path)
    if suf == ".csv":
        return pd.read_csv(path)
    raise ValueError(f"Input must be .xlsx or .csv, got: {path.suffix}")


@click.command()
@click.option(
    "--ds-path",
    "ds_path",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    default=Path("./data/derived/epidemics_241210_clean.csv"),
    help="Epidemic dataset to update (Excel or CSV).",
)
@click.option(
    "--outdir",
    "outdir",
    type=click.Path(path_type=Path),
    default=Path('./data/derived'),
    help="Full path for the output CSV. Overrides --outdir.",
)
@click.option(
    "--covid-severity-file",
    type=click.Path(exists=True, path_type=Path),
    default=Path("./data/derived/inverted_covid_severity.yaml"),
)
def update_covid_severity(
    ds_path: Path,
    outdir: Path ,
    covid_severity_file: Path,
) -> None:
    """
    Set severity and intensity for covid-19 rows using the YAML ex-ante severity,
    and write ``<stem>_upcov.csv``.
    """
    ds_path = ds_path.resolve()
    outdir = outdir.resolve()
    covid_severity_file = covid_severity_file.resolve()

    outdir.mkdir(parents=True, exist_ok=True)
    out_fp = outdir / f"{ds_path.stem}_upcov.csv"

    with open(covid_severity_file, "r", encoding="utf-8") as f:
        covid_sev_dict = yaml.safe_load(f)
    covid_severity = covid_sev_dict["ex_ante_severity"]

    epidemics_ds = _read_table(ds_path)

    epidemics_ds.loc[epidemics_ds["disease"] == "covid-19", "severity"] = covid_severity
    epidemics_ds.loc[epidemics_ds["disease"] == "covid-19", "intensity"] = (
        covid_severity
        / epidemics_ds.loc[epidemics_ds["disease"] == "covid-19", "duration"]
    )

    epidemics_ds.to_csv(out_fp, index=False)


if __name__ == "__main__":
    update_covid_severity()
