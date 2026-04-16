#!/bin/bash
# Usage: ./submit_full_workflow.sh <run_config> <num_chunks> [n_bootstrap]


set -euo pipefail

JOB_CONFIG=$1
NUM_CHUNKS=$2
N_BOOTSTRAP=${3:-1000}
BOOT_WORKERS=${4:-2}
CONFIG_NAME=$(basename "${JOB_CONFIG}" .yaml)
REPO_ROOT=$(git rev-parse --show-toplevel)

if [ ! -f "${JOB_CONFIG}" ]; then
  echo "Job config not found: ${JOB_CONFIG}" >&2
  exit 1
fi

echo "Submitting workflow for ${JOB_CONFIG}"
echo "  Chunks: ${NUM_CHUNKS}"
echo "  Bootstrap samples: ${N_BOOTSTRAP}"

# Clear job outdir before submitting so array order does not matter (matches run_job.m path)
OUTDIR=$(awk '
  /^[[:space:]]*outdir[[:space:]]*:/ {
    line = $0
    sub(/^[[:space:]]*outdir[[:space:]]*:[[:space:]]*/, "", line)
    sub(/[[:space:]]*#.*/, "", line)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
    gsub(/^["'"'"']|["'"'"']$/, "", line)
    print line
    exit
  }
' "${JOB_CONFIG}")
if [ -z "${OUTDIR}" ]; then
  echo "Could not parse outdir from ${JOB_CONFIG}" >&2
  exit 1
fi

if [[ "${OUTDIR}" = /* ]]; then
  OUTDIR_ABS="${OUTDIR}"
else
  OUTDIR_CLEAN="${OUTDIR#./}"
  OUTDIR_ABS="${REPO_ROOT}/${OUTDIR_CLEAN}"
fi

JOB_OUTDIR="${OUTDIR_ABS}/${CONFIG_NAME}"
if [ -d "$JOB_OUTDIR" ]; then
  echo "Removing existing job outdir: ${JOB_OUTDIR}"
  rm -rf "$JOB_OUTDIR"
fi

# Submit array job
JOB_NAME=${CONFIG_NAME}_model_run
ARRAY_JOB=$(sbatch --parsable --array=1-${NUM_CHUNKS} \
            --job-name=${JOB_NAME} \
            --export=ALL,JOB_CONFIG=${JOB_CONFIG},NUM_CHUNKS=${NUM_CHUNKS} \
            slurm/submit_model_run.sbatch)
echo "Array job submitted: ${ARRAY_JOB}"

# Submit aggregation (depends on array job)
JOB_NAME=${CONFIG_NAME}_agg_relative_sums
AGG_JOB=$(sbatch --parsable --dependency=afterok:${ARRAY_JOB} \
          --job-name=${JOB_NAME} \
          slurm/slurm_agg_relative_sums.sbatch ${JOB_CONFIG})
echo "Aggregation job submitted: ${AGG_JOB}"

# Submit bootstrap (depends on aggregation)
JOB_NAME=${CONFIG_NAME}_bootstrap
BOOT_JOB=$(sbatch --parsable --dependency=afterok:${AGG_JOB} \
           --job-name=${JOB_NAME} --cpus-per-task=${BOOT_WORKERS} \
           --export=ALL,BOOT_WORKERS=${BOOT_WORKERS} \
           slurm/submit_bootstrap.sbatch ${JOB_CONFIG} ${N_BOOTSTRAP} ${BOOT_WORKERS})
echo "Bootstrap job submitted: ${BOOT_JOB}"

echo ""
echo "Workflow submitted successfully!"
echo "Monitor with: watch -n 5 squeue -u \$USER"
