#!/bin/bash
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=4:00:00
#SBATCH --mem=45G
#SBATCH --account=pi-rglennerster
#SBATCH --account=pi-rglennerster
#SBATCH --mail-type=ALL
#SBATCH --mail-user=squaade@rcc.uchicago.edu

module load matlab/2023a

NUM_CHUNKS=$1
OVERWRITE=${2:-true};

matlab -batch "run('./matlab/load_project.m'); run_sensitivity('./config/sensitivity_configs/baseline_vaccine_program.yaml', 'response', 'num_chunks', ${NUM_CHUNKS}, 'overwrite', ${OVERWRITE});"

matlab -batch "run('./matlab/load_project.m'); agg_sensitivity_benefits('./sensitivity_results/baseline_vaccine_program');"
