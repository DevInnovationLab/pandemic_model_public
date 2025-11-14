function run_job(job_config_path)

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
    duration_dist = load_duration_dist(job_config.duration_dist_config);
    arrival_rates = readtable(job_config.arrival_rates, "TextType", "string");
    pathogen_info = readtable(job_config.pathogen_info, "TextType", "string");
    ptrs_pathogen = readtable(job_config.ptrs_pathogen, "TextType", "string");
    prototype_effect_ptrs = readtable(job_config.prototype_effect_ptrs, "TextType", "string");
    response_rd_timelines = readtable(job_config.rd_timelines, "TextType", "string");
    econ_loss_model = load_econ_loss_model(job_config.econ_loss_model_config);

    % Convert logical columns in both arrival_rates and pathogen_info tables
    pathogen_info = convert_logical_columns(pathogen_info);
    arrival_rates = convert_logical_columns(arrival_rates);

    response_threshold_dict = yaml.loadFile(job_config.response_threshold_path);
    job_config.response_threshold = response_threshold_dict.response_threshold;

    % Generate base simulation to be used across scenarios
    [base_simulation_table, total_removed, total_trimmed] = get_base_simulation_table(arrival_dist, duration_dist, arrival_rates, pathogen_info, job_config.seed, job_config);
    base_simulation_table_path = fullfile(raw_results_path, "base_simulation_table.mat");
    save(base_simulation_table_path, 'base_simulation_table');

    % Save trim and remove amounts
    job_config.total_removed = total_removed;
    job_config.total_trimmed = total_trimmed;

    % Pandemics per simulation histogram
    h = histogram(base_simulation_table.eff_severity, 'Visible', 'off');
    counts = h.Values / job_config.num_simulations;
    midpoints = h.BinEdges(1:end-1) + diff(h.BinEdges) / 2;
    average_simulation_hist = figure('Visible', 'off');
    bar(midpoints, counts);
    xlabel("Effective severity");
    ylabel("Average number of pandemics per simulation (200 years)");
    title("Histogram of pandemic severities for average simulation");
    saveas(average_simulation_hist, fullfile(figure_path, "average_simulation_hist.jpg"));

    % Ex post severity exceedance function
    ex_post_severity_fig = figure('Visible', 'off');
    total_draws = job_config.num_simulations * job_config.sim_periods;
    [unique_severities, ~, ic] = unique(sort(base_simulation_table.severity));
	severity_counts = histcounts(ic, 1:max(ic)+1); % Count occurrences of each unique intensity
	emp_min_severity_prob = 1 - sum(severity_counts) / total_draws;
	cdf = (cumsum(severity_counts) / sum(severity_counts)) * (sum(severity_counts) / total_draws) + emp_min_severity_prob;
	exceedance = 1 - cdf;

    plot(unique_severities, exceedance, 'b-', 'LineWidth', 1.5); % Plot with a blue line
	grid on;
	xlabel('Deaths per 10,000'); % Label for x-axis
	ylabel('Exceedance probability'); % Label for y-axis
	title('Ex post severity exceedance function'); % Plot title

	% Customize plot appearance
	set(gca, 'XScale', 'log');
	set(gca, 'FontSize', 11); % Set axis font size

    saveas(ex_post_severity_fig, fullfile(figure_path, "ex_post_severity_exceedance.jpg"))

    % Plot duration distribution
    plot_duration_distributions(base_simulation_table, figure_path, false); % No clipped durations

    dur_severity_scatterhist = figure('Visible', 'off');
    subplot(2, 2, 3);  % Bottom-left position for scatter plot
    scatterhist(base_simulation_table.actual_dur, base_simulation_table.eff_severity, ...
        'Kernel', 'on', 'Location', 'SouthEast');
    xlabel('Actual duration (years)');
    ylabel('Effective severity (deaths / 10,000)');
    title('Effective severity vs pandemic duration');
    grid on;
    
    saveas(dur_severity_scatterhist, fullfile(figure_path, "dur_severity_scatterhist.jpg"))

    % 3d histogram of effective duration and severity
    severity_dur_hist = figure('Visible', 'off');
    histogram2(base_simulation_table.eff_severity, base_simulation_table.actual_dur, 'Normalization', 'probability');
    view(3);
    view(129, 28);
    xlabel("Actual severity (Deaths per 1,0000)");
    ylabel("Actual duration (years)");
    zlabel("Probability");
    title("Realized pandemic severity and duration histogram");
    saveas(severity_dur_hist, fullfile(figure_path, 'dur_severity_histogram.jpg'));

    % Create object storing job and scenario configurations that we will save.
    out_params = job_config;
    out_params.scenarios = {};
    
    % Handle folderpath input for scenario configs
    if isfolder(job_config.scenario_configs)
        scenario_config_paths = dir(fullfile(job_config.scenario_configs, '*.yaml'));
    elseif isfile(job_config.scenario_configs)
        scenario_config_paths = dir(fullfile(job_config.scenario_configs));
    else
        print("Improper scenario config")
    end

    for i = 1:length(scenario_config_paths)
        % Load scenario config
        scenario_config_path = fullfile(scenario_config_paths(i).folder, scenario_config_paths(i).name);
        [~, scenario_name, ~] = fileparts(scenario_config_path);
        disp(['Running configuration from file: ', scenario_config_path]);
        scenario_config = yaml.loadFile(scenario_config_path);
        out_params.scenarios.(scenario_name) = scenario_config;

        % Add scenario specific parameter configucations
        simulation_params = update_params(job_config, scenario_config, arrival_rates);
        simulation_params.scenario_name = scenario_name;

        % Run scenario
        scenario_simulation_table = get_scenario_simulation_table(base_simulation_table, ...
                                                                  ptrs_pathogen, ...
                                                                  prototype_effect_ptrs, ...
                                                                  response_rd_timelines, ...
                                                                  simulation_params);

        event_list_simulation(scenario_simulation_table, econ_loss_model, simulation_params);
    end

    % Save job and scenario params
    config_outpath = fullfile(sim_results_path, "job_config.yaml");
    yaml.dumpFile(config_outpath, out_params);
end

function updated_params = update_params(job_config, scenario_config, arrival_rates)

    % New parameters override base parameters
    updated_params = job_config;
    if ~isempty(scenario_config)
        fns = fieldnames(scenario_config);
        for k=1:numel(fns)
            updated_params.(fns{k}) = scenario_config.(fns{k});
        end
    end

    % Set pathogen family params.
    invest_strategy = scenario_config.rd_investments.strategy;
    updated_params.num_pathogens_researched = scenario_config.rd_investments.num;
    [pathogens_with_baseline_prototype, new_invested_pathogens] = parse_rd_investments(scenario_config.rd_investments, arrival_rates);
    updated_params.pathogens_with_baseline_prototype = pathogens_with_baseline_prototype;
    updated_params.new_invested_pathogens = new_invested_pathogens;

    if strcmp(invest_strategy, "top") || strcmp(invest_strategy, "random")
        updated_params.prototype_RD = true;
    else
        updated_params.prototype_RD = false;
    end

    updated_params.prototype_RD_spend = updated_params.advance_RD_cost_per_pathogen * updated_params.num_pathogens_researched;
    updated_params.ufv_spend = updated_params.advance_RD_cost_per_pathogen .* updated_params.univ_flu_cost_multiplier;

    % Set advance capacity
    if updated_params.share_target_advanced_capacity == 0
        updated_params.theta = 0;
    end

    [z_m, z_o] = get_adv_capacity(updated_params); % get target advance capacity
    updated_params.z_m = z_m;
    updated_params.z_o = z_o;
end

% Helper function to convert 'TRUE'/'FALSE'/NA columns to numeric 1/0/NaN
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