#!/bin/bash
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=0:15:00
#SBATCH --mem=16G
#SBATCH --account=pi-rglennerster
#
# Plot vaccine-readiness CMF and write percentile table for a completed job.
#
# Usage (from repository root):
#   sbatch slurm/plot_vaccine_readiness_cmf.sbatch <job_dir>
#
# Example:
#   sbatch slurm/plot_vaccine_readiness_cmf.sbatch output/single_runs/allrisk_base

if [ "$#" -lt 1 ]; then
  echo "Usage: sbatch slurm/plot_vaccine_readiness_cmf.sbatch <job_dir>" >&2
  exit 1
fi

mkdir -p logs

JOB_DIR=$1

module load matlab/2023a

matlab -batch "run('./matlab/load_project.m'); plot_vaccine_readiness_cmf('${JOB_DIR}');"
