"""Generate scenario config files for pairwise investment complementarity analysis.

Reads a baseline scenario config and writes out all individual and pairwise
combinations of the four core interventions (improved_early_warning,
neglected_pathogen_rd, universal_flu_rd, advance_capacity).

Optional ``--include-prevac0`` / ``--include-prec1`` add extra filenames; early-warning
precision/recall and UFV ``initial_share_ufv`` are read from the MATLAB run config, not
from these YAML files.

Inputs:  config/scenario_configs/standard/status_quo.yaml (or --base-config-path)
Outputs: config/scenario_configs/pairwise_combos/*.yaml (or --config-dir)

Usage:
    python scripts/create_pairwise_configs.py [config_dir] [base_config_path]
        [--include-prevac0] [--include-prec1]
"""
from copy import deepcopy
from itertools import combinations
from pathlib import Path

import click
import yaml

scenario_config_updates = {
    "improved_early_warning": {
        "surplus": {
            "active": True,
        }
    },
    "neglected_pathogen_rd": {
        "surplus": {
            "strategy": "top",
            "num": 3
        }
    },
    "universal_flu_rd": {
        "surplus" : {
            "active": True,
            "platform_response_invest": "both",
        },
    },
    "advance_capacity": {
        "surplus": {
            "share_target_advance_capacity": 1
        }
    }
}

@click.command()
@click.argument('config_dir', type=click.Path(), default="./config/scenario_configs/pairwise_combos")
@click.argument('base_config_path', type=click.Path(exists=True), default="./config/scenario_configs/standard/status_quo.yaml")
@click.option('--include-prevac0', is_flag=True, default=False)
@click.option('--include-prec1', is_flag=True, default=False)
def create_pairwise_configs(config_dir, base_config_path, include_prevac0, include_prec1):
    """Write status-quo, single-intervention, and pairwise scenario config files."""
    # --- Setup ---
    outdir = Path(config_dir)
    outdir.mkdir(parents=False, exist_ok=True)

    # Load status-quo config
    with open(base_config_path, 'r') as f:
        status_quo_config = yaml.safe_load(f)

    # 1. Write out the status-quo config as status_quo.yaml
    status_quo_output_path = outdir / "status_quo.yaml"
    with open(status_quo_output_path, 'w') as f:
        yaml.dump(status_quo_config, f, sort_keys=False)

    # --- Pairwise combinations ---

    # Pair each investment intervention with each other (all unordered pairs)
    scenario_keys = list(scenario_config_updates.keys())
    scenario_types = ["surplus"]

    # Create all unique unordered pairwise combinations for each scenario type (no duplicate orderings)
    pairwise_combos = list(combinations(scenario_keys, 2))

    for scenario_type in scenario_types:
        for combo in pairwise_combos:
            combo_name = "_and_".join(combo)
            new_config = deepcopy(status_quo_config)
            for k in combo:
                param_update = scenario_config_updates[k][scenario_type]
                assert k in new_config.keys()
                new_config[k] = param_update
            output_path = outdir / f"{combo_name}_{scenario_type}.yaml"
            with open(output_path, 'w') as f:
                yaml.dump(new_config, f, sort_keys=False)

    # --- Single-intervention configs ---
    for scenario_type in scenario_types:
        for scenario_key in scenario_keys:
            new_config = deepcopy(status_quo_config)
            param_update = scenario_config_updates[scenario_key][scenario_type]
            new_config[scenario_key] = param_update
            output_path = outdir / f"{scenario_key}_{scenario_type}.yaml"
            with open(output_path, 'w') as f:
                yaml.dump(new_config, f, sort_keys=False)

    # Optional: same scenario shapes as above; precision/recall and initial_share_ufv are run-config
    # parameters (set improved_ew_precision / initial_share_ufv in the job run_config when needed).
    if include_prec1:
        for scenario_type in scenario_types:
            new_config = deepcopy(status_quo_config)
            new_config['improved_early_warning'] = deepcopy(scenario_config_updates["improved_early_warning"][scenario_type])
            output_path = outdir / f"improved_early_warning_prec1_{scenario_type}.yaml"
            with open(output_path, 'w') as f:
                yaml.dump(new_config, f, sort_keys=False)

            for other in [k for k in scenario_keys if k != "improved_early_warning"]:
                combo_name = f"improved_early_warning_prec1_and_{other}"
                new_config = deepcopy(status_quo_config)
                new_config['improved_early_warning'] = deepcopy(scenario_config_updates["improved_early_warning"][scenario_type])
                param_update = scenario_config_updates[other][scenario_type]
                new_config[other] = param_update
                output_path = outdir / f"{combo_name}_{scenario_type}.yaml"
                with open(output_path, 'w') as f:
                    yaml.dump(new_config, f, sort_keys=False)

    if include_prevac0:
        non_ufv_keys = [k for k in scenario_keys if k != "universal_flu_rd"]

        for scenario_type in scenario_types:
            new_config = deepcopy(status_quo_config)
            new_config['universal_flu_rd'] = deepcopy(scenario_config_updates["universal_flu_rd"][scenario_type])
            outpath = outdir / f"universal_flu_rd_prevac0_{scenario_type}.yaml"
            with open(outpath, 'w') as f:
                yaml.dump(new_config, f, sort_keys=False)

            for other in non_ufv_keys:
                combo_name = f"universal_flu_rd_and_{other}_prevac0"
                new_config = deepcopy(status_quo_config)
                new_config['universal_flu_rd'] = deepcopy(scenario_config_updates["universal_flu_rd"][scenario_type])
                param_update = scenario_config_updates[other][scenario_type]
                new_config[other] = param_update
                outpath = outdir / f"{combo_name}_{scenario_type}.yaml"
                with open(outpath, 'w') as f:
                    yaml.dump(new_config, f, sort_keys=False)

if __name__ == "__main__":
    create_pairwise_configs()