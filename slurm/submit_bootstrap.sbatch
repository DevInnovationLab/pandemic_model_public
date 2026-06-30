#!/bin/bash
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --partition=broadwl
#SBATCH --time=2:00:00
#SBATCH --mem-per-cpu=15G  
#SBATCH --account=pi-rglennerster

# Usage: sbatch --dependency=afterok:JOBID slurm_bootstrap.sh <run_config> [n_bootstrap]

JOB_CONFIG=$1
N_BOOTSTRAP=${2:-1000}
BOOT_WORKERS=${3:-4}

module load matlab/2023a

matlab -batch "run('./matlab/load_project.m'); run_workflow('${JOB_CONFIG}', 'n_bootstrap', ${N_BOOTSTRAP}, 'bootstrap_parallel', true, 'bootstrap_workers', ${BOOT_WORKERS}, 'skip_run', true, 'skip_aggregate', true);"
