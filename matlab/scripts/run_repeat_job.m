function run_repeat_job(job_config_path, num_repeats, varargin)

    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'parallel', false, @islogical);
    parse(p, varargin{:});
    use_parallel = p.Results.parallel;

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);
    [~, job_config_name, ~] = fileparts(job_config_path);
    job_config.save_mode = 'light';
    
    % Create output dir
    top_dir = fullfile(job_config.outdir, ...
        sprintf("%s_%d_repeat", job_config_name, num_repeats));
    create_folders_recursively(top_dir);

    % Make temporary file that you save and then you load bac
    base_seed = job_config.seed;
    
    % Use parfor if parallel, otherwise regular for
    if use_parallel
        parfor seed = base_seed:(base_seed + num_repeats - 1)
            run_single_repeat(job_config, top_dir, seed);
        end
    else
        for seed = base_seed:(base_seed + num_repeats - 1)
            run_single_repeat(job_config, top_dir, seed);
        end
    end
end

function run_single_repeat(job_config, top_dir, seed)
    run_config = job_config;
    run_config.seed = seed;
    run_config.outdir = fullfile(top_dir, sprintf("seed_%d", seed));
    create_folders_recursively(run_config.outdir);
    
    % Put down config for specific run
    temp_config_path = tempname;
    yaml.dumpFile(temp_config_path, run_config);
    run_job(temp_config_path);

    % For run_job, results are saved in a subfolder named after the temp config file
    [~, temp_name, ~] = fileparts(temp_config_path);
    temp_results = fullfile(run_config.outdir, temp_name);
    if exist(temp_results, 'dir')
        movefile(fullfile(temp_results, '*'), run_config.outdir);
        rmdir(temp_results);
    end
    delete(temp_config_path);
end