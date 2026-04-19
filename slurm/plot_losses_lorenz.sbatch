#!/bin/bash
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=4:00:00
#SBATCH --mem=30G
#SBATCH --account=pi-rglennerster
#SBATCH --account=pi-rglennerster
#SBATCH --mail-type=ALL
#SBATCH --mail-user=squaade@rcc.uchicago.edu

module load matlab/2023a

OUTDIR=$1
OVERWRITE=${2:-true};

matlab -batch "run('./matlab/load_project.m'); plot_losses_lorenz('${OUTDIR}');"

