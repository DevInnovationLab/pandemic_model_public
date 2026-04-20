# Pandemic preparedness model

This repository contains the code behind [Estimating future pandemic harms and the gains from preparedness investments]() by Christopher Snyder *et al.* (unpublished).

## Repository structure


| Folder                           | Role                                                         |
| -------------------------------- | ------------------------------------------------------------ |
| `[config/](config/)`             | Configs for model runs (see explanation below) |
| `[data/raw/](data/raw/)`         | Raw data that will be manipulated into model inputs |
| `[data/derived/](data/derived/)` | Data cleaning intermediates — not final model inputs |
| `[data/clean/](data/clean/)`     | Data used as inputs into the pandemic simulation models. |
| `[matlab/](matlab/)`             | MATLAB code (mostly pandemic simulations and postprocessing) |
| `[python/](python/)`             | Python code (mostly input generation) |
| `[R/](R/)`                       | R code (mostly input generation) |
| `[slurm/](slurm/)`               | SLURM batch files and wrappers for cluster workflows |
| `[output/](output/)`             | Ouputs from pandemic simulations |


## Requirements


| Language | Version                             | Manager |
| -------- | ----------------------------------- | ---------------------------------------------------------  |
| MATLAB   | R2020a+ (e.g. R2023a on RCC Midway) | —       |
| Python   | 3.11.9                              | [Poetry](https://python-poetry.org/) |
| R        | —                                   | [renv](https://rstudio.github.io/renv/articles/renv.html) |


**MATLAB toolboxes:** Statistics and Machine Learning Toolbox (required). Parallel Computing Toolbox is optional.

## Installation

### 1. Submodules

We install two git submodules to obtain their helper functions: [yaml](https://github.com/MartinKoch123/yaml), a YAML parser for MATLAB, and [pandemic-statistics](https://github.com/ganqili/pandemic-statistics), a companion repository that contains reusable scripts for our pandemic risk modeling pipeline.

```bash
git submodule update --init --recursive
```

### 2. Python

We use [Poetry](https://python-poetry.org/) for Python package and dependency manangement.

To install the package and virtual environment:

```bash
poetry --directory python install
```

To initialize the Python virtual environment, use the command returned by

```bash
poetry --directory python env activate
```

### 3. R

We use [renv](https://rstudio.github.io/renv/articles/renv.html)

To install the virtual environment:

```bash
Rscript -e "renv::restore()"
```

## Model configuration

The pandemic simulation model composes **three YAML layers** at runtime:

1. **Run configs** (`[config/run_configs/](config/run_configs/)`) — Run-wide settings: simulations, horizons, paths to inputs, `outdir`, etc.
2. **Scenario configs** (`[config/scenario_configs/](config/scenario_configs/)`) — Intervention parameters (referenced by job configs).
3. **Sensitivity configs** (`[config/sensitivity_configs/](config/sensitivity_configs/)`) — Parameter sweeps for `run_sensitivity` (baseline job config plus variants).

## MATLAB from the command line

Always load the project first so paths and packages resolve:

```matlab
run('./matlab/load_project');
```

In batch mode, prefix any script or function call with that line, for example:

```bash
matlab -batch "run('./matlab/load_project'); run_model('config/run_configs/<your_run_config>.yaml')"
```

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
| 5     | `[transfer_from_remote.sh](transfer_from_remote.sh)`                   | Transfer selected `output/` files from the remote server to your local repo. **Make sure that all jobs on the remote server were completed without error. (See `[transfer_from_remote.sh](transfer_from_remote.sh)` for notes on this.)                                                                                                                                |
| 6     | `[generate_outputs.sh](generate_outputs.sh)`                           | Generates paper-style tables and figures.                                                                                                                                                                                                                                                                                                                              |


The above pipeline is also self-documenting of the expected run order of the various scripts in our repository.