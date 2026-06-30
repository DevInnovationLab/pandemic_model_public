#!/usr/bin/env bash
# Submit sensitivity run: clear run root, freeze inputs, write manifest, chunk array, aggregate.
#
# Usage (from repository root):
#   bash slurm/submit_sensitivity_workflow.sh <sensitivity_config.yaml> <num_chunks> [run_type]
#
# run_type defaults to response. Pass unmitigated for unmitigated sensitivity runs.
#
# Example:
#   bash slurm/submit_sensitivity_workflow.sh config/sensitivity_configs/baseline_vaccine_program.yaml 10

set -euo pipefail

JOB_SENS="${1:?sensitivity yaml required}"
NUM_CHUNKS="${2:?num_chunks required}"
RUN_TYPE="${3:-response}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

if [ ! -f "${JOB_SENS}" ]; then
  echo "Sensitivity config not found: ${JOB_SENS}" >&2
  exit 1
fi

CONFIG_NAME="$(basename "${JOB_SENS}" .yaml)"
OUTDIR="$(awk '
  /^[[:space:]]*outdir[[:space:]]*:/ {
    line = $0
    sub(/^[[:space:]]*outdir[[:space:]]*:[[:space:]]*/, "", line)
    sub(/[[:space:]]*#.*/, "", line)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
    gsub(/^["'"'"']|["'"'"']$/, "", line)
    print line
    exit
  }
' "${JOB_SENS}")"
if [ -z "${OUTDIR}" ]; then
  echo "Could not parse outdir from ${JOB_SENS}" >&2
  exit 1
fi

if [[ "${OUTDIR}" = /* ]]; then
  OUTDIR_ABS="${OUTDIR}"
else
  OUTDIR_CLEAN="${OUTDIR#./}"
  OUTDIR_ABS="${REPO_ROOT}/${OUTDIR_CLEAN}"
fi

JOB_SENS_ABS="$(cd "$(dirname "${JOB_SENS}")" && pwd)/$(basename "${JOB_SENS}")"
SENS_ROOT="${OUTDIR_ABS}/${CONFIG_NAME}"

echo "Submitting sensitivity workflow for ${JOB_SENS}"
echo "  Run root: ${SENS_ROOT}"
echo "  Chunks:   ${NUM_CHUNKS}"
echo "  Run type: ${RUN_TYPE}"

if [ -d "${SENS_ROOT}" ]; then
  echo "Removing existing sensitivity run root: ${SENS_ROOT}"
  rm -rf "${SENS_ROOT}"
fi
mkdir -p "${SENS_ROOT}"

export JOB_SENS_ABS
export SENS_ROOT
export NUM_CHUNKS
export RUN_TYPE

mkdir -p logs
MANIFEST_JOB_NAME="${CONFIG_NAME}_sens_manifest"
MANIFEST_JOB="$(sbatch --parsable \
  --job-name="${MANIFEST_JOB_NAME}" \
  --output=logs/%x_%j.out \
  --error=logs/%x_%j.err \
  --partition=broadwl \
  --nodes=1 \
  --ntasks-per-node=1 \
  --cpus-per-task=1 \
  --time=00:10:00 \
  --mem=8G \
  --account=pi-rglennerster \
  --export=ALL,REPO_ROOT="${REPO_ROOT}",JOB_SENS_ABS="${JOB_SENS_ABS}",RUN_TYPE="${RUN_TYPE}" \
  --wrap="module load matlab/2023a; cd \"${REPO_ROOT}\"; matlab -batch \"run('./matlab/load_project.m'); write_sensitivity_manifest('${JOB_SENS_ABS}', '${RUN_TYPE}');\"")"
echo "Sensitivity manifest job submitted: ${MANIFEST_JOB}"

JOB_NAME="${CONFIG_NAME}_sens_chunk"
ARRAY_JOB="$(sbatch --parsable --dependency=afterok:${MANIFEST_JOB} --array=1-${NUM_CHUNKS} \
  --job-name="${JOB_NAME}" \
  --export=ALL,JOB_SENS_ABS="${JOB_SENS_ABS}",NUM_CHUNKS="${NUM_CHUNKS}",RUN_TYPE="${RUN_TYPE}",OVERWRITE="true" \
  slurm/submit_sensitivity_chunk.sbatch)"
echo "Sensitivity chunk array submitted: ${ARRAY_JOB}"

JOB_NAME="${CONFIG_NAME}_sens_agg"
AGG_JOB="$(sbatch --parsable --dependency=afterok:"${ARRAY_JOB}" \
  --job-name="${JOB_NAME}" \
  --export=ALL,SENS_ROOT="${SENS_ROOT}" \
  slurm/submit_sensitivity_agg.sbatch)"
echo "Sensitivity aggregation job submitted: ${AGG_JOB}"

echo ""
echo "Sensitivity workflow submitted successfully."
echo "Monitor with: squeue -u \$USER"
