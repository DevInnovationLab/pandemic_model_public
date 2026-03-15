function run_sensitivity(config_path, run_type, varargin)
    % Run a sensivitity config, which takes a job_config and details parameter variations to run.
    % The script has capacity for sens
    % 
    % Run type options:
    %   - 'unmitigated': Calls estimate_unmitigated_losses.m, which runs the model without any response interventions.
    %   - 'response': Calls run_job.m, which includes the full response model with interventions.
    % 
    % Optional parameters:
    %   - 'overwrite': true or false; helpful for restarting run that was interrupted without running the same scenarios.
    %   - 'num_chunks': Number of chunks to split simulations into (default: 1)
    %   - 'array_task_id': SLURM array task ID for parallel processing (default: nan)

    p = inputParser;
    addParameter(p, 'overwrite', true, @islogical);
    addParameter(p, 'num_chunks', 1, @isnumeric);
    addParameter(p, 'array_task_id', nan, @isnumeric);
    parse(p, varargin{:});
    
    overwrite = p.Results.overwrite;
    num_chunks = p.Results.num_chunks;
    array_task_id = p.Results.array_task_id;

    fprintf('Loading configuration files...\n');
    sensitivity_config = yaml.loadFile(config_path);
    [~, run_name, ~] = fileparts(config_path);
    sensitivity_config.run_name = run_name;

    run_sensitivity_core(sensitivity_config, run_type, overwrite, num_chunks, array_task_id);
end


function run_sensitivity_core(sensitivity_config, run_type, overwrite, num_chunks, array_task_id)
    % Single runner for all sensitivity configs: expand to canonical scenario list, then run each.
    % Handles one-parameter, multi-parameter, and mixed configs via expand_sensitivities.

    base_config = get_base_config(sensitivity_config);
    if isfield(sensitivity_config, 'fix_params') && ~isempty(sensitivity_config.fix_params)
        fix_params = sensitivity_config.fix_params;
        param_names = fieldnames(fix_params);
        for k = 1:length(param_names)
            base_config.(param_names{k}) = fix_params.(param_names{k});
        end
    end

    base_dir = setup_sensitivity_dirs(sensitivity_config, overwrite);
    run_baseline(base_config, base_dir, run_type, overwrite, num_chunks, array_task_id);

    [scenario_ids, rel_paths, overrides] = expand_sensitivities(sensitivity_config.sensitivities);

    for i = 1:length(scenario_ids)
        scenario_id = scenario_ids{i};
        scenario_dir = fullfile(base_dir, rel_paths{i});
        create_folders_recursively(scenario_dir);

        run_config = base_config;
        of = overrides{i};
        of_names = fieldnames(of);
        for k = 1:length(of_names)
            run_config.(of_names{k}) = of.(of_names{k});
        end
        run_config.outdir = scenario_dir;
        create_folders_recursively(run_config.outdir);

        job_config_path = fullfile(run_config.outdir, 'job_config.yaml');
        if ~overwrite && exist(job_config_path, 'file')
            fprintf('Skipping scenario "%s" (job_config.yaml exists).\n', scenario_id);
            continue;
        end

        fprintf('Processing scenario: %s\n', scenario_id);
        run_single_scenario(run_config, run_type, num_chunks, array_task_id);
    end
end


function base_config = get_base_config(sensitivity_config)
    base_config = yaml.loadFile(sensitivity_config.base_job_config);
end


function base_dir = setup_sensitivity_dirs(sensitivity_config, overwrite)
    base_dir = fullfile(sensitivity_config.outdir, sensitivity_config.run_name);

    if overwrite && exist(base_dir, 'dir')
        rmdir(base_dir, 's');
    end
    
    create_folders_recursively(base_dir);
    
    % Save sensitivity config
    yaml.dumpFile(fullfile(base_dir, "sensitivity_config.yaml"), sensitivity_config);
end


function run_baseline(base_config, base_dir, run_type, overwrite, num_chunks, array_task_id)
    fprintf('Running baseline configuration...\n');
    run_config = base_config;
    run_config.outdir = fullfile(base_dir, 'baseline');
    create_folders_recursively(run_config.outdir);

    % Only run if job_config.yaml does not exist in outdir, indicating job was not yet run
    job_config_path = fullfile(run_config.outdir, 'job_config.yaml');
    if ~overwrite && exist(job_config_path, 'file')
        fprintf('Skipping baseline as overwrite set to false.\n');
        return;
    end

    run_single_scenario(run_config, run_type, num_chunks, array_task_id);
end


function run_single_scenario(run_config, run_type, num_chunks, array_task_id)
    % Run a single scenario and handle output organization
    %
    % Args:
    %   run_config (struct): Configuration for this scenario run
    %   run_type (string): Either 'response' or 'unmitigated'
    %   num_chunks (numeric): Number of chunks to split simulations into
    %   array_task_id (numeric): SLURM array task ID (nan if not array task)
    
    temp_config_path = tempname;
    yaml.dumpFile(temp_config_path, run_config);

    % Handle run_type argument: either 'response' or 'unmitigated'
    if strcmp(run_type, "response")
        run_job(temp_config_path, 'num_chunks', num_chunks, 'array_task_id', array_task_id);
    elseif strcmp(run_type, "unmitigated")
        estimate_unmitigated_losses(temp_config_path, 'num_chunks', num_chunks, 'array_task_id', array_task_id);
    else
        error('Unknown run_type: %s. Must be "response" or "unmitigated".', run_type);
    end

    % For run_job, results are saved in a subfolder named after the temp config file
    [~, temp_name, ~] = fileparts(temp_config_path);
    temp_results = fullfile(run_config.outdir, temp_name);
    if exist(temp_results, 'dir')
        movefile(fullfile(temp_results, '*'), run_config.outdir);
        rmdir(temp_results);
    end
    delete(temp_config_path);
end