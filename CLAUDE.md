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
- `vax_mitigation_factor.m`: Piecewise linear vaccination damage mitigation function (IMF paper footnote 17)
- `+sim_indexing/`: Package for efficient indexing of simulation results
- `helpers/`: Utility functions — config validation, data loading, capacity calculations

**MATLAB Scripts** (`matlab/scripts/`):
- `workflow/`: `run_job`, `run_workflow`, `run_sensitivity`, `aggregate_results`, `bootstrap_sums`, `estimate_unmitigated_losses`, `expand_sensitivities`
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

**Job Configs** (`config/job_configs/`): Specify run-wide settings
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
matlab -batch "run('./matlab/load_project'); run_job('config/job_configs/airborne_base.yaml')"
```

**Full Workflow**:
```bash
matlab -batch "run('./matlab/load_project'); run_workflow('config/job_configs/airborne_base.yaml')"
```

**MATLAB Tests**:
```bash
matlab -batch "run('./matlab/load_project'); runtests('matlab/tests')"
```

### SLURM (HPC Cluster)

**Submit Model Run**:
```bash
sbatch --array=1-10 --export=JOB_CONFIG=config/job_configs/airborne_base.yaml,NUM_CHUNKS=10 slurm/submit_model_run.sbatch
```

**Submit Full Workflow**:
```bash
./slurm/submit_workflow.sh config/job_configs/airborne_base.yaml
```

## Key File Paths

All scripts should be run from the repository root. The model expects:
- Arrival distributions: `output/arrival_distributions/`
- Duration distributions: `output/duration_distributions/`
- Economic loss models: `output/econ_loss_models/`
- PTRS tables: `output/ptrs/`
- R&D timelines: `output/rd_timelines/`
- Response thresholds: `output/response_threshold_half_covid_severity.yaml`

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
cd python && poetry run python scripts/fit_arrival_distributions.py && cd ..

# 4. Run other input-preparation scripts as needed (see python/scripts/)

# 5. Submit the full simulation workflow (HPC)
./slurm/submit_workflow.sh config/job_configs/airborne_base.yaml <num_chunks>
```

Note: `submit_workflow.sh` automatically re-runs step 3 before submitting SLURM jobs.

## Important Notes

- Python virtual environment must be activated before running Python scripts
- All scripts (MATLAB, Python) should be executed from the repository root directory
- MATLAB GUI is needed for running tests interactively
- Output files are written to `output/` directory with timestamped subdirectories
- The model supports parallel execution via SLURM job arrays for large simulation runs
- Sensitivity analyses use separate configuration files that extend base job configs
