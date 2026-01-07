function run_workflow(job_config_path, varargin)
    % Complete workflow: run job, aggregate, and bootstrap
    %
    % Usage:
    %   run_workflow('job.yaml')  % Run everything with defaults
    %   run_workflow('job.yaml', 'skip_run', true)  % Just aggregate & bootstrap
    %   run_workflow('job.yaml', 'aggregate_only', true)  % Only aggregate
    %   run_workflow('job.yaml', 'bootstrap_only', true)  % Only bootstrap
    %   run_workflow('job.yaml', 'array_task_id', 5, 'num_chunks', 10)  % Array task
    %
    % Parameters:
    %   job_config_path: Path to job config YAML
    %   
    % Optional name-value pairs:
    %   Job execution:
    %     'num_chunks': Number of chunks (default: 1)
    %     'parallel': Use parallel processing locally (default: false)
    %     'array_task_id': SLURM array task ID (default: nan, means not array task)
    %   
    %   Workflow control:
    %     'skip_run': Skip job execution, only aggregate/bootstrap (default: false)
    %     'aggregate_only': Only run aggregation (default: false)
    %     'bootstrap_only': Only run bootstrap (default: false)
    %     'skip_aggregate': Skip aggregation (default: false)
    %     'skip_bootstrap': Skip bootstrapping (default: false)
    %     'sim_results_path': Explicit path to results (for aggregate/bootstrap only)
    %
    %   Bootstrap parameters:
    %     'keep_vars': Variables to bootstrap (default: ["benefits_vaccine_full", "total_costs_pv_full"])
    %     'n_bootstrap': Number of bootstrap samples (default: 1000)
    %     'bootstrap_parallel': Use parallel for bootstrap (default: false)
    %     'bootstrap_workers': Number of workers for bootstrap (default: 4)
    %     'bootstrap_overwrite': Overwrite existing bootstraps (default: false)
    %     'bootstrap_seed': Random seed (default: 42)
    
    p = inputParser;
    
    % Job execution parameters
    addParameter(p, 'num_chunks', 1, @isnumeric);
    addParameter(p, 'array_task_id', nan, @isnumeric);
    
    % Workflow control
    addParameter(p, 'skip_run', false, @islogical);
    addParameter(p, 'skip_aggregate', false, @islogical);
    addParameter(p, 'skip_bootstrap', false, @islogical);
    addParameter(p, 'sim_results_path', '', @ischar);
    
    % Bootstrap parameters
    addParameter(p, 'keep_vars', ["benefits_vaccine_full", "total_costs_pv_full"], @(x) isstring(x) || isempty(x));
    addParameter(p, 'n_bootstrap', 1000, @isnumeric);
    addParameter(p, 'bootstrap_parallel', false, @islogical);
    addParameter(p, 'bootstrap_workers', 1, @(x) isnumeric(x) || isempty(x));
    addParameter(p, 'bootstrap_seed', 42, @isnumeric);
    
    parse(p, varargin{:});
    opts = p.Results;
    
    is_array_task = ~isnan(opts.array_task_id);
    
    % Determine sim_results_path
    if ~isempty(opts.sim_results_path)
        sim_results_path = opts.sim_results_path;
    else
        % Need to construct it from job_config
        job_config = yaml.loadFile(job_config_path);
        [~, job_config_name, ~] = fileparts(job_config_path);
        
        sim_results_path = fullfile(job_config.outdir, job_config_name);
    end
    
    % Run simulation (unless skipped)
    if ~opts.skip_run
        fprintf('=== Running job ===\n');
        run_job(job_config_path, ...
               'num_chunks', opts.num_chunks, ...
               'parallel', opts.parallel, ...
               'array_task_id', opts.array_task_id);
        
        % For array tasks, stop here
        if is_array_task
            fprintf('Array task %d complete. Run aggregation after all tasks finish.\n', opts.array_task_id);
            return;
        end
    end
    
    % Aggregate (unless skipped or array task)
    if ~opts.skip_aggregate && ~is_array_task
        fprintf('=== Aggregating results ===\n');
        aggregate_relative_sums(sim_results_path);
    end
    
    % Bootstrap (unless skipped or array task)
    if ~opts.skip_bootstrap && ~is_array_task
        fprintf('=== Bootstrapping results ===\n');
        bootstrap_sums(sim_results_path, ...
                      'keep_vars', opts.keep_vars, ...
                      'n_bootstrap', opts.n_bootstrap, ...
                      'parallel', opts.bootstrap_parallel, ...
                      'n_workers', opts.bootstrap_workers, ...
                      'overwrite', opts.bootstrap_overwrite, ...
                      'seed', opts.bootstrap_seed);
    end
    
    if ~is_array_task
        fprintf('=== Workflow complete! ===\n');
    end
end