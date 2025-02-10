function run_sensitivity(config_path)
    %% Load configs
    fprintf('Loading configuration files...\n');
    sensitivity_config = yaml.loadFile(config_path);
    job_config = yaml.loadFile(sensitivity_config.base_job_config);
    job_config = clean_job_config(job_config);

    % Create base sensitivity output directory
    [~, sensitivity_name, ~] = fileparts(config_path);
    sensitivity_base_dir = fullfile(sensitivity_config.outdir, sensitivity_name);
    create_folders_recursively(sensitivity_base_dir);
    
    % Save sensitivity config at top level
    sensitivity_config_outpath = fullfile(sensitivity_base_dir, "sensitivity_config.yaml");
    yaml.dumpFile(sensitivity_config_outpath, sensitivity_config);

    %% Run baseline configuration
    fprintf('Running baseline configuration...\n');
    baseline_dir = fullfile(sensitivity_base_dir, 'baseline');
    create_folders_recursively(baseline_dir);
    
    % Set up baseline config
    run_config = job_config;
    run_config.outdir = baseline_dir;
    
    % Run baseline
    run_single_scenario(run_config);

    %% Get sensitivity variables and values
    sensitivities = sensitivity_config.sensitivities;
    sensitivity_vars = fieldnames(sensitivities);

    fprintf('Running sensitivity analysis...\n');
    % Run job for each sensitivity variable and value
    for i = 1:length(sensitivity_vars)
        var_name = sensitivity_vars{i};
        var_values = sensitivities.(var_name);
        
        fprintf('Processing sensitivity variable: %s\n', var_name);
        % Create directory for this sensitivity variable
        var_dir = fullfile(sensitivity_base_dir, var_name);
        create_folders_recursively(var_dir);

        for j = 1:length(var_values)
            fprintf('  Running value %d of %d...\n', j, length(var_values));
            % Make copy of base job config
            run_config = job_config;
            var_value = var_values{j};
            
            % Update config with sensitivity value
            run_config.(var_name) = var_value;
            
            % Set output directory for this sensitivity run
            run_config.outdir = fullfile(var_dir, sprintf('value_%d', j));
            create_folders_recursively(run_config.outdir);
            
            run_single_scenario(run_config);
        end
    end
    fprintf('Sensitivity analysis complete!\n');
end


function run_single_scenario(run_config)
    % Run a single scenario and handle output organization
    %
    % Args:
    %   run_config (struct): Configuration for this scenario run
    %
    % The function:
    % 1. Creates temporary config file
    % 2. Runs the job
    % 3. Moves results to proper location
    % 4. Cleans up temporary files
    
    temp_config_path = tempname;
    yaml.dumpFile(temp_config_path, run_config);
    run_job(temp_config_path);

    % Move results from temp folder
    [~, temp_name, ~] = fileparts(temp_config_path);
    temp_results = fullfile(run_config.outdir, temp_name);
    if exist(temp_results, 'dir')
        movefile(fullfile(temp_results, '*'), run_config.outdir);
        rmdir(temp_results);
    end
    delete(temp_config_path);
end