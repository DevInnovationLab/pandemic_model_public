#!/usr/bin/env bash

###############################################################################
# transfer_from_remote.sh
#
# Pulls selected simulation outputs from the Midway clone of this repo into your
# local working tree (repository root). Intended for results produced by
# slurm/submit_workflow.sh and sensitivity runs matching replicate_paper_results.sh.
#
# Usage (from repository root):
#   bash transfer_from_remote.sh
#   bash transfer_from_remote.sh path/to/extra ...
#   REMOTE_DIR=/other/path bash transfer_from_remote.sh
#
# Options:
#   -d remote_dir   Remote repo root on the cluster (default: see below).
#   -h              Show help and exit.
#
# With no extra arguments, transfers the default path list.
#
# Requires: ssh, GNU tar on the cluster, tar locally.
###############################################################################

set -euo pipefail

DEFAULT_REMOTE_USER="squaade"
DEFAULT_REMOTE_HOST="midway2.rcc.uchicago.edu"
DEFAULT_REMOTE_DIR="/project/rglennerster/pandemic_model"

# Default relative paths (under the remote repo root) to pull into ./<same path>
# Single runs (submit_workflow): processed/ + run_config.yaml per job
# Sensitivity runs: processed/, figures/, config, recurrence tables from compare_exceedances
DEFAULT_PATHS=(
  # Single-run workflows (allrisk_base family)
  "output/single_runs/allrisk_base/processed"
  "output/single_runs/allrisk_base/run_config.yaml"
  "output/single_runs/allrisk_base_pairwise/processed"
  "output/single_runs/allrisk_base_pairwise/run_config.yaml"
  "output/single_runs/allrisk_base_program_levels/processed"
  "output/single_runs/allrisk_base_program_levels/run_config.yaml"
  # Sensitivity batches
  "output/sensitivity_runs/baseline_vaccine_program/baseline"
  "output/sensitivity_runs/baseline_vaccine_program/ptrs_pathogen_gamma1"
  "output/sensitivity_runs/baseline_vaccine_program/processed"
  "output/sensitivity_runs/baseline_vaccine_program/figures"
  "output/sensitivity_runs/baseline_vaccine_program/sensitivity_config.yaml"
  "output/sensitivity_runs/baseline_vaccine_program/mean_annual_recurrence_rates.csv"
  "output/sensitivity_runs/baseline_vaccine_program/mean_annual_recurrence_rates_selected.csv"
  "output/sensitivity_runs/baseline_vaccine_program_airborne/baseline"
  "output/sensitivity_runs/baseline_vaccine_program_airborne/ptrs_pathogen_gamma1"
  "output/sensitivity_runs/baseline_vaccine_program_airborne/processed"
  "output/sensitivity_runs/baseline_vaccine_program_airborne/figures"
  "output/sensitivity_runs/baseline_vaccine_program_airborne/sensitivity_config.yaml"
  "output/sensitivity_runs/baseline_vaccine_program_airborne/mean_annual_recurrence_rates.csv"
  "output/sensitivity_runs/baseline_vaccine_program_airborne/mean_annual_recurrence_rates_selected.csv"
)

usage() {
  echo "Usage: $0 [-d remote_dir] [-h] [extra_rel_path ...]"
  echo
  echo "Pull paths from ${DEFAULT_REMOTE_USER}@${DEFAULT_REMOTE_HOST}:\${REMOTE_DIR}/"
  echo "into the current repo (defaults listed in script header)."
  echo
  echo "  -d remote_dir   Override remote repo root (default: ${DEFAULT_REMOTE_DIR})"
  echo "  -h               This help"
  echo
  echo "  SKIP_CONFIRM=1    Do not wait for Enter after the pre-flight note"
  echo "  TAR_CHECKPOINT=N  Records between GNU tar checkpoint dots (default: 8192)"
  exit "${1:-1}"
}

REMOTE_DIR="${DEFAULT_REMOTE_DIR}"

while getopts ":d:h" opt; do
  case ${opt} in
    d) REMOTE_DIR="$OPTARG" ;;
    h) usage 0 ;;
    \?) usage 1 ;;
  esac
done
shift $((OPTIND - 1))

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

REMOTE_BASE="${DEFAULT_REMOTE_USER}@${DEFAULT_REMOTE_HOST}:${REMOTE_DIR}"

if [ "$#" -ge 1 ]; then
  PATHS=("$@")
else
  PATHS=("${DEFAULT_PATHS[@]}")
fi

print_preflight_note() {
  cat <<'EOF'

================================================================================
  Before you pull: confirm cluster jobs have FINISHED
================================================================================

  If jobs are still running, files may be incomplete or missing.

  To check the status of your jobs, run the following on your SLURM cluster:

    squeue -u $USER

  After nothing is left in squeue, confirm jobs finished successfully (not FAILED
  or CANCELLED) using the accounting log:

    sacct -u $USER --starttime=today --format=JobID,JobName,State,ExitCode,Elapsed,End

  Cancel now with Ctrl+C if you are not ready.

================================================================================
EOF
}

print_preflight_note

if [ -t 0 ] && [ "${SKIP_CONFIRM:-0}" != "1" ]; then
  read -r -p "Press Enter to start the transfer, or Ctrl+C to cancel. "
  echo ""
fi

echo "Remote: ${REMOTE_BASE}/"
echo "Local:  $(pwd)/"
echo ""
echo "Paths (${#PATHS[@]} items):"
for rel in "${PATHS[@]}"; do
  echo "  <- ${rel}"
done
echo ""
REMOTE_DIR_Q=$(printf '%q' "${REMOTE_DIR}")
PATHS_Q=$(printf '%q ' "${PATHS[@]}")
TAR_CHECKPOINT="${TAR_CHECKPOINT:-8192}"

ssh "${DEFAULT_REMOTE_USER}@${DEFAULT_REMOTE_HOST}" \
  "cd ${REMOTE_DIR_Q} && tar --checkpoint=${TAR_CHECKPOINT} --checkpoint-action=dot -czf - ${PATHS_Q}" \
  | tar xzf - -C "${SCRIPT_DIR}"

echo ""
echo "Transfer complete."
