#!/bin/bash
#SBATCH --job-name=allrisk_pairwise
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=1:00:00
#SBATCH --mem=50G
#SBATCH --account=pi-rglennerster
#SBATCH --account=pi-rglennerster
#SBATCH --mail-type=ALL
#SBATCH --mail-user=squaade@rcc.uchicago.edu

# ============ CONFIGURATION ============
JOB_CONFIG="./config/job_configs/allrisk_base_pairwise.yaml"
NUM_CHUNKS=10
#SBATCH --array=1-10 # Must be same as NUM_CHUNKS
# =======================================

module load matlab/2023a

matlab -batch "run('./matlab/load_project.m'); run_job('${JOB_CONFIG}', 'array_task_id', ${SLURM_ARRAY_TASK_ID}, 'num_chunks', ${NUM_CHUNKS});"