function compare_allrisk_and_airborne_losses()
    % Creates box plots comparing total losses from all pandemics in all-risk scenario,
    % respiratory pandemics in all-risk scenario, and airborne-only scenario
    %
    % Args:
    %   None - Uses standard job output directories
    %
    % Returns:
    %   None - Saves box plot to figures directory

    % Set up paths
    allrisk_dir = fullfile("output", "jobs", "no_mitigation_allrisk");
    airborne_dir = fullfile("output", "jobs", "no_mitigation_airborne");

    % Load pandemic tables and viral family data
    allrisk_table = readtable(fullfile(allrisk_dir, "raw", "baseline_pandemic_table.csv"));
    airborne_table = readtable(fullfile(airborne_dir, "raw", "baseline_pandemic_table.csv"));
    pathogen_data = readtable("data/clean/pathogen_data_arrival_all.csv");
    
    % Calculate total losses for each pandemic
    allrisk_totals = (allrisk_table.m_mortality_losses + ...
                      allrisk_table.m_output_losses + ...
                      allrisk_table.m_learning_losses) / 1e12;
                  
    % Get respiratory pandemics from all-risk scenario
    airborne_families = pathogen_data.pathogen(strcmp(pathogen_data.airborne, 'Yes'));
    airborne_idx = ismember(allrisk_table.pathogen, airborne_families);
    
    % Calculate total losses for airborne scenario
    airborne_totals = (airborne_table.m_mortality_losses + ...
                       airborne_table.m_output_losses + ...
                       airborne_table.m_learning_losses) / 1e12;

    % Get unique sim_nums
    allrisk_sims = unique(allrisk_table.sim_num);
    airborne_sims = unique(airborne_table.sim_num);
    
    % Calculate total losses per sim_num
    allrisk_sim_totals = zeros(length(allrisk_sims), 1);
    allrisk_resp_sim_totals = zeros(length(allrisk_sims), 1);
    airborne_sim_totals = zeros(length(airborne_sims), 1);
    
    for i = 1:length(allrisk_sims)
        sim_idx = allrisk_table.sim_num == allrisk_sims(i);
        allrisk_sim_totals(i) = sum(allrisk_totals(sim_idx));
        allrisk_resp_sim_totals(i) = sum(allrisk_totals(sim_idx & airborne_idx));
    end
    
    for i = 1:length(airborne_sims)
        sim_idx = airborne_table.sim_num == airborne_sims(i);
        airborne_sim_totals(i) = sum(airborne_totals(sim_idx));
    end

    % Combine data and create labels
    all_data = [allrisk_sim_totals; allrisk_resp_sim_totals; airborne_sim_totals];
    labels = [repmat({'All Risks - All Pandemics'}, length(allrisk_sim_totals), 1);
              repmat({'All Risks - Respiratory Only'}, length(allrisk_resp_sim_totals), 1);
              repmat({'Airborne Only'}, length(airborne_sim_totals), 1)];

    % Create figure
    fig = figure('Position', [100 100 800 600], 'Visible', 'off');
    
    % Create categorical array with custom ordering
    categories = {'All Risks - All Pandemics', 'All Risks - Respiratory Only', 'Airborne Only'};
    labels_cat = categorical(labels, categories, 'Ordinal', true);
    
    % Create subplot with box plot and bar chart
    tiledlayout(2,1)
    
    % Box plot
    nexttile
    boxchart(labels_cat, all_data)
    grid on
    ylabel('Total losses per sim_num ($ trillions)', 'FontSize', 10)
    title('Distribution of total pandemic losses by scenario', 'FontSize', 14)
    set(gca, 'FontSize', 9)
    xtickangle(45)
    
    % Bar chart of means
    nexttile
    means = [];
    for i = 1:length(categories)
        means(i) = mean(all_data(labels_cat == categories{i}));
    end
    bar(categorical(categories, categories, 'Ordinal', true), means)
    grid on
    ylabel('Average total losses per sim_num ($ trillions)', 'FontSize', 10)
    title('Average pandemic losses by scenario', 'FontSize', 14)
    set(gca, 'FontSize', 9)
    xtickangle(45)

    % Save figure
    figures_dir = fullfile(allrisk_dir, "figures");
    if ~exist(figures_dir, 'dir')
        mkdir(figures_dir);
    end
    saveas(fig, fullfile(figures_dir, "allrisk_vs_airborne_losses.png"));
    close(fig);
end
