#!/bin/bash
#SBATCH --job-name=allrisk_pairwise
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=20:00:00
#SBATCH --mem=48G

#SBATCH --account=pi-rglennerster
# Optional: email notifications
#SBATCH --mail-type=ALL
#SBATCH --mail-user=squaade@rcc.uchicago.edu

# Load MATLAB module
module load matlab/2023a

# Run MATLAB in batch mode
matlab -batch "run('./matlab/load_project.m'); run_job('./config/job_configs/allrisk_base_pairwise.yaml');"
