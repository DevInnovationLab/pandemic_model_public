#!/usr/bin/env bash

###############################################################################
# generate_outputs.sh
#
# Generates paper-style tables and figures from completed simulation outputs. Intended
# to run locally after:
#   - no_mitigation_all unmitigated losses have been run (e.g. run_unmitigated_losses.sh), and
#   - cluster results have been pulled (e.g. transfer_from_remote.sh) for single runs
#     and baseline_vaccine_program sensitivity.
#
# Usage (from repository root):
#   bash generate_outputs.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

DIR_NO_MIT="${DIR_NO_MIT:-output/sensitivity_runs/no_mitigation_all}"
DIR_NO_MIT_BASELINE="${DIR_NO_MIT_BASELINE:-${DIR_NO_MIT}/baseline}"
DIR_BASELINE_VACCINE_SENS="${DIR_BASELINE_VACCINE_SENS:-output/sensitivity_runs/baseline_vaccine_program}"
DIR_BASELINE_VACCINE_SENS_AIRBORNE="${DIR_BASELINE_VACCINE_SENS_AIRBORNE:-output/sensitivity_runs/baseline_vaccine_program_airborne}"
DIR_ALLRISK="${DIR_ALLRISK:-output/single_runs/allrisk_base}"
DIR_PAIRWISE="${DIR_PAIRWISE:-output/single_runs/allrisk_base_pairwise}"
DIR_PROGRAM_LEVELS="${DIR_PROGRAM_LEVELS:-output/single_runs/allrisk_base_program_levels}"

step() {
  printf '\n'
  printf '%s\n' '----------------------------------------------------------------'
  printf '  %s\n' "$*"
  printf '%s\n' '----------------------------------------------------------------'
  printf '\n'
}

require_dir() {
  if [ ! -d "$1" ]; then
    echo "ERROR: Missing directory: $1" >&2
    exit 1
  fi
}

step 'Checking expected input directories'
require_dir "${DIR_NO_MIT}"
require_dir "${DIR_NO_MIT_BASELINE}"
require_dir "${DIR_BASELINE_VACCINE_SENS}"
require_dir "${DIR_BASELINE_VACCINE_SENS_AIRBORNE}"
require_dir "${DIR_ALLRISK}"
require_dir "${DIR_PAIRWISE}"
require_dir "${DIR_PROGRAM_LEVELS}"

if [ ! -f "${DIR_NO_MIT_BASELINE}/unmitigated_losses.mat" ]; then
  echo "ERROR: Expected ${DIR_NO_MIT_BASELINE}/unmitigated_losses.mat (run unmitigated losses first)." >&2
  exit 1
fi

step 'Running MATLAB table and figure writers'
matlab -batch "run('./matlab/load_project.m'); 
               plot_losses_lorenz('${DIR_NO_MIT_BASELINE}'); 
               write_unmitigated_loss_figures('${DIR_NO_MIT}')
               write_status_quo_sensitivity_table('${DIR_BASELINE_VACCINE_SENS}');
               write_invest_scenario_table('${DIR_ALLRISK}');
               plot_net_value_boxplot('${DIR_ALLRISK}');
               plot_pairwise_program_matrix('${DIR_PAIRWISE}');
               write_program_levels_invest_table('${DIR_PROGRAM_LEVELS}');
               compare_exceedances('${DIR_BASELINE_VACCINE_SENS}', 'simulations_only');
               compare_exceedances('${DIR_BASELINE_VACCINE_SENS_AIRBORNE}', 'baseline_madhav');"

step 'Finished generate_outputs.sh'
