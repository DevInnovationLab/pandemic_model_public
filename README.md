# Pandemic Model

A pandemic preparedness modeling framework that evaluates investments in advance
manufacturing capacity, vaccine R&D, and enhanced surveillance through Monte Carlo
simulation of pandemic events and their economic impacts.

## Requirements

| Language | Version | Manager |
|---|---|---|
| MATLAB | R2020a+ | — |
| Python | 3.11.9 | Poetry |
| R | — | renv |

**MATLAB toolboxes required**: Statistics and Machine Learning Toolbox.
Parallel Computing Toolbox is optional (used if `bootstrap_parallel: true`).

---

## Installation

### 1. Clone and initialize submodules

```bash
git clone <repo-url>
cd pandemic_model
git submodule update --init --recursive
```

### 2. Verify submodules initialized

`git submodule update --init --recursive` (from step 1) fetches both
`python/vendor/pandemic-statistics` and `matlab/yaml`.

### 3. Python environment

```bash
cd python
poetry install   # installs all dependencies including pandemic-statistics
cd ..
```

Activate the environment before running any Python script:

```bash
cd python && poetry shell && cd ..
```

### 4. R environment

```bash
Rscript -e "renv::restore()"
```

---

## Data layout

Input and derived tables live under `data/raw/`, `data/clean/`, and `data/derived/` (see **Data directories** in [`CLAUDE.md`](CLAUDE.md)).

## Running the Model

All commands are run from the **repository root**.

### Full workflow (local)

```bash
matlab -batch "run('./matlab/load_project'); run_workflow('config/run_configs/allrisk_base.yaml')"
```

### Single job (local)

```bash
matlab -batch "run('./matlab/load_project'); run_model('config/run_configs/allrisk_base.yaml')"
```

### Sensitivity analysis

```bash
matlab -batch "run('./matlab/load_project'); run_sensitivity('config/sensitivity_runs_configs/no_mitigation_all.yaml', 'unmitigated')"
```

### HPC cluster (SLURM)

```bash
# Full workflow (submits array + aggregation jobs automatically)
./slurm/submit_workflow.sh config/run_configs/allrisk_base.yaml

# Manual array submission
sbatch --array=1-10 \
  --export=JOB_CONFIG=config/run_configs/allrisk_base.yaml,NUM_CHUNKS=10 \
  slurm/submit_model_run.sbatch
```

---

## Running Tests

### MATLAB tests

```bash
matlab -batch "run('./matlab/load_project'); results = runtests('matlab/tests'); disp(results)"
```

Individual test:
```bash
matlab -batch "run('./matlab/load_project'); runtests('matlab/tests/test_h.m')"
```

### Regression test

Requires reference outputs to be generated first — see `tests/reference/README.md`.

```bash
matlab -batch "run('./matlab/load_project'); runtests('matlab/tests/run_regression_test.m')"
```

### Python tests

```bash
cd python && poetry run pytest
```

---

## Configuration

The model uses a three-tier YAML configuration system. See `config/README.md` for
the full field reference, schema documentation, and sensitivity config semantics.

---

## Repository Layout

```
config/
  run_configs/        # Simulation run parameters
  scenario_configs/   # Per-intervention parameters
  sensitivity_configs/ # Parameter sweep definitions
data/
  clean/              # Preprocessed input data
  raw/                # Raw source data
matlab/
  load_project.m      # Entry point — run this first
  pandemic_model/     # Core simulation engine
    helpers/          # Utility functions (config validation, data loading)
    +sim_indexing/    # Simulation indexing package
    econ_loss/        # EconLossModel class
  scripts/
    workflow/         # run_model, run_workflow, run_sensitivity, aggregate_*, bootstrap_*
    analysis/         # get_*, check_*, compare_*, build_sensitivity_loss_tables
    figures/          # plot_*, write_* (tables and figures)
    deprecated/       # Superseded scripts (do not use)
    clean_data/       # Data cleaning utilities
  tests/              # MATLAB test suite
  notebooks/          # Exploratory development notebooks (not part of workflow)
python/
  pandemic_model/     # Core Python package (stats, utils)
  scripts/            # Data preprocessing and config generation
  vendor/             # pandemic-statistics submodule
  notebooks/          # Exploratory development notebooks (not part of workflow)
R/
  scripts/            # Input data preparation and PTRS/timeline fitting
slurm/               # SLURM batch scripts for HPC
tests/
  reference/          # Committed reference outputs for regression testing
output/              # Generated outputs (gitignored)
```

---

## Input Data Pipeline

Before running the main simulation, generate required inputs:

1. **R scripts** (`R/scripts/`) — fit PTRS, R&D timelines, arrival risk
2. **Python scripts** (`python/scripts/`) — fit economic loss models, clean data,
   generate scenario configs
3. **MATLAB** — all inputs are read from `output/` at runtime

See `R/scripts/README.md` for R script execution order.

---

## Output Structure

`run_workflow` writes to `{outdir}/{run_config_name}/`:

```
run_config.yaml
raw/chunk_{i}/          # Per-chunk .mat files (base table, sums, pandemic table)
processed/              # Aggregated: baseline_annual_sums.mat, {scenario}_relative_sums.mat
figures/                # Saved plots
```

`run_sensitivity` (unmitigated) writes per-variant directories to
`{sensitivity_outdir}/{run_name}/{variant}/`.
