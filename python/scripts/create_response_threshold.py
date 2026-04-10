import os

import click
import yaml

@click.command()
def create_response_threshold():
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