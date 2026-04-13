"""Create configs to test complementarity of early warning at different thresholds."""
from copy import deepcopy
from itertools import product
from pathlib import Path

import click
import yaml

# Set defaults for other investments
other_investments = {
    "baseline": None,
    "neglected_pathogen_rd": {
        "strategy": "top",
        "num": 3
    },
    "universal_flu_rd": {
        "active": True,
        "platform_response_invest": "both",
        "initial_share_ufv": 0.1
    },
    "advance_capacity": {
        "share_target_advance_capacity": 0.5
    }
}

@click.command()
@click.argument('config_dir', type=click.Path(), default="./config/scenario_configs/ew_complementarity_analysis")
@click.argument('base_config_path', type=click.Path(exists=True), default="./config/scenario_configs/standard/baseline.yaml")
def create_early_warning_invest_configs(config_dir, base_config_path):

    # Create scenario config outdir
    outdir = Path(config_dir)
    outdir.mkdir(parents=False, exist_ok=True)

    # Load baseline config
    with open(base_config_path, 'r') as f:
        baseline_config = yaml.safe_load(f)

    # 1. Write out the baseline config as baseline.yaml
    baseline_output_path = outdir / "baseline.yaml"
    with open(baseline_output_path, 'w') as f:
        yaml.dump(baseline_config, f, sort_keys=False)

    precisions = [0, 0.2, 0.4, 0.6, 0.8]
    recalls = [0, 0.2, 0.4, 0.6, 0.8]

    combos = product(precisions, recalls)

    for (precision, recall) in combos:
        improved_early_warning = {
            'active': True,
            'precision': precision,
            'recall': recall
        }

        for (other_invest_cat, other_params) in other_investments.items():

            new_config = deepcopy(baseline_config)
            new_config['improved_early_warning'] = improved_early_warning

            if other_invest_cat != "baseline":
                new_config[other_invest_cat] = other_params

            new_config_path = outdir / f"{other_invest_cat}_prec{precision:.1f}_rec{recall:.1f}.yaml"
            with open(new_config_path, 'w+') as f:
                yaml.dump(new_config_path, f, sort_keys=False)

if __name__ == "__main__":
    create_early_warning_invest_configs()