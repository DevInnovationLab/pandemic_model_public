# Configuration System

The model uses a three-tier YAML configuration system. All paths in config files
are relative to the repository root (the working directory when running scripts).

---

## Tier 1: Job Configs (`job_configs/`)

Specify a complete simulation run: simulation parameters, social value parameters,
file paths for inputs, and capacity/vaccine/surveillance parameters.

**Usage:**
```matlab
run_workflow('config/job_configs/allrisk_base.yaml')
run_job('config/job_configs/allrisk_base.yaml')
estimate_unmitigated_losses('config/job_configs/allrisk_base.yaml')
```

### Required Fields (all entry points)

| Field | Type | Description |
|---|---|---|
| `outdir` | string | Output directory root (e.g. `./output/jobs`) |
| `num_simulations` | int | Number of Monte Carlo simulations |
| `sim_periods` | int | Simulation horizon in years |
| `seed` | int | Base random seed (chunk seed = seed + chunk_idx) |
| `arrival_dist_config` | string | Path to arrival distribution directory |
| `duration_dist_config` | string | Path to duration distribution CSV |
| `arrival_rates` | string | Path to arrival rates CSV |
| `pathogen_info` | string | Path to pathogen info CSV |
| `econ_loss_model_config` | string | Path to economic loss model YAML |
| `y` | float | Per capita GDP growth rate |
| `r` | float | Social discount rate |
| `P0` | float | Base year world population |
| `Y0` | float | Base year world GDP per capita (USD) |
| `value_of_death` | float | Value of statistical life (USD) |

### Additional Required Fields (run_job / run_workflow only)

| Field | Type | Description |
|---|---|---|
| `scenario_configs` | string | Path to scenario configs directory |
| `ptrs_pathogen` | string | Path to pathogen PTRS table CSV |
| `prototype_effect_ptrs` | string | Path to prototype effect PTRS CSV |
| `rd_timelines` | string | Path to R&D timelines CSV |
| `response_threshold_path` | string | Path to response threshold YAML |
| `tolerance` | float | Numerical tolerance for near-zero comparisons |
| `save_mode` | string | Output verbosity: `"light"` or `"full"` |
| `pandemic_table_out` | string | Pandemic table output: `"none"`, `"skinny"`, or `"full"` |

### Optional Fields

| Field | Default | Description |
|---|---|---|
| `add_datetime_to_outdir` | `0` | Append timestamp to output folder name |
| `save_output` | `1` | Whether to save outputs |
| `profile` | `false` | Enable MATLAB profiler |
| `gamma` | — | Fraction of remaining harm mitigated by vaccine |
| `conservative` | `1` | Harm timing: `1` = start of period, `0` = end |

### Capacity / Vaccine / Surveillance Parameters

See `allrisk_base.yaml` for the full list of capacity parameters (`theta`, `max_capacity`,
`delta`, `mRNA_share`, etc.), vaccine parameters (`tau_m`, `tau_o`, `inp_RD_spend`, etc.),
and surveillance parameters (`surveil_annual_installation_spend`, etc.).

---

## Tier 2: Scenario Configs (`scenario_configs/`)

Each YAML file defines one intervention scenario. A job config's `scenario_configs`
field points to a directory; all `.yaml` files in that directory are loaded as scenarios.

Scenarios define overrides to the base job config parameters, plus intervention-specific
parameters:
- `neglected_pathogen_rd`: Neglected pathogen R&D strategy
- `universal_flu_rd`: Universal flu vaccine parameters
- `advance_capacity`: Advance manufacturing capacity targets
- `improved_early_warning`: Surveillance precision/recall configuration

A scenario named `baseline.yaml` is required in every scenario configs directory.

### Generated Configs

`scenario_configs/ew_complementarity_analysis/` contains auto-generated configs
produced by `python/scripts/create_early_warning_invest_configs.py`. Do not edit
these files manually — regenerate them via the script if parameters change.

---

## Tier 3: Sensitivity Configs (`sensitivity_configs/`)

Specify parameter sweeps over a base job config.

**Usage:**
```matlab
run_sensitivity('config/sensitivity_configs/no_mitigation_all.yaml', 'unmitigated')
run_sensitivity('config/sensitivity_configs/baseline_vaccine_program.yaml', 'response')
```

### Sensitivity Config Fields

| Field | Description |
|---|---|
| `base_job_config` | Path to the base job config YAML |
| `outdir` | Output directory root for sensitivity results |
| `fix_params` | Fields to override in the base config for ALL variants |
| `sensitivities` | Dict mapping parameter names to lists of values to sweep |

### Runtime Composition Semantics

`run_sensitivity` expands the `sensitivities` dict into a canonical list of variant
configs at runtime via `expand_sensitivities.m`. One-parameter sweeps produce variants
named `{param}_value_{i}`; multi-parameter sweeps produce joined names. The baseline
(base config + fix_params) is always run as variant `baseline/`.

Each variant is a complete job config written to a temp YAML and run independently.
After all SLURM array tasks finish, call `aggregate_unmitigated_losses` per variant
directory if the run was chunked.

---

## Adding a New Job Config

1. Copy the closest existing config (e.g. `allrisk_base.yaml`).
2. Change `outdir` if you want results in a separate directory.
3. Update any parameters you want to vary.
4. Ensure all required fields are present — `validate_job_config` will error at
   runtime if any are missing.
