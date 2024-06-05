# Pandemic Model


## Configuring scenarios and model runs
We distinguish between two types of configs: 
1. **job configs** and 
2. **scenario configs**. 

Job configs configure settings that persist across a series of model runs (number of simulations, number of years, output directory, etc). It also takes in the names of a directory containing scenario configs. Each scenario config contains the parameter configurations particular to that scenario that differ from the baseline scenario configuration that can be found in `pandemic_model/default_params`.

## Run model

### Local
To run the model, create a job config and run the following command:
```
matlab  -nodesktop -nojvm -nosplash -r "run_job({PATH_TO_JOB_CONFIG})"
```

### Cluster using SLURM
To do