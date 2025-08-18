function estimate_unmitigated_losses(job_config_path)
    arguments
        job_config_path (1,:) char
    end
    % Estimate unmitigated pandemic losses.
    %
    %   result = estimate_unmitigated_losses(job_config_path, num_simulations)
    %
    %   Parameters
    %   ----------
    %   job_config_path : char
    %       Path to the job configuration YAML file.
    %   num_simulations : double
    %       Number of simulations to run.
    %
    %   Returns
    %   -------
    %   result : struct
    %       Struct containing results of the unmitigated loss estimation.

    % Make sure to adjust for the false positive rate

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);
        
    % Create output dir
    [~, job_config_name, ~] = fileparts(job_config_path);

    foldername = job_config_name;
    if job_config.add_datetime_to_outdir
        currentDateTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
        foldername = foldername + "_" + char(currentDateTime);
    end

    % Set results paths 
    sim_results_path = fullfile(job_config.outdir, foldername);
    raw_results_path = fullfile(sim_results_path, "raw");
    figure_path = fullfile(sim_results_path, "figures");
    job_config.outdirpath = sim_results_path;
    job_config.rawoutpath = raw_results_path;

    create_folders_recursively(raw_results_path);
    create_folders_recursively(figure_path);

    % Load inputs from files
    arrival_dist = load_arrival_dist(job_config.arrival_dist_config, job_config.false_positive_rate);
    assert(strcmp(arrival_dist.measure, "severity"), ...
           "Please use an arrival distribution estimated on pandemic severities.")
    duration_dist = load_duration_dist(job_config.duration_dist_config);
    econ_loss_model = load_econ_loss_model(job_config.econ_loss_model_config);
    pathogen_data = readtable(job_config.pathogen_data, "TextType", "string");

    job_config.response_threshold = 0; % Only works because we've been carefuly in arrival dist sampler

    simulation_table = get_base_simulation_table(arrival_dist, duration_dist, pathogen_data, job_config.seed, job_config);
    simulation_table = simulation_table(~isnan(simulation_table.yr_start), :); % Remove simulations with no outbreaks
    sim_idx = simulation_table.sim_num;
    yr_start = simulation_table.yr_start;
    yr_end = simulation_table.yr_end;
    intensity = simulation_table.intensity;

    % Compute the number of years for each pandemic
    intensity_mat = zeros([job_config.num_simulations, job_config.sim_periods]);
 
    % Vectorized expansion using repelem and arrayfun
    pandemic_lengths = yr_end - yr_start + 1;
    row_idx = repelem(sim_idx, pandemic_lengths);
    val = repelem(intensity, pandemic_lengths);
    col_idx = arrayfun(@(s,e) (s:e)', yr_start, yr_end, 'UniformOutput', false);
    col_idx = vertcat(col_idx{:});

    % Assign all values at once
    ind = sub2ind(size(intensity_mat), row_idx, col_idx);
    intensity_mat(ind) = val;

    % Now we can calculate losses
    discount_factor = ((1+job_config.y)./(1+job_config.r)).^(1:job_config.sim_periods);
    deaths = (job_config.P0 / 10000) .* intensity_mat;
    mortality_losses = deaths .* job_config.value_of_death .* discount_factor;

    output_losses = zeros(size(intensity_mat));
    output_losses(ind) = econ_loss_model.predict(val) .* (job_config.Y0 .* job_config.P0);
    output_losses = output_losses .* discount_factor;
    learning_losses = output_losses .* (10 / 13.8);
    total_losses = mortality_losses + output_losses + learning_losses;

    % Save all relevant results to a single MAT file (as in save_to_file_fast.m)
    yaml.dumpFile(fullfile(job_config.outdir, "job_config.yaml"), job_config) % Save job config
    mat_filename = fullfile(job_config.outdir, 'unmitigated_losses.mat');
    save(mat_filename, ...
        'deaths', ...
        'mortality_losses', ...
        'output_losses', ...
        'learning_losses', ...
        'total_losses', ...
        '-v7.3');
    fprintf('Saved unmitigated losses to %s\n', mat_filename);
end