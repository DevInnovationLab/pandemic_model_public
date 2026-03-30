# Python Components

This directory contains Python preprocessing scripts and the `pandemic_model` package.

## Setup

```bash
cd python
poetry install   # installs all dependencies
```

Activate the environment before running scripts:

```bash
cd python && poetry shell && cd ..   # return to repo root after activating
```

All scripts must be run from the **repository root**, not from `python/`.

## Package: `pandemic_model`

Core statistical utilities used by preprocessing scripts:

| Module | Purpose |
|---|---|
| `stats/bayes.py` | Bayesian inference utilities |
| `stats/mevd.py` | Multivariate extreme value distribution |
| `stats/pareto.py` | Pareto / GPD fitting |
| `stats/reg.py` | Regression utilities |
| `utils.py` | General utilities |
| `constants.py` | Shared constants |

## Submodule: `vendor/pandemic-statistics`

Additional statistical tools pinned to branch `prep-for-integration`. The submodule
is installed as a local editable dependency via Poetry (`develop = true`), so the
working copy in `vendor/pandemic-statistics/` is what gets imported — no separate
git clone in `.venv/`.

To update to a newer commit on the branch:
```bash
cd python/vendor/pandemic-statistics && git pull origin prep-for-integration && cd ../..
# Then re-lock if the package API changed:
cd python && poetry lock && poetry install
```

## Scripts (`scripts/`)

| Script | Purpose |
|---|---|
| `fit_econ_loss_models.py` | Fit economic loss model from historical data |
| `fit_mle_duration.py` | Fit pandemic duration distributions |
| `clean_ptrs.py` | Clean probability-of-technical-success data |
| `clean_rd_timelines_and_cost.py` | Clean R&D timeline and cost data |
| `clean_wastewater_treatment.py` | Clean wastewater treatment data |
| `write_clean_ds_table.py` | Write cleaned disease severity table |
| `create_early_warning_invest_configs.py` | Generate early warning scenario configs |
| `create_pairwise_configs.py` | Generate pairwise program comparison configs |
| `create_response_threshold.py` | Compute response threshold from severity data |
| `update_covid_severity.py` | Update COVID-19 severity estimates |
| `plot_rd_inputs.py` | Plot R&D input data |

## Notebooks (`notebooks/`)

Exploratory development notebooks. Not part of the workflow and not guaranteed
to run without manual setup. See individual notebooks for context.

## Tests

```bash
cd python && poetry run pytest
```
