#!/bin/bash
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err
#SBATCH --partition=broadwl
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=2:00:00
#SBATCH --mem=30G
#SBATCH --account=pi-rglennerster
#SBATCH --account=pi-rglennerster
#SBATCH --mail-type=ALL
#SBATCH --mail-user=squaade@rcc.uchicago.edu

module load matlab/2023a

JOB_CONFIG=$1

matlab -batch "run('./matlab/load_project.m'); compare_exceedances('${JOB_CONFIG}'); compare_exceedances('${JOB_CONFIG}', 'Include90CI', true);"

