function run_simulations(job_config_path)
    % Add libraries to path
    addpath(genpath('./yaml'));
    addpath(genpath('./pandemic_model'));

    % Load job config and set seed
    job_config = yaml.loadFile(job_config_path);
    job_config = clean_job_config(job_config);
    rng(job_config.seed);

    % Create output dir
    [~, job_config_name, ~] = fileparts(job_config_path);

    foldername = job_config_name;
    if job_config.add_datetime_to_outdir
        currentDateTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
        foldername = foldername + "_" + char(currentDateTime);
    end
    
    outdirpath = fullfile(job_config.outdir, foldername, "raw");
    create_folders_recursively(outdirpath);
    job_config.outdirpath = outdirpath;
    figure_path = fullfile(outdirpath, "figures");

    % Generate simulations
    arrival_dist = load_arrival_dist(job_config.arrival_dist_config);
    response_threshold_dict = yaml.loadFile(job_config.response_threshold_path);
    duration_dist = load_duration_dist(job_config.duration_dist_config);
    viral_family_data = readtable(job_config.viral_family_data);
    vaccine_ptrs_data = readtable(job_config.vaccine_ptrs);
    econ_loss_model = load_econ_loss_model(job_config.econ_loss_model_config);

    job_config.response_threshold = response_threshold_dict.response_threshold;
    base_simulation_table = get_base_simulation_table(arrival_dist, duration_dist, viral_family_data, job_config);

    % Save the simulation table using the name of the job config
    base_simulation_table_path = fullfile(outdirpath, "base_simulation_table.mat");
    save(base_simulation_table_path, 'base_simulation_table');

    % Pandemics per simulation histogram
    h = histogram(base_simulation_table.eff_severity, 'Visible', 'off');
    counts = h.Values / job_config.num_simulations;
    midpoints = h.BinEdges(1:end-1) + diff(h.BinEdges) / 2;
    average_simulation_hist = figure('Visible', 'off');
    bar(counts, midpoints);
    xlabel("Effective severity");
    ylabel("Average number of pandemics per simulation (200 years)");
    title("Histogram of pandemic severities for average simulation");
    saveas(average_simulation_hist, fullfile(figure_path, "average_simulation_hist.jpg"));

    % Ex ante severity exceedance function
    ex_ante_severity_fig = plot_ex_ante_severity_exceedance(arrival_dist);
    saveas(ex_ante_severity_fig, fullfile(figure_path, "ex_ante_severity_exceedance.png"));

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

    % Ex ante duration distribution
    % Move to function later
    ex_ante_dur_fig = figure('Visible', 'off');
    hold on;
    plot(duration_dist.pd);
    set(findobj(gca, 'Type', 'Line'), 'LineWidth', 1.5);
    xlabel('Years', 'FontSize', 12);
    ylabel('Probability density', 'FontSize', 12);
    title('Ex ante pandemic duration PDF', 'FontSize', 14, 'FontWeight', 'bold');
    hold off;
    saveas(ex_ante_dur_fig, fullfile(figure_path, "ex_ante_duration_pdf.jpg"));

    % Realized duration plots
    ex_post_dur_fig = figure('Visible', 'off');
    hold on;
    histogram(base_simulation_table.actual_dur, 'Normalization', 'probability');
    title("Ex post pandemic durations");
    xlabel("Actual duration (years)");
    ylabel("Empirical probability");
    hold off;
    saveas(ex_post_dur_fig, fullfile(figure_path, "ex_post_duration_hist.jpg"))

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
    scenario_config_paths = dir(fullfile(job_config.scenario_configs, '*.yaml'));
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
        scenario_simulation_table = get_scenario_simulation_table(base_simulation_table, vaccine_ptrs_data, simulation_params);

        % Save scenario simulation table so you can inspect
        save(fullfile(outdirpath, "scenario_simulation_table.mat"), 'scenario_simulation_table');

        simulate_scenario(scenario_simulation_table, econ_loss_model, simulation_params);
    end

    % Handle filepath list input for scenario configs
    % TO DO 

    % Save job and scenario params
    config_outpath = fullfile(outdirpath, "job_config.yaml");
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
    updated_params.viral_families_researched = parse_rd_investments(scenario_config.rd_investments, viral_family_data);
    num_vfs_researched = length(updated_params.viral_families_researched); % Check dimensions here

    updated_params.adv_RD_spend = updated_params.adv_RD_cost_per_pathogen * ...
        updated_params.pathogens_per_family * ... 
        num_vfs_researched;

    % Set advance capacity
    [z_m, z_o] = get_adv_capacity(updated_params); % get target advance capacity
    updated_params.z_m = updated_params.share_target_advanced_capacity * z_m;
    updated_params.z_o = updated_params.share_target_advanced_capacity * z_o;

    validate_params(updated_params);

end

function validate_params(params)

    assert(params.RD_speedup_months <= params.tau_A); % R&D speedup must be less or equal than baseline time.
    assert(params.RD_success_rate_increase_per_platform * 4 <= 1 - params.p_b - params.p_m - params.p_o);

end