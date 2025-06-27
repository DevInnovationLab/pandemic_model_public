function run_job(job_config_path)

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);
    job_config = clean_job_config(job_config);

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
    viral_family_data = readtable(job_config.viral_family_data, "TextType", "string");
    ptrs_vf = readtable(job_config.ptrs_vf, "TextType", "string");
    ptrs_rd = readtable(job_config.ptrs_rd, "TextType", "string");
    econ_loss_model = load_econ_loss_model(job_config.econ_loss_model_config);

    response_threshold_dict = yaml.loadFile(job_config.response_threshold_path);
    job_config.response_threshold = response_threshold_dict.response_threshold;

    % Generate base simulation to be used across scenarios
    base_simulation_table = get_base_simulation_table(arrival_dist, duration_dist, viral_family_data, job_config.seed, job_config);
    base_simulation_table_path = fullfile(raw_results_path, "base_simulation_table.mat");
    save(base_simulation_table_path, 'base_simulation_table');

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
    [unique_severities, ~, ic] = unique(sort(base_simulation_table.eff_severity));
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
        simulation_params = update_params(job_config, scenario_config, viral_family_data);
        simulation_params.scenario_name = scenario_name;

        % Run scenario
        scenario_simulation_table = get_scenario_simulation_table(base_simulation_table, ...
                                                                  ptrs_vf, ...
                                                                  ptrs_rd, ...
                                                                  viral_family_data, ...
                                                                  simulation_params);

        event_list_simulation(scenario_simulation_table, econ_loss_model, simulation_params);
    end

    % Save job and scenario params
    config_outpath = fullfile(sim_results_path, "job_config.yaml");
    yaml.dumpFile(config_outpath, out_params);
end

function updated_params = update_params(job_config, scenario_config, viral_family_data)

    % New parameters override base parameters
    updated_params = job_config;
    if ~isempty(scenario_config)
        fns = fieldnames(scenario_config);
        for k=1:numel(fns)
            updated_params.(fns{k}) = scenario_config.(fns{k});
        end
    end

    % Set pathogen family params.
    invest_strategy =scenario_config.rd_investments.strategy;
    num_vfs_researched = scenario_config.rd_investments.num;
    updated_params.viral_families_researched = parse_rd_investments(scenario_config.rd_investments, viral_family_data);

    if strcmp(invest_strategy, "top") || strcmp(invest_strategy, "random")
        updated_params.adv_RD = true;
    else
        updated_params.adv_RD = false;
    end

    updated_params.adv_RD_spend = updated_params.adv_RD_cost_per_pathogen * ...
        updated_params.pathogens_per_family * ... 
        num_vfs_researched;

    updated_params.ufv_spend = updated_params.adv_RD_cost_per_pathogen * updated_params.pathogens_per_family;

    % Set advance capacity
    if updated_params.share_target_advanced_capacity == 0
        updated_params.theta = 0;
    end

    [z_m, z_o] = get_adv_capacity(updated_params); % get target advance capacity
    updated_params.z_m = z_m;
    updated_params.z_o = z_o;

    assert(updated_params.rd_speedup_months <= updated_params.tau_a); % R&D speedup must be less or equal than baseline time.
end