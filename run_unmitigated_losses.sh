#!/usr/bin/env bash

###############################################################################
# run_unmitigated_losses.sh
#
# Runs the no-mitigation-all sensitivity in unmitigated-loss mode on your local
# machine (single MATLAB process; chunks run sequentially within each scenario).
#
# Usage (from repository root):
#   bash run_unmitigated_losses.sh
#
# Optional environment overrides:
#   NUM_CHUNKS=10 bash run_unmitigated_losses.sh
#   SENS_CONFIG=config/sensitivity_configs/no_mitigation_all_small.yaml bash run_unmitigated_losses.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

NUM_CHUNKS="${NUM_CHUNKS:-20}"
SENS_CONFIG="${SENS_CONFIG:-config/sensitivity_configs/no_mitigation_all.yaml}"
OVERWRITE="${OVERWRITE:-true}"

if [ ! -f "${SENS_CONFIG}" ]; then
  echo "Sensitivity config not found: ${SENS_CONFIG}" >&2
  exit 1
fi

echo "Running unmitigated losses (run_sensitivity, unmitigated)"
echo "  Config: ${SENS_CONFIG}"
echo "  Chunks: ${NUM_CHUNKS}"
echo "  Overwrite: ${OVERWRITE}"
echo ""

matlab -batch "run('./matlab/load_project');
               run_sensitivity('${SENS_CONFIG}', 'unmitigated', 'num_chunks', ${NUM_CHUNKS}, 'overwrite', ${OVERWRITE});"
echo ""
echo "Done. Outputs under output/sensitivity_runs/<run_name>/ (see sensitivity YAML run_name)."
