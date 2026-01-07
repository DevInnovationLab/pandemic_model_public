#!/bin/bash
#SBATCH --job-name=allrisk_check_compl
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=5:00:00
#SBATCH --mem=56G

#SBATCH --account=pi-rglennerster
# Optional: email notifications
#SBATCH --mail-type=ALL
#SBATCH --mail-user=squaade@rcc.uchicago.edu

# Load MATLAB module
module load matlab/2023a

# Run MATLAB in batch mode
matlab -batch "run('./matlab/load_project.m'); run_job('./config/job_configs/allrisk_base_check_cap_warning_compl.yaml', 'num_chunks', 13, 'parallel', false);"
