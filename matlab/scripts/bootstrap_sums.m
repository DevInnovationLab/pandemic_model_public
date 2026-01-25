function bootstrap_sums(sim_results_path, varargin)
    % Bootstrap aggregated results from a completed job array run
    % 
    % Args:
    %   sim_results_path: Path to simulation results directory
    %   varargin: Optional name-value pairs:
    %     'keep_vars': String array of variable names to bootstrap (default: all)
    %     'n_bootstrap': Number of bootstrap samples (default: 1000)
    
    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'keep_vars', ["benefits_vaccine_full", "total_costs_pv_full"], @(x) isstring(x) || isempty(x));
    addParameter(p, 'n_bootstrap', 1000, @isnumeric);
    addParameter(p, 'parallel', false, @islogical);
    addParameter(p, 'n_workers', 1, @isnumeric);
    addParameter(p, 'seed', 42, @isnumeric);
    parse(p, varargin{:});
    keep_vars = p.Results.keep_vars;
    n_bootstrap = p.Results.n_bootstrap;
    use_parallel = p.Results.parallel;
    n_workers = p.Results.n_workers;
    seed = p.Results.seed;

    processed_dir = fullfile(sim_results_path, "processed");
    
    % Load config to get scenario info
    config = yaml.loadFile(fullfile(sim_results_path, "job_config.yaml"));
    scenario_names = fieldnames(config.scenarios);
    
    % Set up random seed for reproducibility    
    if use_parallel
        pc = parcluster('local');
        parpool(pc, n_workers);

        parfor i = 1:length(scenario_names)
            process_scenario(scenario_names{i}, processed_dir, keep_vars, n_bootstrap, seed);
        end

        delete(gcp('nocreate'));
    else
        for i = 1:length(scenario_names)
            process_scenario(scenario_names{i}, processed_dir, keep_vars, n_bootstrap, seed);
        end
    end

    fprintf('All bootstraps complete!\n');
end

function process_scenario(scenario_name, processed_dir, keep_vars, n_bootstrap, seed)
    if strcmp(scenario_name, 'baseline')
        return;
    end

    rng(seed);
    
    rel_sums_file = fullfile(processed_dir, sprintf('%s_relative_sums.mat', scenario_name));
    bootstrap_file = fullfile(processed_dir, sprintf('%s_relative_sums_bootstraps.mat', scenario_name));
    
    if ~exist(rel_sums_file, 'file')
        warning('Relative sums file not found for scenario %s. Skipping.', scenario_name);
        return;
    end
    
    % Load the aggregated data
    load(rel_sums_file);
    
    % Get number of simulations
    n_sims = height(all_relative_sums);
    
    % Generate bootstrap indices
    bootstrap_indices = randi(n_sims, n_sims, n_bootstrap);
    
    % Create bootstrap table
    bootstrap_table = table('Size', [n_bootstrap, numel(keep_vars)], ...
                            'VariableTypes', repmat({'double'}, 1, numel(keep_vars)), ...
                            'VariableNames', keep_vars);
    
    % Calculate bootstrap means
    for j = 1:n_bootstrap
        bootstrap_table(j, :) = mean(all_relative_sums(bootstrap_indices(:, j), keep_vars), 1);
    end
    
    % Save bootstrap results
    save(bootstrap_file, 'bootstrap_table');
    fprintf('Bootstrap complete for scenario %s (%d samples)\n', scenario_name, n_bootstrap);    
end
