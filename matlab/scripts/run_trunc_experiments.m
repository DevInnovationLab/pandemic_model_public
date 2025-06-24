function run_trunc_experiments(rerun_jobs)
    % Get list of config files
    config_files = dir("./config/job_configs/trunc_experiments/*.yaml");
    
    % Run each config file
    for i = 1:length(config_files)
        config_path = fullfile(config_files(i).folder, config_files(i).name);
        [~, job_name, ~] = fileparts(config_files(i).name);
        job_dir = fullfile('./output/jobs', job_name);
        
        % Check if job already processed
        processed_dir = fullfile(job_dir, 'processed');
        if ~rerun_jobs && exist(job_dir, 'dir') && exist(processed_dir, 'dir')
            disp(['Skipping already processed job: ' job_name]);
            continue;
        end
        
        % Run simulation job
        disp(['Running job for config: ' config_files(i).name]);
        run_job(config_path);
        
        % Calculate NPV
        disp(['Calculating NPV for job: ' job_name]);
        get_npv(job_dir, true);
    end
end