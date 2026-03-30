# R Scripts

Input data preparation scripts for the pandemic model. These generate the files
in `output/` that MATLAB reads at runtime.

## Execution Order

Run from the repository root. Activate the R environment first:

```r
# In R or RScript
renv::restore()  # first time only
```

### Step 1: Clean raw data

```bash
Rscript R/scripts/clean_arrival_rate_responses.R
Rscript R/scripts/clean_detection_data.R
```

### Step 2: Generate pathogen info and R&D inputs

```bash
Rscript R/scripts/write_pathogen_info.R
Rscript R/scripts/write_adv_rd_inputs.R
```

### Step 3: Fit vaccine PTRS and R&D timelines

```bash
Rscript R/scripts/fit_vaccine_ptrs_and_timeline.R
Rscript R/scripts/fit_vaccine_rd_costs.R
Rscript R/scripts/get_expected_rd_outcomes.R
```

### Step 4: Generate tables and predictions

```bash
Rscript R/scripts/create_ptrs_table.R
Rscript R/scripts/create_timelines_from_predictions.R
Rscript R/scripts/create_optimistic_rd_timelines.R
Rscript R/scripts/pred_viral_arrival_risk.R
```

### Step 5: Publication tables (optional)

```bash
Rscript R/scripts/write_ptrs_pub_table.R
Rscript R/scripts/write_rd_timeline_pub_table.R
Rscript R/scripts/write_vaccine_always_succeed.R
```

## Script Reference

| Script | Output |
|---|---|
| `clean_arrival_rate_responses.R` | Cleaned arrival rate data |
| `clean_detection_data.R` | Cleaned detection data |
| `write_pathogen_info.R` | `data/raw/pathogen_info.csv` |
| `write_adv_rd_inputs.R` | Advance R&D input files |
| `fit_vaccine_ptrs_and_timeline.R` | PTRS and timeline model fits |
| `fit_vaccine_rd_costs.R` | R&D cost model |
| `get_expected_rd_outcomes.R` | Expected R&D outcomes |
| `create_ptrs_table.R` | `output/ptrs/ptrs_table.csv` |
| `create_timelines_from_predictions.R` | `output/rd_timelines/timelines_from_predictions.csv` |
| `create_optimistic_rd_timelines.R` | Optimistic R&D timeline variants |
| `pred_viral_arrival_risk.R` | Pathogen arrival risk predictions |
| `plot_arrival_shares.R` | Arrival share diagnostic plots |
| `plot_ptrs.R` | PTRS diagnostic plots |
| `plot_timelines_from_preds.R` | Timeline diagnostic plots |
| `plot_prototype_invest_effect.R` | Prototype investment effect plots |
| `write_ptrs_pub_table.R` | Publication-ready PTRS table |
| `write_rd_timeline_pub_table.R` | Publication-ready timeline table |
| `write_vaccine_always_succeed.R` | Vaccine-always-succeed sensitivity inputs |
