function estimate_unmitigated_losses(job_config_path)
    % Estimate unmitigated pandemic losses.
    %
    %   estimate_unmitigated_losses(job_config_path)
    %
    %   Parameters
    %   ----------
    %   job_config_path : char
    %       Path to the job configuration YAML file.
    %
    %   This function simulates unmitigated pandemic losses using the
    %   configuration provided in the YAML file at job_config_path.
    arguments
        job_config_path (1,:) char
    end

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);

    % Create output dir
    [~, job_config_name, ~] = fileparts(job_config_path);

    foldername = job_config_name;
    if isfield(job_config, 'add_datetime_to_outdir') && job_config.add_datetime_to_outdir
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

    if isfield(job_config, 'response_threshold') && isfield(job_config, 'response_threshold_path')
        warning('Both ''response_threshold'' and ''response_threshold_path'' are set in the job config. Defaulting to ''response_threshold''.');
    elseif ~isfield(job_config, 'response_threshold') && isfield(job_config, 'response_threshold_path')
        response_threshold_dict = yaml.loadFile(job_config.response_threshold_path);
        job_config.response_threshold = response_threshold_dict.response_threshold;
    end

    % Load inputs from files (same as run_job.m)
    arrival_dist = load_arrival_dist(job_config.arrival_dist_config, 0);
    assert(strcmp(arrival_dist.measure, "severity"), ...
           "Please use an arrival distribution estimated on pandemic severities.")
    duration_dist = load_duration_dist(job_config.duration_dist_config);
    num_simulations = height(arrival_dist.param_samples);

    % Load arrival rates, pathogen info, etc. as in run_job.m
    arrival_rates = readtable(job_config.arrival_rates, "TextType", "string");
    pathogen_info = readtable(job_config.pathogen_info, "TextType", "string");
    econ_loss_model = load_econ_loss_model(job_config.econ_loss_model_config);

    % Convert logical columns in both arrival_rates and pathogen_info tables
    pathogen_info = convert_logical_columns(pathogen_info);
    arrival_rates = convert_logical_columns(arrival_rates);

    % Generate base simulation table (same as run_job.m, but no scenario config)
    [simulation_table, total_removed, total_trimmed] = get_base_simulation_table(arrival_dist, duration_dist, arrival_rates, pathogen_info, job_config.seed, num_simulations, job_config);

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

    % Save all relevant results to a single MAT file
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



function tbl = convert_logical_columns(tbl)
    %CONVERT_LOGICAL_COLUMNS Converts 'TRUE'/'FALSE'/NA columns to numeric 1/0/NaN.
    %
    %   tbl = CONVERT_LOGICAL_COLUMNS(tbl) converts any columns in the table tbl
    %   that contain 'TRUE'/'FALSE'/NA values (as strings or logicals) to numeric
    %   columns with 1 for TRUE, 0 for FALSE, and NaN for NA/missing.
    %
    %   This is useful for harmonizing imported CSV data where logical columns
    %   may be read as strings.
    %
    %   Parameters
    %   ----------
    %   tbl : table
    %       Input table with possible logical columns as strings.
    %
    %   Returns
    %   -------
    %   tbl : table
    %       Table with logical columns converted to numeric.
    
    logical_colnames = {'has_prototype', 'airborne'};
    for i = 1:length(logical_colnames)
        col = logical_colnames{i};
        if ismember(col, tbl.Properties.VariableNames)
            col_data = tbl.(col);
            col_str = string(col_data);
            col_numeric = nan(height(tbl), 1);
            col_numeric(strcmpi(col_str, "TRUE")) = 1;
            col_numeric(strcmpi(col_str, "FALSE")) = 0;
            col_numeric(strcmpi(col_str, "NA")) = 0;
            tbl.(col) = col_numeric;
        end
    end
end
