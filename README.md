# Pandemic Model

## Installation
This repository uses YAML configuration files. If you don't already have the `yaml` directory in your repository, clone [this repository](https://github.com/MartinKoch123/yaml) into the root directory of the pandemic model repository.

## Configuring scenarios and model runs
We distinguish between two types of configs: 
1. **job configs** and 
2. **scenario configs**. 

Job configs configure settings that persist across a series of model runs (number of simulations, number of years, output directory, etc). It also takes in the names of a directory containing scenario configs. Each scenario config contains the parameter configurations particular to that scenario. `config/job_configs/job_template.yaml` and `config/scenario_configs/scenario_template.yaml` colectively specify the parameters required to run the model.

The distinction between job parameter and scenario parameters is not hard and fast, and may change as our work evolves.

## Run model

### Local
To run the model locally, create a job config, a directory with scenario configs and run the following command:
```
matlab  -nodesktop -nosplash -r "run_simulations({PATH_TO_JOB_CONFIG})"
```

### Cluster using SLURM
To do