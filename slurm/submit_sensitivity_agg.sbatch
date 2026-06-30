#!/bin/bash
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=2:00:00
#SBATCH --mem=16G
#SBATCH --account=pi-rglennerster

module load matlab/2023a
set -euo pipefail

mkdir -p logs

matlab -batch "run('./matlab/load_project.m'); agg_response_sensitivity_benefits('${SENS_ROOT}');"
