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
matlab  -nodesktop -nosplash -r "run('./matlab/load_project'); run_job({PATH_TO_JOB_CONFIG})"
```

Use the same basic structure to run any matlab script in the codebase with a Matlab command window. To run without a command window, use

```
matlab -batch "run('./matlab/load_project'); {matlab_script}"
```

### Running Matlab tests

This is easiest to do in the Matlab GUI. Open our Matlab project in the GUI to load our scripts onto path and run
```
runtests({path_to_matlab_test});
```

### Running Stata

Running Stata from the command line is a little janky. You will first need to add your Stata executable to PATH.

Suppose that executable is called StataMP-64, as mine is. After adding it to PATH, you then run:

```
StataMP-64 -batch "{path_to_stata_do_file}"
```

This runs the do file and creates a log file with the same name in your working directory which will record Stata's execution of the program.