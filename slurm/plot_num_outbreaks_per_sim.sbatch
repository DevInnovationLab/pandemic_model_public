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

# Usage: sbatch slurm/plot_num_outbreaks_per_sim.sbatch <job_dir>
# Example: sbatch slurm/plot_num_outbreaks_per_sim.sbatch output/single_runs/allrisk_base

JOB_DIR=$1

module load matlab/2023a

matlab -batch "run('./matlab/load_project.m'); plot_num_outbreaks_per_sim('${JOB_DIR}');"
