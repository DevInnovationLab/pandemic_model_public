# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a pandemic modeling framework that simulates pandemic preparedness investments and their economic impacts. The model evaluates interventions like advance manufacturing capacity, vaccine R&D, and enhanced surveillance systems through Monte Carlo simulation.

## Architecture

### Multi-Language Stack
The project uses four primary languages with distinct roles:
- **MATLAB**: Core simulation engine and analysis (primary language)
- **Python**: Statistical modeling, data preprocessing, and complementary analysis
- **R**: Input data preparation, vaccine probability-of-technical-success (PTRS) modeling, and R&D timeline fitting
- **SBATCH**: HPC job submission scripts for running model arrays on SLURM clusters.

### Core Simulation Flow
1. **Input Generation**: R/Python scripts prepare arrival distributions, duration distributions, economic loss models, and vaccine development parameters
2. **Base Simulation Table**: `get_base_simulation_table.m` generates pandemic events by sampling from arrival and duration distributions
3. **Scenario Simulation Table**: `get_scenario_simulation_table.m` applies intervention-specific logic (surveillance, advance R&D, etc.)
4. **Event List Simulation**: `event_list_simulation.m` processes each pandemic event, calculating capacity dynamics, costs, and benefits
5. **Aggregation & Analysis**: Results are aggregated across simulations and analyzed through bootstrapping and sensitivity analysis

### Key Components

**MATLAB Core** (`matlab/pandemic_model/`):
- `event_list_simulation.m`: Main simulation loop that processes pandemic events and calculates outcomes
- `get_base_simulation_table.m`: Generates base pandemic event table from distributions
- `get_scenario_simulation_table.m`: Applies scenario-specific interventions (R&D, surveillance, etc.)
- `h_function.m`: Piecewise linear vaccination damage mitigation function (IMF paper footnote 17)
- `+sim_indexing/`: Package for efficient indexing of simulation results
- `helpers/`: Utility functions — config validation, data loading, capacity calculations

**MATLAB Scripts** (`matlab/scripts/`):
- `workflow/`: `run_model`, `run_workflow`, `run_sensitivity`, `aggregate_results`, `bootstrap_sums`, `estimate_unmitigated_losses`, `expand_sensitivities`
- `analysis/`: `build_sensitivity_loss_tables`, `get_*`, `check_*`, `compare_*`, `agg_sensitivity_benefits`
- `figures/`: `plot_*`, `write_*` (table and figure outputs), diagnostic plots
- `deprecated/`: Superseded scripts (do not use)

**Python Components** (`python/`):
- `pandemic_model/stats/`: Statistical utilities (multivariate EVD, Pareto distributions, Bayesian inference)
- `scripts/`: Data cleaning and preprocessing (PTRS, R&D timelines, economic loss models)
- `vendor/pandemic-statistics`: Git submodule for shared statistical tools

**R Components** (`R/scripts/`):
- Vaccine PTRS and timeline fitting (`fit_vaccine_ptrs_and_timeline.R`)
- R&D cost and outcome modeling (`fit_vaccine_rd_costs.R`, `get_expected_rd_outcomes.R`)
- Pathogen arrival risk prediction (`pred_viral_arrival_risk.R`)
- Input data preparation (`write_adv_rd_inputs.R`, `write_pathogen_info.R`)

### Configuration System

The model uses a three-tier YAML configuration system. See `config/README.md` for
the full field reference and runtime composition semantics.

**Job Configs** (`config/run_configs/`): Specify run-wide settings
**Scenario Configs** (`config/scenario_configs/`): Intervention-specific parameters
**Sensitivity Configs** (`config/sensitivity_configs/`): Parameter sweep definitions

## Development Commands

### Python Setup
```bash
cd python
poetry install              # Install dependencies
poetry shell                # Activate environment
cd ..                       # Return to root (Python scripts run from root)
```

### MATLAB Execution

**Local model run**:
```bash
matlab -batch "run('./matlab/load_project'); run_model('config/run_configs/airborne_base.yaml')"
```

**Full Workflow**:
```bash
matlab -batch "run('./matlab/load_project'); run_workflow('config/run_configs/airborne_base.yaml')"
```

**MATLAB Tests**:
```bash
matlab -batch "run('./matlab/load_project'); runtests('matlab/tests')"
```

### SLURM (HPC Cluster)

**Submit Model Run**:
```bash
sbatch --array=1-10 --export=JOB_CONFIG=config/run_configs/airborne_base.yaml,NUM_CHUNKS=10 slurm/submit_model_run.sbatch
```

**Submit Full Workflow**:
```bash
./slurm/submit_workflow.sh config/run_configs/airborne_base.yaml
```

## Data directories (clean vs derived)

Run all prep CLIs with **current working directory = repository root** (`poetry --directory python run python …` from the repo root).

| Location | Purpose |
|----------|---------|
| `data/raw/` | Source downloads and immutable inputs (not read directly by simulation YAML). |
| `data/clean/` | Curated tables intended as **model inputs** (e.g. Marani-cleaned epidemic sheet, YAML such as `inverted_covid_severity.yaml`, arrival response tables). |
| `data/derived/` | Pipeline outputs that are **not** final model inputs—e.g. filtered epidemic CSVs, COVID-adjusted copies, and R/Python prep intermediates (cleaned arrival-rate survey tables, marginal PTRS and R&D cost predictions, survey response extracts). |

**Epidemics pipeline:** `clean_marani.py` reads `data/raw/` (e.g. `epidemics_241210.xlsx`) and writes `data/clean/` (e.g. `epidemics_241210_clean.csv`). `filter_epidemics_batch.py` reads that clean CSV and writes filtered `{lineage}__filt__{filter_slug}.csv` under `data/derived/epidemics_filtered/` (and Sankey PDFs under `output/epidemics_filter_figures/`). Stem grammar (lineage, filter slug, GPD/duration segments) is documented in `docs/naming_convention.md`.

| Stage | Writer | Primary outputs |
|-------|--------|-----------------|
| Raw → clean sheet | `clean_marani.py` | `data/clean/epidemics_*_clean.csv` |
| Clean → filtered | `filter_epidemics_batch.py` | `data/derived/epidemics_filtered/{lineage}__filt__{filter_slug}.csv`, `output/epidemics_filter_figures/*.pdf` |
| GPD fits (optional) | `fit_genpareto_batch.py` | `data/clean/arrival_distributions/` (lineage encodes `*_clean_upcov` inputs, e.g. `e241210c_upcov__filt__...`) |
| Duration fits (optional) | `fit_duration_dist_batch.py` | `data/clean/duration_distributions/` (CSVs), `output/duration_dist_figs/` (PMF PDFs for 50k runs) |

Do not commit large generated files under `vendor/`; keep artifacts under `data/` and `output/` as appropriate.

**Migration:** If you previously used a symlink or `data/epidemics_filtered/` under a different name, move filtered CSVs to `data/derived/epidemics_filtered/` (and COVID-adjusted outputs to `data/derived/epidemics_filtered/modified/`) and update any local scripts that still point at `data/epidemics_ds/`.

## Key File Paths

All scripts should be run from the repository root. The model expects:
- Arrival distributions (GPD): `data/clean/arrival_distributions/`; directory stem `{lineage}__filt__{filter_slug}__arr__gpd_{fit}_{arrival}_{trunc}_u{U}_n{n}_s{seed}` (see `docs/naming_convention.md`). COVID severity revision is encoded in lineage (e.g. `e241210c_upcov`), not in an extra folder tier.
- Duration distributions: `data/clean/duration_distributions/`; filename stem `{lineage}__filt__{filter_slug}__dur__trunc{T}_n{n}_s{seed}.csv` (helpers in `pandemic_model.pipeline_names`).
- Economic loss model (Poisson GLM on severity): `data/clean/econ_loss_model_sev_poisson.yaml`; curated rows `data/clean/econ_loss_model_sev_poisson.csv`; diagnostic PDF and LaTeX under `output/econ_loss_model_sev_poisson.*`
- PTRS tables: `output/ptrs/`
- R&D timelines: `output/rd_timelines/`
- Response thresholds: `output/response_thresholds/response_threshold_half_covid_severity.yaml`
- Filtered epidemic tables (from `filter_epidemics`): `data/derived/epidemics_filtered/`
- Sankey figures from filter batch: `output/epidemics_filter_figures/`

## MATLAB Project Setup

The repository uses a MATLAB project file (`Pandemic_model.prj`). Always load the project before running scripts:
```matlab
run('./matlab/load_project')
```
This ensures all paths are correctly set.

## Dependencies

**Python**: Managed via Poetry (`python/pyproject.toml`)
- Core: pandas, numpy, scipy, scikit-learn
- Stats: statsmodels, numdifftools, numba
- Optimization: jax, optax
- Visualization: seaborn, plotly
- Submodule: pandemic-statistics (from GitHub)

**MATLAB**:
- YAML read/write functions from [MartinKoch123/yaml](https://github.com/MartinKoch123/yaml)
- Registered as a git submodule at `matlab/yaml/` — fetched via `git submodule update --init --recursive`

**R**: Managed via renv (`renv.lock`)

## Git Submodules

The repository uses the `pandemic-statistics` submodule (tracked on `main`):
```bash
git submodule update --init --recursive
```

To update to the latest `pandemic-statistics` release:
```bash
git submodule update --remote python/vendor/pandemic-statistics
```

## Reproducing Results from Clean Checkout

```bash
# 1. Clone and initialise submodules
git clone --recurse-submodules <repo-url>

# 2. Install Python dependencies
cd python && poetry install && cd ..

# 3. Fit arrival distributions (prerequisite for the simulation)
poetry --directory python run python scripts/fit_arrival_distributions.py

# 4. Run other input-preparation scripts as needed (see python/scripts/)

# 5. Submit the full simulation workflow (HPC)
./slurm/submit_workflow.sh config/run_configs/airborne_base.yaml <num_chunks>
```

Note: `submit_workflow.sh` automatically re-runs step 3 before submitting SLURM jobs.

## Important Notes

- Python virtual environment must be activated before running Python scripts
- All scripts (MATLAB, Python) should be executed from the repository root directory
- MATLAB GUI is needed for running tests interactively
- Output files are written to `output/` directory with timestamped subdirectories
- The model supports parallel execution via SLURM job arrays for large simulation runs
- Sensitivity analyses use separate configuration files that extend base job configs
