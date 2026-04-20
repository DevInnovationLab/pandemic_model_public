#!/usr/bin/env bash

###############################################################################
# replicate_paper_results.sh
#
# Submits the SLURM jobs used to generate paper results.
#
# Usage (from repository root):
#   bash slurm/replicate_paper_results.sh
#
#   SKIP_CONFIRM=1    Skip the pre-flight Enter prompt (non-interactive / CI).
#
# Before you run (on the machine where you submit, e.g. cluster login):
#   - Repository up to date: git pull in this checkout (code and configs).
#   - Input data current: large paths under data/clean/ (e.g. arrival and duration
#     distributions) synced to this host — often transfer_to_remote.sh from your
#     machine. This script does not run git or transfers.
#
# Job order:
#   1–3  Full workflows (10 chunks each): allrisk_base, pairwise, program_levels
#   4–5  simulation_at_pct for allrisk_base baseline @ 10th and 90th percentiles (submitted
#        after all three workflows; still depends only on allrisk_base bootstrap completing)
#   6–7  Sensitivity batches (10 chunks each): airborne, baseline vaccine program
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

print_preflight_note() {
  cat <<'EOF'

================================================================================
Before you submit: Confirm that repo and data inputs on this host are up to date.
================================================================================

    1. Update committed code and configs:

         git pull

    2. Sync large data inputs not tracked by git:
    
        bash transfer_to_remote.sh (run on your local machine)

    3. Install the defined submodules:
    
        git submodule update --init --recursive
        (You may need to add the --force flag)

  This script does not run git or transfers. Cancel with Ctrl+C if you are not ready.

================================================================================
EOF
}

print_preflight_note

if [ -t 0 ] && [ "${SKIP_CONFIRM:-0}" != "1" ]; then
  read -r -p "Press Enter if the repo and input data on this host are up to date, or Ctrl+C to cancel. "
  echo ""
fi

NUM_CHUNKS="${NUM_CHUNKS:-10}"

echo "Repository root: ${REPO_ROOT}"
echo "Chunks per workflow / sensitivity: ${NUM_CHUNKS}"
echo ""

submit_workflow() {
  local config_path="$1"
  local label="$2"
  echo "================================================================"
  echo "  Workflow: ${label}"
  echo "  Config:   ${config_path}"
  echo "================================================================"
  bash slurm/submit_workflow.sh "${config_path}" "${NUM_CHUNKS}"
  echo ""
}

echo "================================================================"
echo "  Workflow: allrisk_base (capture bootstrap id for simulation_at_pct)"
echo "================================================================"
ALLRISK_OUT="$(bash slurm/submit_workflow.sh "config/run_configs/allrisk_base.yaml" "${NUM_CHUNKS}" 2>&1)"
echo "${ALLRISK_OUT}"
echo ""
ALLRISK_BOOT="$(echo "${ALLRISK_OUT}" | grep 'Bootstrap job submitted:' | tail -1 | awk '{print $NF}')"
if [ -z "${ALLRISK_BOOT}" ]; then
  echo "ERROR: Could not parse bootstrap job ID from submit_workflow.sh output." >&2
  exit 1
fi

submit_workflow "config/run_configs/allrisk_base_pairwise.yaml" "allrisk_base_pairwise"
submit_workflow "config/run_configs/allrisk_base_program_levels.yaml" "allrisk_base_program_levels"

echo "================================================================"
echo "  simulation_at_pct: allrisk_base baseline @ 10th & 90th percentile"
echo "      (after bootstrap job ${ALLRISK_BOOT} only)"
echo "================================================================"
SIM_PCT_10_JOB="$(
  sbatch --parsable \
    --dependency="afterok:${ALLRISK_BOOT}" \
    --job-name=sim_at_pct_p10 \
    slurm/simulation_at_pct.sbatch \
    output/single_runs/allrisk_base \
    baseline \
    10
)"
echo "Submitted: ${SIM_PCT_10_JOB}"
SIM_PCT_90_JOB="$(
  sbatch --parsable \
    --dependency="afterok:${ALLRISK_BOOT}" \
    --job-name=sim_at_pct_p90 \
    slurm/simulation_at_pct.sbatch \
    output/single_runs/allrisk_base \
    baseline \
    90
)"
echo "Submitted: ${SIM_PCT_90_JOB}"
echo ""

echo "================================================================"
echo "  Airborne sensitivity (baseline_vaccine_program_airborne)"
echo "================================================================"
AIRBORNE_SENS_JOB="$(
  sbatch --parsable \
    --job-name=airborne_baseline_sens \
    slurm/submit_airborne_sensitivity.sbatch "${NUM_CHUNKS}"
)"
echo "Submitted: ${AIRBORNE_SENS_JOB}"
echo ""

echo "================================================================"
echo "  Baseline sensitivity (baseline_vaccine_program)"
echo "================================================================"
BASELINE_SENS_JOB="$(
  sbatch --parsable \
    --job-name=baseline_vaccine_sens \
    slurm/submit_baseline_sensitivity.sbatch "${NUM_CHUNKS}"
)"
echo "Submitted: ${BASELINE_SENS_JOB}"
echo ""

echo "All jobs submitted."
echo "  allrisk_base bootstrap:      ${ALLRISK_BOOT}"
echo "  simulation_at_pct p10:       ${SIM_PCT_10_JOB}  (after ${ALLRISK_BOOT})"
echo "  simulation_at_pct p90:       ${SIM_PCT_90_JOB}  (after ${ALLRISK_BOOT})"
echo "  Airborne sensitivity:        ${AIRBORNE_SENS_JOB}"
echo "  Baseline sensitivity:        ${BASELINE_SENS_JOB}"
echo "Monitor:  squeue -u \$USER"
