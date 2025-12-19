from itertools import combinations
from pathlib import Path
from copy import deepcopy

import click
import yaml

scenario_config_updates = {
    "improved_early_warning": {
        "bcr": {
            "active": True,
            "precision": 0.5,
            "recall": 0.4
        },
        "surplus": {
            "active": True,
            "precision": 0.3,
            "recall": 0.5
        }
    },
    "neglected_pathogen_rd": {
        "bcr": {
            "strategy": "top",
            "num": 1
        },
        "surplus": {
            "strategy": "top",
            "num": 3
        }
    },
    "universal_flu_rd": {
        "bcr": {
            "active": True,
            "platform_response_invest": "both",
            "initial_share_ufv": 0.1
        },
        "surplus" : {
            "active": True,
            "platform_response_invest": "single",
            "initial_share_ufv": 0.1
        },
    },
    "advance_capacity": {
        "bcr": {
            "share_target_advance_capacity": 0.75
        },
        "surplus": {
            "share_target_advance_capacity": 1
        }
    }
}

@click.command()
@click.argument('config_dir', type=click.Path(), default="./config/scenario_configs/pairwise_combos")
@click.argument('base_config_path', type=click.Path(exists=True), default="./config/scenario_configs/standard/baseline.yaml")

def create_pairwise_configs(config_dir, base_config_path):

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

    # 2. Make pairwise configs (pair each investment intervention with each other under both bcr and surplus scenarios)
    scenario_keys = list(scenario_config_updates.keys())
    scenario_types = ["bcr", "surplus"]

    # Create all unique unordered pairwise combinations for each scenario type (no duplicate orderings)
    pairwise_combos = list(combinations(scenario_keys, 2))

    for scenario_type in scenario_types:
        for combo in pairwise_combos:
            combo_name = "_and_".join(combo)
            new_config = deepcopy(baseline_config)
            for k in combo:
                param_update = scenario_config_updates[k][scenario_type]
                assert k in new_config.keys()
                new_config[k] = param_update
            output_path = outdir / f"{combo_name}_{scenario_type}.yaml"
            with open(output_path, 'w') as f:
                yaml.dump(new_config, f, sort_keys=False)

    # Add all single-intervention configs too
    for scenario_type in scenario_types:
        for scenario_key in scenario_keys:
            new_config = deepcopy(baseline_config)
            param_update = scenario_config_updates[scenario_key][scenario_type]
            new_config[scenario_key] = param_update
            output_path = outdir / f"{scenario_key}_{scenario_type}.yaml"
            with open(output_path, 'w') as f:
                yaml.dump(new_config, f, sort_keys=False)

    # Add configs for improved early warning with precision=1 for both bcr and surplus
    for scenario_type in scenario_types:
        # single: improved_early_warning, precision=1
        new_config = deepcopy(baseline_config)
        new_config['improved_early_warning'] = deepcopy(scenario_config_updates["improved_early_warning"][scenario_type])
        new_config['improved_early_warning']['precision'] = 1

        output_path = outdir / f"improved_early_warning_prec1_{scenario_type}.yaml"
        with open(output_path, 'w') as f:
            yaml.dump(new_config, f, sort_keys=False)

        # pairwise: improved_early_warning (precision=1) with each other scenario
        for other in [k for k in scenario_keys if k != "improved_early_warning"]:
            combo_name = f"improved_early_warning_prec1_and_{other}"
            new_config = deepcopy(baseline_config)
            # improved_early_warning with precision=1
            new_config['improved_early_warning'] = deepcopy(scenario_config_updates["improved_early_warning"][scenario_type])
            new_config['improved_early_warning']['precision'] = 1
            # add the other scenario
            param_update = scenario_config_updates[other][scenario_type]
            new_config[other] = param_update

            output_path = outdir / f"{combo_name}_{scenario_type}.yaml"
            with open(output_path, 'w') as f:
                yaml.dump(new_config, f, sort_keys=False)

    # Also include pairwise and single scenarios where universal flu vaccine initial protection is zero,
    # so universal_flu_rd is combined with each other intervention *with* initial_share_ufv = 0
    non_ufv_keys = [k for k in scenario_keys if k != "universal_flu_rd"]

    for scenario_type in scenario_types:
        # single: universal_flu_rd only, with initial_share_ufv=0
        new_config = deepcopy(baseline_config)
        new_config['universal_flu_rd'] = deepcopy(scenario_config_updates["universal_flu_rd"][scenario_type])
        new_config['universal_flu_rd']['initial_share_ufv'] = 0
        outpath = outdir / f"universal_flu_rd_prevac0_{scenario_type}.yaml"
        with open(outpath, 'w') as f:
            yaml.dump(new_config, f, sort_keys=False)

        # pairwise: universal_flu_rd with each other (non ufv) scenario, with initial_share_ufv=0
        for other in non_ufv_keys:
            combo_name = f"universal_flu_rd_and_{other}_prevac0"
            new_config = deepcopy(baseline_config)
            # update universal_flu_rd with initshare0
            new_config['universal_flu_rd'] = deepcopy(scenario_config_updates["universal_flu_rd"][scenario_type])
            new_config['universal_flu_rd']['initial_share_ufv'] = 0
            # update the other scenario investment
            param_update = scenario_config_updates[other][scenario_type]
            new_config[other] = param_update

            outpath = outdir / f"{combo_name}_{scenario_type}.yaml"
            with open(outpath, 'w') as f:
                yaml.dump(new_config, f, sort_keys=False)

if __name__ == "__main__":
    create_pairwise_configs()