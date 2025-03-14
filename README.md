# Pandemic Model

## Installation
This repository uses YAML configuration files. Clone [this repository](https://github.com/MartinKoch123/yaml) into the root directory of the pandemic model repository to add YAML read and write functions.

## Python
We use [poetry](https://python-poetry.org/) for Python package and environment management.

Install poetry following the instructions [here](https://python-poetry.org/docs/#installation). Then run the following commands

```
cd python
poetry install
```

To use the project environment:

```
cd python
poetry shell
```

All python scripts are run form the top folder, so you will have to cd back to the root dir after activating the environment.

## Configuring scenarios and model runs
We distinguish between two types of configs: 
1. **job configs** and 
2. **scenario configs**. 

Job configs configure settings that persist across a series of model runs (number of simulations, number of years, output directory, etc). It also takes in the names of a directory containing scenario configs. Each scenario config contains the parameter configurations particular to that scenario. `config/job_configs/job_template.yaml` and `config/scenario_configs/scenario_template.yaml` colectively specify the parameters required to run the model.

The distinction between job parameter and scenario parameters is not hard and fast, and may change as our work evolves.

We have also added **sensitivity configs**, which we use for runs that conduct sensitivity analysis. We will document those in more detail later.

## Run

### Local
To run the model locally, create a job config, a directory with scenario configs and run the following command:

```
matlab  -nodesktop -nosplash -r "run('./matlab/load_project'); run_simulations({PATH_TO_JOB_CONFIG})"
```

### Cluster using SLURM
If we ever want to run on a cluster, we will likely want to refactor the simulation script so that each simulation stores its results on disk and then the results are combined at the end in a single process. Or some other way that will allow us to allocate the minimum required memory to each process and still merge all the results at the end.


### Running Matlab Tests