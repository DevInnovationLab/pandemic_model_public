function run_sensitivity(config_path)
    %% Load config and determine type
    fprintf('Loading configuration files...\n');
    sensitivity_config = yaml.loadFile(config_path);
    [~, run_name, ~] = fileparts(config_path);
    sensitivity_config.run_name = run_name;
    
    % Check first sensitivity to determine config type
    sensitivity_fields = fieldnames(sensitivity_config.sensitivities);
    first_field = char(sensitivity_fields(1));
    first_sensitivity = sensitivity_config.sensitivities.(first_field);
    % Check if this is a multi-parameter config (like compare_old.yaml) where each
    % sensitivity scenario changes multiple parameters at once, or a single-parameter
    % config (like no_mitigation.yaml) where we vary one parameter at a time
    if isstruct(first_sensitivity) && ~isempty(fieldnames(first_sensitivity))
        % Multi-parameter case: first sensitivity is a struct with fields
        % specifying multiple parameters to change
        run_multiparameter_sensitivity(sensitivity_config);
    elseif iscell(first_sensitivity) || isnumeric(first_sensitivity)
        % Single-parameter case: first sensitivity is an array of values
        % to try for a single parameter
        run_oneparameter_sensitivity(sensitivity_config);
    else
        error('Invalid sensitivity configuration structure. Each sensitivity must either be a struct of parameters or an array of values.');
    end
end


function run_multiparameter_sensitivity(sensitivity_config)
    % Runs sensitivity analysis where each variation changes multiple parameters
    % E.g. compare_old.yaml style configs
    
    % Get base config and apply any fixed parameter overrides
    base_config = get_base_config(sensitivity_config);
    if isfield(sensitivity_config, 'fix_params') && ~isempty(sensitivity_config.fix_params)
        fix_params = sensitivity_config.fix_params;
        param_names = fieldnames(fix_params);
        for k = 1:length(param_names)
            base_config.(param_names{k}) = fix_params.(param_names{k});
        end
    end
    
    base_dir = setup_sensitivity_dirs(sensitivity_config);
    run_baseline(base_config, base_dir);
    
    % Run variations
    sensitivities = sensitivity_config.sensitivities;
    sensitivity_scenarios = fieldnames(sensitivities);
    
    for i = 1:length(sensitivity_scenarios)
        scenario = sensitivity_scenarios{i};
        vary_params = sensitivities.(scenario);
        
        fprintf('Processing scenario: %s\n', scenario);
        scenario_dir = fullfile(base_dir, scenario);
        create_folders_recursively(scenario_dir);
        run_config = base_config;
            
        % Update all parameters in this combination
        param_names = fieldnames(vary_params);
        for k = 1:length(param_names)
            run_config.(param_names{k}) = vary_params.(param_names{k});
        end
        
        run_config.outdir = scenario_dir;
        create_folders_recursively(run_config.outdir);
        run_single_scenario(run_config);
    end
end


function run_oneparameter_sensitivity(sensitivity_config)
    % Runs sensitivity analysis where each variation changes one parameter
    % E.g. no_mitigation.yaml style configs
    
    % Get base config and apply any fixed parameter overrides
    base_config = get_base_config(sensitivity_config);
    if isfield(sensitivity_config, 'fix_params') && ~isempty(sensitivity_config.fix_params)
        fix_params = sensitivity_config.fix_params;
        param_names = fieldnames(fix_params);
        for k = 1:length(param_names)
            base_config.(param_names{k}) = fix_params.(param_names{k});
        end
    end
    
    base_dir = setup_sensitivity_dirs(sensitivity_config);
    run_baseline(base_config, base_dir);
    
    % Run variations
    sensitivities = sensitivity_config.sensitivities;
    sensitivity_vars = fieldnames(sensitivities);
    
    for i = 1:length(sensitivity_vars)
        var_name = sensitivity_vars{i};
        var_values = sensitivities.(var_name);
        
        fprintf('Processing parameter: %s\n', var_name);
        var_dir = fullfile(base_dir, var_name);
        create_folders_recursively(var_dir);

        for j = 1:length(var_values)
            fprintf('  Running value %d of %d...\n', j, length(var_values));
            run_config = base_config;
            run_config.(var_name) = var_values{j};
            
            run_config.outdir = fullfile(var_dir, sprintf('value_%d', j));
            create_folders_recursively(run_config.outdir);
            run_single_scenario(run_config);
        end
    end
end


function base_config = get_base_config(sensitivity_config)
    base_config = yaml.loadFile(sensitivity_config.base_job_config);
    base_config = clean_job_config(base_config);
end


function base_dir = setup_sensitivity_dirs(sensitivity_config)
    base_dir = fullfile(sensitivity_config.outdir, sensitivity_config.run_name);
    create_folders_recursively(base_dir);
    
    % Save sensitivity config
    yaml.dumpFile(fullfile(base_dir, "sensitivity_config.yaml"), sensitivity_config);
end


function run_baseline(base_config, base_dir)
    fprintf('Running baseline configuration...\n');
    run_config = base_config;
    run_config.outdir = fullfile(base_dir, 'baseline');
    create_folders_recursively(run_config.outdir);
    run_single_scenario(run_config);
end


function run_single_scenario(run_config)
    % Run a single scenario and handle output organization
    %
    % Args:
    %   run_config (struct): Configuration for this scenario run
    
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