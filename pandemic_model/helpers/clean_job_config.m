function config = clean_job_config(config)

    config.surveillance_thresholds = cell2mat(config.surveillance_thresholds);
end 

