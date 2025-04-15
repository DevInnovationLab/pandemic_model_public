"""Clean vaccine discovery timeline dataset."""

import pandas as pd


if __name__ == "__main__":

    discovery_ds = pd.read_csv("./data/raw/vaccine-discovery-dataset.csv")

    discovery_ds = discovery_ds \
        .rename(columns=lambda s: s.lower()) \
        .rename(columns={'name': 'disease'})

    pass