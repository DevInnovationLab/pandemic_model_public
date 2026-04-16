"""update_covid_severity.py — Overwrite COVID-19 severity and intensity in filtered epidemic datasets.

Reads the ex-ante COVID-19 severity from a YAML file and updates matching rows
in all *_filt_*.csv files in the epidemics dataset directory, writing modified
copies to the output directory.

Inputs:  data/epidemics_ds/*_filt_*.csv, data/clean/inverted_covid_severity.yaml
Outputs: data/epidemics_ds/modified/*_filt_*_mod.csv

Usage:
    python scripts/update_covid_severity.py [--epidemics_ds_dir PATH] [--outdir PATH] [--covid-severity-file PATH]
"""
from pathlib import Path

import click
import pandas as pd
import yaml

@click.command()
@click.option("--epidemics_ds_dir", type=click.Path(exists=True, file_okay=False), default="./data/epidemics_ds")
@click.option("--outdir", type=click.Path(exists=True), default="./data/epidemics_ds/modified")
@click.option("--covid-severity-file", type=click.Path(exists=True), default="./data/clean/inverted_covid_severity.yaml")
def update_hiv_covid_severity(epidemics_ds_dir, outdir, covid_severity_file):
    """
    Update the severity and intensity for covid-19 in all epidemics_ds files in the given directory
    that contain '_filt_' in their filename, using the provided covid severity file.
    """
    epidemics_ds_dir = Path(epidemics_ds_dir)
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    with open(covid_severity_file, "r") as f:
        covid_sev_dict = yaml.safe_load(f)
    covid_severity = covid_sev_dict["ex_ante_severity"]

    for epidemics_ds_path in epidemics_ds_dir.glob("*_filt_*.csv"):
        epidemics_ds = pd.read_csv(epidemics_ds_path)

        epidemics_ds.loc[epidemics_ds['disease'] == 'covid-19', 'severity'] = covid_severity
        epidemics_ds.loc[epidemics_ds['disease'] == 'covid-19', 'intensity'] = (
            covid_severity /
            epidemics_ds.loc[epidemics_ds['disease'] == 'covid-19', 'duration']
        )

        # Save epidemics_ds
        outfp = outdir / (epidemics_ds_path.stem + "_mod.csv")
        epidemics_ds.to_csv(outfp, index=False)

if __name__ == "__main__":
    update_hiv_covid_severity()