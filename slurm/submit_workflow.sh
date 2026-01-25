#!/bin/bash
# Submit complete workflow with proper dependencies
# Usage: ./submit_full_workflow.sh <job_config> <num_chunks> [n_bootstrap]

JOB_CONFIG=$1
NUM_CHUNKS=$2
N_BOOTSTRAP=${3:-1000}
BOOT_WORKERS=${4:-2}
CONFIG_NAME=$(basename ${JOB_CONFIG} .yaml)

echo "Submitting workflow for ${JOB_CONFIG}"
echo "  Chunks: ${NUM_CHUNKS}"
echo "  Bootstrap samples: ${N_BOOTSTRAP}"

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
