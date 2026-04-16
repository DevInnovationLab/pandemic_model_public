# Reference Outputs

This directory stores committed reference outputs for regression testing.

## Generating Reference Outputs

Run the following from the repository root **once** to generate the reference outputs:

```matlab
run('./matlab/load_project')
run_workflow('config/run_configs/allrisk_base_small.yaml')
```

Then copy the processed outputs into this directory:

```bash
cp -r output/single_runs/allrisk_base_small/processed/ tests/reference/allrisk_base_small/processed/
```

Commit the reference outputs. They are the ground truth against which
`matlab/tests/run_regression_test.m` compares future runs.

## Re-generating After an Intentional Model Change

If you make an intentional change to computed results:
1. Run the reference workflow to produce new outputs
2. Copy them here (overwriting old files)
3. Commit with a message explaining what changed and why

## Files

- `allrisk_base_small/processed/baseline_annual_sums.mat`
- `allrisk_base_small/processed/{scenario}_relative_sums.mat`
- `allrisk_base_small/processed/{scenario}_relative_sums_bootstraps.mat`
