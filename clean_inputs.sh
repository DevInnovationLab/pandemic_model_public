# Run the following commands in your terminal before running this scripts
## cd python
## poetry shell
## cd ..

# Run order is important. Read scripts to understand dependencies.

# Clean data
matlab -batch "run('./matlab/load_project.m');
               clean_covid19_mortality;
               clean_covid19_vaccination;
               clean_hiv_deaths;
               clean_pathogen_data;
               clean_madhav_severity_exceedance;
               find_natural_covid_deaths('./config/run_configs/covid_severity_search.yaml');"

python ./python/scripts/clean_ptrs.py
python ./python/scripts/clean_rd_timelines_and_cost.py
python ./python/scripts/create_response_threshold.py
python ./python/scripts/fit_econ_loss_models.py
python ./python/scripts/fit_mle_duration.py "./data/epidemics_ds/epidemics_241210_clean_filt_all_int_0d01_1900.csv" --create-fig
python ./python/scripts/update_hiv_covid_severity.py "./data/epidemics_ds/epidemics_241210_clean_filt_all_int_0d01_1900.csv"

cmd /c "StataSE-64.exe /e /q do stata/scripts/ptrs_model.do"
cmd /c "StataSE-64.exe /e /q do stata/scripts/rd_costs.do"
cmd /c "StataSE-64.exe /e /q do stata/scripts/rd_timelines.do"