#!/bin/bash
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --partition=broadwl
#SBATCH --cpus-per-task=1
#SBATCH --time=30:00
#SBATCH --mem=16G  # Lower memory for aggregation
#SBATCH --account=pi-rglennerster

# Usage: sbatch --dependency=afterok:JOBID slurm_aggregate.sh <run_config>

JOB_CONFIG=$1

module load matlab/2023a

matlab -batch "run('./matlab/load_project.m'); run_workflow('${JOB_CONFIG}', 'skip_run', true, 'skip_bootstrap', true);"