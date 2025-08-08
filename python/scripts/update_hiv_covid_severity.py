from pathlib import Path

import click
import pandas as pd
import yaml

@click.command()
@click.argument("epidemics_ds_path", type=click.Path(exists=True, dir_okay=False))
@click.option("--outdir", type=click.Path(exists=True), default="./data/epidemics_ds/modified")
@click.option("--hiv-deaths-file", type=click.Path(exists=True), default="./data/clean/hiv_deaths_per_10k.csv")
@click.option("--covid-severity-file", type=click.Path(exists=True), default="./data/clean/inverted_covid_severity.yaml")
def update_hiv_covid_severity(epidemics_ds_path, outdir, hiv_deaths_file, covid_severity_file):
    epidemics_ds = pd.read_csv(epidemics_ds_path)
    hiv_deaths = pd.read_csv(hiv_deaths_file)

    with open(covid_severity_file, "r") as f:
        covid_sev_dict = yaml.safe_load(f)
    covid_severity = covid_sev_dict["ex_ante_severity"]

    # Calculate HIV severity
    hiv_severity = ( 
        hiv_deaths['deaths'].sum() / 
        hiv_deaths.sort_values('year')['population'][0]  # Use population from base year 
    ) * 10000 

    # Put severities in epidemics_ds
    epidemics_ds.loc[epidemics_ds['disease'] == 'hiv/aids', 'severity'] = hiv_severity
    epidemics_ds.loc[epidemics_ds['disease'] == 'hiv/aids', 'intensity'] = (
        hiv_severity / 
        epidemics_ds.loc[epidemics_ds['disease'] == 'hiv/aids', 'duration']
    )
    epidemics_ds.loc[epidemics_ds['disease'] == 'covid-19', 'severity'] = covid_severity
    epidemics_ds.loc[epidemics_ds['disease'] == 'covid-19', 'intensity'] = (
        covid_severity / 
        epidemics_ds.loc[epidemics_ds['disease'] == 'covid-19', 'duration']
    )

    # Save epidemics_ds
    outfp = Path(outdir) / (Path(epidemics_ds_path).stem + "_mod.csv")
    epidemics_ds.to_csv(outfp, index=False)

if __name__ == "__main__":
    update_hiv_covid_severity()