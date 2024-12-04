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

    % Generate simulations
    arrival_dist = load_arrival_dist(job_config.arrival_dist_config);
    duration_dist = load_duration_dist(job_config.duration_dist_config);
    viral_family_data = readtable(job_config.viral_family_data);
    base_simulation_table = get_base_simulation_table(arrival_dist, duration_dist, viral_family_data, job_config);

    % Add econ loss params
    econ_loss_model = load_econ_loss_model(job_config.econ_loss_model_config);

    % Save the simulation table using the name of the job config
    simulation_table_path = fullfile(outdirpath, "base_simulation_table.mat");
    save(simulation_table_path, 'base_simulation_table');
    
    % Log the save operation
    fprintf('Simulation table saved to: %s\n', simulation_table_path);

    % Plot upfront outputs
    % Arrival distribution
    arrival_exceedance_plot = plot_arrival_dist(arrival_dist, job_config.response_threshold);
    saveas(arrival_exceedance_plot, fullfile(job_config.outdirpath, "arrival_exceedance_prob.jpg"))

    % Ex ante duration distribution
    % Move to function later
    ex_ante_dur_fig = figure;
    hold on;
    plot(duration_dist.pd);
    set(findobj(gca, 'Type', 'Line'), 'LineWidth', 1.5);
    xlabel('Years', 'FontSize', 12);
    ylabel('Probabiliyt density', 'FontSize', 12);
    title('Ex ante pandemic duration PDF', 'FontSize', 14, 'FontWeight', 'bold');
    hold off;
    saveas(ex_ante_dur_fig, fullfile(job_config.outdirpath, "figures", "ex_ante_duration_pdf.jpg"));

    % Realized duration plots
    ex_post_dur_fig = figure;
    hold on;
    histogram(base_simulation_table.actual_dur);
    title("Ex post pandemic durations");
    xlabel("Actual duration (years)");
    ylabel("Frequency");
    hold off;
    saveas(ex_post_dur_fig, fullfile(job_config.outdirpath, "figures", "ex_post_duration_hist.jpg"))

    dur_severity_scatterhist = figure;
    subplot(2, 2, 3);  % Bottom-left position for scatter plot
    scatterhist(base_simulation_table.actual_dur, base_simulation_table.eff_severity, ...
        'Kernel', 'on', 'Location', 'SouthEast');
    xlabel('Actual duration (years)');
    ylabel('Effective severity (deaths / 10,000)');
    title('Effective severity vs pandemic duration');
    grid on;
    
    saveas(dur_severity_scatterhist, fullfile(job_config.outdirpath, "figures", "dur_severity_scatterhist.jpg"))

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
        scenario_simulation_table = get_scenario_simulation_table(base_simulation_table, econ_loss_model, simulation_params);

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

function config = clean_job_config(config)

    config.surveillance_thresholds = cell2mat(config.surveillance_thresholds);
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

    % Set pathogen family params. Should maybe do this elsewhere
    updated_params.viral_families_researched = parse_rd_investments(scenario_config.rd_investments, viral_family_data);
    num_vfs_researched = length(updated_params.viral_families_researched) % Check dimensions here

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