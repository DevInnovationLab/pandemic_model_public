import click
import yaml

@click.command()
def create_response_threshold():
    with open("./data/clean/inverted_covid_severity.yaml", "r") as f:
        sev_dict = yaml.safe_load(f)

    covid_severity = sev_dict["ex_ante_severity"]
    covid_intensity = covid_severity  / 5 # Need to undo hard coding here

    with open("./output/response_threshold_intensity.yaml", "w") as f:
        yaml.dump(
            {
                "response_threshold": covid_intensity / 2,
                "response_threshold_type": "intensity"
            },
            f
        )

    with open("./output/response_threshold_severity.yaml", "w") as f:
        yaml.dump(
            {
                "response_threshold": covid_severity / 2,
                "response_threshold_type": "severity"
            },
            f
        )

if __name__ == "__main__":
    create_response_threshold()