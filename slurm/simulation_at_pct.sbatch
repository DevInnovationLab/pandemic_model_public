#!/bin/bash
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=1:00:00
#SBATCH --mem=16G
#SBATCH --account=pi-rglennerster
#
# Run simulation_at_pct on a completed job (processed/*.mat and raw/chunk_* present).
#
# Usage (from repository root):
#   sbatch slurm/simulation_at_pct.sbatch <job_dir> <scenario_name> <percentile>
#
# Examples:
#   sbatch slurm/simulation_at_pct.sbatch output/jobs/allrisk_base baseline 50
#   sbatch slurm/simulation_at_pct.sbatch output/jobs/airborne_base advance_capacity_6_month 90

if [ "$#" -lt 3 ]; then
  echo "Usage: sbatch slurm/simulation_at_pct.sbatch <job_dir> <scenario_name> <percentile>" >&2
  exit 1
fi

mkdir -p logs

JOB_DIR=$1
SCENARIO=$2
PERCENTILE=$3

module load matlab/2023a

matlab -batch "run('./matlab/load_project.m'); simulation_at_pct('${JOB_DIR}', '${SCENARIO}', ${PERCENTILE});"
