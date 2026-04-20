#!/usr/bin/env bash

###############################################################################
# clean_inputs.sh
#
# Regenerates model input artifacts (Python, R, MATLAB) for the pandemic model.
#
# Usage:
#   bash clean_inputs.sh
#
# Run from the repository root. Requires:
#   - Python venv at python/.venv (Windows: Scripts/activate; Linux/macOS: bin/activate)
#   - R renv (restored at start) and MATLAB on PATH for -batch steps
#
# Pipeline: Marani clean → COVID severity → filters → distribution fits →
# supplemental cleaners → vaccine/PTRS R scripts → configs → figures and tables.
###############################################################################

set -euo pipefail
step() { # Helper function to print step header
  printf '\n'
  printf '%s\n' '----------------------------------------------------------------'
  printf '  %s\n' "$*"
  printf '%s\n' '----------------------------------------------------------------'
  printf '\n'
}

step 'Initialize environment'
source python/.venv/Scripts/activate
python -c "import kaleido; kaleido.get_chrome_sync()" # Sync Kaleido with Chrome webdriver
Rscript -e "renv::restore();"
LOAD_MATPROJ="run('./matlab/load_project.m');"
LOAD_RENV="renv::activate();"


step 'Clean Marani epidemic sheet'
python ./python/vendor/pandemic-statistics/scripts/clean_marani.py \
  --outdir "./data/derived"


step 'Estimate ``state of nature'' COVID severity and merge into dataset'
python ./python/scripts/clean_covid19_vaccination.py
matlab -batch "${LOAD_MATPROJ}
                find_natural_covid_deaths('./config/run_configs/covid_severity_search.yaml');"
python ./python/scripts/update_covid_severity.py \
  --ds-path "./data/derived/epidemics_241210_clean.csv" \
  --outdir "./data/derived" \
  --covid-severity-file "./data/derived/inverted_covid_severity.yaml"


step 'Filter epidemics'
python ./python/scripts/filter_epidemics_batch.py \
  --input "./data/derived/epidemics_241210_clean_upcov.csv" \
  --data-outdir "./data/derived/epidemics_filtered"


step 'Fit arrival, duration, and economic loss models'
python ./python/scripts/fit_genpareto_batch.py \
  --input-dir "./data/derived/epidemics_filtered" \
  --outdir "./data/clean/arrival_distributions"
python ./python/scripts/fit_duration_dist_batch.py \
  --input-dir "./data/derived/epidemics_filtered" \
  --outdir "./data/clean/duration_distributions" \
  --fig-outdir "./output/duration_dist_figs"
python ./python/scripts/fit_econ_loss_model.py


step 'Clean supplemental inputs'
Rscript -e "${LOAD_RENV}
            source('R/scripts/write_pathogen_info.R');"
python ./python/scripts/clean_madhav_severity_exceedance.py
python ./python/scripts/clean_rd_timeline_and_cost_responses.py
python ./python/scripts/clean_ptrs_responses.py
python ./python/scripts/clean_wastewater_treatment.py
Rscript -e "${LOAD_RENV}
            source('R/scripts/clean_arrival_rate_responses.R');
            source('R/scripts/fit_vaccine_ptrs.R');
            source('R/scripts/fit_vaccine_rd_costs.R');
            source('R/scripts/create_ptrs_table.R');
            source('R/scripts/pred_viral_arrival_risk.R');
            source('R/scripts/write_adv_rd_costing_inputs.R');
            source('R/scripts/write_vaccine_always_succeed.R');
            "


step 'Write pairwise scenario configs and response thresholds'
python ./python/scripts/write_pairwise_configs.py
python ./python/scripts/write_response_thresholds.py


step 'Write input figures'
python ./python/scripts/plot_limited_exceedance_panel.py
python ./python/scripts/print_arrival_distribution_moments.py
python ./python/scripts/write_clean_ds_table.py \
  "./data/derived/epidemics_filtered/e241210c_upcov__filt__all_int_0d01_1900.csv" \
  --measure severity
Rscript -e "${LOAD_RENV}
            source('R/scripts/plot_arrival_shares.R');
            source('R/scripts/plot_ptrs.R');
            source('R/scripts/write_ptrs_pub_table.R');
            "
matlab -batch "${LOAD_MATPROJ}
                plot_h;"

step 'Finished input cleaning pipeline.'
