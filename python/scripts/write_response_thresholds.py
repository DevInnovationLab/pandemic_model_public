"""write_response_thresholds.py — Write response threshold YAML files derived from COVID-19 severity.

Reads the ex-ante COVID-19 severity from a YAML file and generates a set of response
threshold files at full, half, and quarter of the COVID-19 severity and intensity,
writing one YAML per (type, scale) combination.

Inputs:  data/clean/inverted_covid_severity.yaml
Outputs: output/response_thresholds/response_thresholds/response_threshold_*.yaml

Usage:
    python scripts/write_response_thresholds.py
"""
import os

import click
import yaml

@click.command()
def create_response_threshold():
    """Generate response threshold YAML files at fractions of COVID-19 severity."""
    with open("./data/clean/inverted_covid_severity.yaml", "r") as f:
        sev_dict = yaml.safe_load(f)

    covid_severity = sev_dict["ex_ante_severity"]
    covid_intensity = covid_severity / 5 

    for typ, val in [("intensity", covid_intensity), ("severity", covid_severity)]:
        for name, factor in [("half", 0.5), ("quarter", 0.25), ("", 1)]:
            if factor == 1:
                outpath = f"./output/response_thresholds/response_thresholds/response_threshold_covid_{typ}.yaml"
            else:
                outpath = f"./output/response_thresholds/response_thresholds/response_threshold_{name}_covid_{typ}.yaml"
       
            os.makedirs(os.path.dirname(outpath), exist_ok=True)
            with open(outpath, "w") as f:
                yaml.dump(
                    {
                        "response_threshold": val * factor,
                        "response_threshold_type": typ,
                    },
                    f
                )

if __name__ == "__main__":
    create_response_threshold()