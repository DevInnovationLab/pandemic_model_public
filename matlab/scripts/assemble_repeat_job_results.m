function assemble_repeat_job_results(output_dir, overwrite, varargin)
    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'vars_to_keep', ['benefits_vaccine', 'total_costs_pv'], @isstring);
    addParameter(p, 'n_bootstrap', 1000, @isnumeric);
    addParameter(p, 'parallel', false, @islogical);
    parse(p, varargin{:});
    use_parallel = p.Results.parallel;
    vars_to_keep = p.Results.vars_to_keep;
    n_bootstrap = p.Results.n_bootstrap;

    subdir_tab = struct2table(dir(output_dir));
    subdir_tab = subdir_tab(contains(subdir_tab.name, "seed_"), :);
    subdirs = fullfile(subdir_tab.folder, subdir_tab.name);

    % Load config from first dir to get scenarios
    templ_config = yaml.loadFile(fullfile(subdirs(1), "job_config.yaml"));
    scenarios = fieldnames(templ_config.scenarios);
    sims_per_batch = templ_config.num_simulations;
    batches = numel(subdirs);
    total_sims = batches * sims_per_batch;

    result_dir = fullfile(output_dir, "processed");
    if ~exist(result_dir, 'dir')
        mkdir(result_dir);
    end

    % Get variable names
    keep_vars = strcat(vars_to_keep, "_full");

    % Set up bootstrap indices
    rng(42);
    bootstrap_indices = randi(total_sims, total_sims, n_bootstrap);

    % Use parfor if parallel, otherwise regular for
    if use_parallel
        parfor i = 1:numel(scenarios)
            process_scenario(scenarios{i}, subdirs, result_dir, keep_vars, ...
                           sims_per_batch, batches, total_sims, ...
                           bootstrap_indices, n_bootstrap, overwrite);
        end
    else
        for i = 1:numel(scenarios)
            process_scenario(scenarios{i}, subdirs, result_dir, keep_vars, ...
                           sims_per_batch, batches, total_sims, ...
                           bootstrap_indices, n_bootstrap, overwrite);
        end
    end
end

function process_scenario(scenario, subdirs, result_dir, keep_vars, ...
                         sims_per_batch, batches, total_sims, ...
                         bootstrap_indices, n_bootstrap, overwrite)
    if strcmp(scenario, "baseline")
        return
    end

    rel_sums_file = fullfile(result_dir, sprintf("%s_rel_sums.mat", scenario));
    bootstrap_file = fullfile(result_dir, sprintf("%s_rel_sums_bootstraps.mat", scenario));

    if ~(exist(rel_sums_file, 'file') && exist(bootstrap_file, 'file')) || overwrite

        % Initialize results table
        results = table('Size', [total_sims, numel(keep_vars)], ...
                        'VariableTypes', repmat({'double'}, 1, numel(keep_vars)), ...
                        'VariableNames', keep_vars);

        % Load and concatenate data from all batches
        for j = 1:batches
            subdir = subdirs(j);
            rel_sums_path = fullfile(subdir, "raw", ...
                                    sprintf("%s_relative_sums.mat", scenario));
            
            load(rel_sums_path, 'scenario_sum_table');

            % Calculate row indices for this batch
            start_idx = (j-1) * sims_per_batch + 1;
            end_idx = j * sims_per_batch;
            
            % Copy all keep_vars at once
            results(start_idx:end_idx, :) = scenario_sum_table(:, keep_vars);
        end

        save(fullfile(result_dir, sprintf("%s_rel_sums.mat", scenario)), ...
            'results');

        % Get bootstraps
        if ~exist(bootstrap_file, 'file') || overwrite
            bootstrap_table = table('Size', [n_bootstrap, numel(keep_vars)], ...
                                    'VariableTypes', repmat({'double'}, 1, numel(keep_vars)), ...
                                    'VariableNames', keep_vars);
            for j = 1:n_bootstrap
                bootstrap_table(j, :) = mean(results(bootstrap_indices(:, j), :), 1);
            end
            save(bootstrap_file, 'bootstrap_table');
        end
    end
end