# Pandemic preparedness model

This repository contains the code behind [Estimating future pandemic harms and the gains from preparedness investments]() by Christopher Snyder *et al.* (unpublished).

## Repository structure


| Folder                           | Role                                                         |
| -------------------------------- | ------------------------------------------------------------ |
| `[config/](config/)`             | Configs for model runs (see explanation below)               |
| `[data/raw/](data/raw/)`         | Raw data that will be manipulated into model inputs          |
| `[data/derived/](data/derived/)` | Data cleaning intermediates — not final model inputs         |
| `[data/clean/](data/clean/)`     | Data used as inputs into the pandemic simulation models.     |
| `[matlab/](matlab/)`             | MATLAB code (mostly pandemic simulations and postprocessing) |
| `[python/](python/)`             | Python code (mostly input generation)                        |
| `[R/](R/)`                       | R code (mostly input generation)                             |
| `[slurm/](slurm/)`               | SLURM batch files for running scripts on remote cluster      |
| `[output/](output/)`             | Ouputs from pandemic simulations                             |


## Requirements


| Language | Version                             | Manager                                                   |
| -------- | ----------------------------------- | --------------------------------------------------------- |
| MATLAB   | R2020a+ (e.g. R2023a on RCC Midway) | —                                                         |
| Python   | 3.11.9                              | [Poetry](https://python-poetry.org/)                      |
| R        | —                                   | [renv](https://rstudio.github.io/renv/articles/renv.html) |


**MATLAB toolboxes:** Statistics and Machine Learning Toolbox (required). Parallel Computing Toolbox is optional.

## Installation

### 1. Submodules

We install two git submodules to obtain their helper functions: [yaml](https://github.com/MartinKoch123/yaml), a YAML parser for MATLAB, and [pandemic-statistics](https://github.com/ganqili/pandemic-statistics), a companion repository that contains reusable scripts for our pandemic risk modeling pipeline.

```bash
git submodule update --init --recursive
```

### 2. Python

We use [Poetry](https://python-poetry.org/) for Python package and dependency manangement. To install the package and virtual environment:

```bash
poetry --directory python install
```

To initialize the Python virtual environment, use the command returned by

```bash
poetry --directory python env activate
```

### 3. R

We use [renv](https://rstudio.github.io/renv/articles/renv.html) for R environment management. To install the virtual environment:

```bash
Rscript -e "renv::restore()"
```

## Model configuration

The pandemic simulation model composes **three YAML layers** at runtime:

1. **Run configs** (`[config/run_configs/](config/run_configs/)`) — Run-wide settings: simulations, horizons, paths to inputs, `outdir`, etc.
2. **Scenario configs** (`[config/scenario_configs/](config/scenario_configs/)`) — Intervention parameters (referenced by job configs).
3. **Sensitivity configs** (`[config/sensitivity_configs/](config/sensitivity_configs/)`) — Parameter sweeps for `run_sensitivity`: a base run config, fixed program assumptions, and one-at-a-time (or named multi-parameter) variants.

### Scenario config specification

`run_model` accepts `scenario_configs` in two forms:

1. **Legacy directory string** (unchanged): run all `*.yaml` in that directory.
2. **String list**: each entry is a single string interpreted as:
  - a literal scenario config path (if the file exists), or
  - a MATLAB regex pattern matched against scenario paths under `./config/scenario_configs`.

Rules:

- Duplicate files are removed while preserving first appearance.
- `status_quo.yaml` is required and is forced to the first scenario position.
- Resolved scenario files are recorded in `run_config.yaml` as `scenario_config_paths_resolved`.

Example:

```yaml
scenario_configs:
  - "./config/scenario_configs/standard/status_quo.yaml"
  - "^standard/advance_capacity_6_month\\.yaml$"
```

### Sensitivity config specification

A sensitivity config declares how to vary model parameters around one or more preparedness programs. `run_sensitivity` reads the YAML, expands it into a frozen manifest of every scenario, and runs (or resumes) simulations chunk by chunk.

**Top-level fields**


| Field                   | Role                                                         |
| ----------------------- | ------------------------------------------------------------ |
| `base_run_config`       | Template run config (same layer as `config/run_configs/`).   |
| `outdir`                | Root for this study (typically `./output/sensitivity_runs`). |
| `fix_params` (optional) | Defaults merged into every program block in the file.        |
| `program_sensitivities` | One block per preparedness program under study.              |


**Each program block** (for example `vaccine_program`, `advance_capacity`) contains:

- `fix_params` — values held fixed for that program, usually `scenario_configs` (which interventions to compare) plus any shared assumptions.
- `sensitivities` — parameters to vary, one scenario at a time.

Within `sensitivities`, each key is swept independently (one-at-a-time analysis):

- **List of values** — single-parameter sweep; each value becomes its own scenario subdirectory.
- **Struct** — multi-parameter alternative specification (for example `ptrs_pathogen_gamma1` setting two fields together).

**What `run_sensitivity` does**

1. Merges `fix_params` into the base run config for each program.
2. Expands every sensitivity entry into concrete `run_config.yaml` files under `outdir/<config_stem>/<program_name>/`.
3. Writes matching status-quo baseline configs for benefit comparisons.
4. Runs simulations via `run_model` when `run_type` is `response`, or `estimate_unmitigated_losses` when `run_type` is `unmitigated`.

For clarity and compute control, use one program block per sensitivity file unless you intentionally want several program studies in a single job (see `advance_investment_programs.yaml`).

Simulation outputs for a program live under `outdir/<config_stem>/<program_name>/` (for example `output/sensitivity_runs/baseline_vaccine_program/vaccine_program/`). On the cluster, submit long sensitivity jobs with `bash slurm/submit_sensitivity_workflow.sh`.

Example skeleton:

```yaml
base_run_config: "./config/run_configs/allrisk_base.yaml"
outdir: "./output/sensitivity_runs"
program_sensitivities:
  vaccine_program:
    fix_params:
      scenario_configs:
        - "./config/scenario_configs/standard/status_quo.yaml"
    sensitivities:
      gamma:
        - 0.3
        - 0.7
      ptrs_pathogen_gamma1:  # multi-parameter alternative
        ptrs_pathogen: "./data/clean/ptrs_table_always_succeed.csv"
        gamma: 1
```

## MATLAB from the command line

All MATLAB entry points in this repository are written to run from the shell (or a cluster batch script), not from the interactive desktop. Use this pattern:

```bash
matlab -batch "run('./matlab/load_project'); <function_call>"
```

In an interactive session, run `run('./matlab/load_project');` once before calling project functions.

Common examples:

```bash
# Single run config
matlab -batch "run('./matlab/load_project'); run_model('config/run_configs/allrisk_base.yaml')"

# Sensitivity study (response mode)
matlab -batch "run('./matlab/load_project'); run_sensitivity('config/sensitivity_configs/baseline_vaccine_program.yaml', 'response')"

# Sensitivity study (unmitigated losses; see run_unmitigated_losses.sh)
matlab -batch "run('./matlab/load_project'); run_sensitivity('config/sensitivity_configs/no_mitigation_all.yaml', 'unmitigated', 'num_chunks', 20)"
```

Shell wrappers such as `clean_inputs.sh`, `run_unmitigated_losses.sh`, and `slurm/submit_sensitivity_workflow.sh` follow the same `load_project` + function-call pattern.

## Replicating paper results

Follow the below steps to replicate the paper results. Some steps may vary or require adjustment depending on computing setup. All scripts are designed to run as bash scripts from the command line:

```
bash clean_inputs.sh
```


| Order | Script                                                                 | What it does                                                                                                                                                                                                                                                                                                                                                           |
| ----- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1     | `[clean_inputs.sh](clean_inputs.sh)`                                   | Constructs all model inputs. *Note that you may need to update the command for virtual environment activation depending on your operating system.*                                                                                                                                                                                                                     |
| 2     | `[transfer_to_remote.sh](transfer_to_remote.sh)`                       | Pushes large git-ignored inputs to a remote server on which you will run pandemic simulations.                                                                                                                                                                                                                                                                         |
| 3     | `[slurm/replicate_paper_results.sh](slurm/replicate_paper_results.sh)` | Submits the full paper job chain (other than the unmitigated losses scripts). **Ensure that model inputs on the SLURM server are up to date before running. This means making sure any data updates have been synced to the remote both via git and the [`transfer_to_remote.sh](transfer_to_remote.sh) script.** Note that some of these jobs are quite long-running. |
| 4     | `[run_unmitigated_losses.sh](run_unmitigated_losses.sh)`               | Runs `run_sensitivity` in unmitigated mode locally. You can run this locally while `[slurm/replicate_paper_results.sh](slurm/replicate_paper_results.sh)` is running on the remote. Note that you may need to adjust the number of chunks upward to fit the job on your machine's memory.                                                                              |
| 5     | `[transfer_from_remote.sh](transfer_from_remote.sh)`                   | Transfer selected `output/` files from the remote server to your local repo. **Make sure that all jobs on the remote server were completed without error.** (See `[transfer_from_remote.sh](transfer_from_remote.sh)` for notes on this.)                                                                                                                              |
| 6     | `[generate_outputs.sh](generate_outputs.sh)`                           | Generates paper-style tables and figures.                                                                                                                                                                                                                                                                                                                              |


The above pipeline is also self-documenting of the expected run order of the various scripts in our repository.