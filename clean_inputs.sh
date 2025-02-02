# Run the following commands in your terminal before running this scripts
## cd python
## poetry shell
## cd ..

# Run order is important. Read scripts to understand dependencies.

# Clean data
matlab -batch "run('./matlab/load_project.m');
               clean_covid19_mortality;
               clean_covid19_vaccination;
               clean_viral_family_data;
               clean_madhav_severity_exceedance;
               find_natural_severity_covid('./config/job_configs/covid_severity_search.yaml');"

python ./python/scripts/clean_ptrs.py
python ./python/scripts/create_response_threshold.py
python ./python/scripts/fit_distributions.py
python ./python/scripts/fit_econ_loss_models.py

StataMP-64 -b do stata/scripts/ptrs_model.do