function plot_pairwise_program_matrix(job_dir)
%PLOT_PAIRWISE_PROGRAM_MATRIX Create complementarity matrix figure for programs.
%   PLOT_PAIRWISE_PROGRAM_MATRIX(JOB_DIR) reads the pairwise advance
%   investment results for the specified JOB_DIR and creates a matrix
%   figure showing expected net value on the diagonal and pairwise
%   complementarities on the off-diagonal elements.
%
%   The script reproduces the logic used in WRITE_PAIRWISE_PROGRAM_TABLE
%   but outputs a figure instead of a LaTeX table.

    % Load data from processed results directory
    processed_dir = fullfile(job_dir, "processed");

    % Get scenarios from config
    config = yaml.loadFile(fullfile(job_dir, 'job_config.yaml'));
    scenarios = string(fieldnames(config.scenarios));
    scenarios = scenarios(~strcmp(scenarios, 'baseline') & ...
                          ~contains(scenarios, "prec1") & ...
                          ~contains(scenarios, "prevac0"));

    % Initialize summary table (point estimates only): net value = benefits - costs
    summary_table = table('Size', [length(scenarios) 2], ...
        'VariableTypes', {'string', 'double'});
    summary_table.Properties.VariableNames = {'Scenario', 'NetValue'};

    % Store raw data for complementarity calculations
    raw_data = struct();

    % Get results for each scenario
    for i = 1:length(scenarios)
        scen_name = scenarios(i);

        % Load relative sums table
        sums_file = fullfile(processed_dir, sprintf('%s_relative_sums.mat', scen_name));
        sums_data = load(sums_file);
        all_relative_sums = sums_data.all_relative_sums;

        % Store raw data for complementarity calculations
        raw_data.(scen_name).benefits = all_relative_sums.tot_benefits_pv_full;
        raw_data.(scen_name).costs = all_relative_sums.costs_adv_invest_pv_full;

        % Extract net value (benefits - costs, same definition as detailed table)
        net_value = mean(all_relative_sums.tot_benefits_pv_full - all_relative_sums.costs_adv_invest_pv_full);

        % Add to table
        summary_table(i, :) = {scen_name, net_value};
    end

    % Add accents and investment indicators to table
    [accents, investment_indicators] = parse_scenario_name(scenarios);

    summary_table.accent = accents;

    investments = investment_indicators.Properties.VariableNames;
    for i = 1:length(investments)
        summary_table.(investments{i}) = investment_indicators.(investments{i});
    end

    % Reorder programs to match investment scenario table (excluding status quo):
    % Advance capacity, Prototype vaccine R&D, Universal flu vaccine R&D,
    % Improved early warning.
    preferred_order = ["advance_capacity", "neglected_pathogen", ...
                       "universal_flu", "early_warning"];
    investments = intersect(preferred_order, string(investments), 'stable');

    % Compute complementarity point estimates
    surplus_summary_table = summary_table(strcmp(summary_table.accent, "surplus"), :);
    complementarity_table = compute_complementarity(surplus_summary_table, investments, raw_data);

    % Convert to billions for plotting
    surplus_summary_table.NetValue = surplus_summary_table.NetValue / 1e9;
    complementarity_table.NetValueComp = complementarity_table.NetValueComp / 1e9;

    % Build matrices for plotting
    n_inv = numel(investments);
    net_value_mat = nan(n_inv);
    comp_mat = nan(n_inv);

    % Helper for rounding display values
    round_nicely = @(x) string((x >= 10).*round(x) + (x < 10).*round(x, 1));

    % Diagonal: net value for each investment alone
    for i = 1:n_inv
        inv_name = investments{i};
        rows_for_inv = surplus_summary_table.(inv_name);
        is_active = table2array(surplus_summary_table(:, investments));
        is_alone = rows_for_inv & (sum(is_active, 2) == 1);
        if any(is_alone)
            net_value_mat(i, i) = surplus_summary_table.NetValue(is_alone);
        end
    end

    % Off-diagonal (lower triangle): complementarities
    for i = 1:n_inv
        for j = 1:(i - 1)
            inv1 = investments{i};
            inv2 = investments{j};
            comp_row = complementarity_table((strcmp(complementarity_table.Investment, inv1) & ...
                                              strcmp(complementarity_table.WithInvestment, inv2)) | ...
                                             (strcmp(complementarity_table.Investment, inv2) & ...
                                              strcmp(complementarity_table.WithInvestment, inv1)), :);
            if ~isempty(comp_row)
                comp_mat(i, j) = comp_row.NetValueComp;
            end
        end
    end

    % Create figure
    figure;
    hold on;
    set(gca, 'YDir', 'reverse', 'XTick', 1:n_inv, 'YTick', 1:n_inv);

    clean_names = cellfun(@get_clean_investment_name, investments, 'UniformOutput', false);
    set(gca, 'XTickLabel', clean_names, 'YTickLabel', clean_names);

    % Define colormap for complementarities (blue for positive, red for negative)
    max_abs_comp = max(abs(comp_mat(~isnan(comp_mat))));
    if isempty(max_abs_comp)
        max_abs_comp = 1;
    end

    for row = 1:n_inv
        for col = 1:n_inv
            x = col;
            y = row;
            if row == col
                % Diagonal cells: net value (grey)
                face_color = [0.95, 0.95, 0.95];
                rectangle('Position', [x - 0.5, y - 0.5, 1, 1], ...
                          'FaceColor', face_color, 'EdgeColor', [0, 0, 0]);
                if ~isnan(net_value_mat(row, col))
                    label_str = char(round_nicely(net_value_mat(row, col)));
                    text(x, y, label_str, 'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'middle', 'FontSize', 10);
                end
            elseif row > col && ~isnan(comp_mat(row, col))
                % Lower triangle: complementarities
                value = comp_mat(row, col);

                if value >= 0
                    face_color = [0.00, 0.45, 0.74]; % blue-ish for positive
                else
                    face_color = [0.85, 0.33, 0.10]; % red-ish for negative
                end

                rectangle('Position', [x - 0.5, y - 0.5, 1, 1], ...
                          'FaceColor', face_color, 'EdgeColor', [0, 0, 0]);
                label_str = char(round_nicely(value));
                text(x, y, label_str, 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', 'FontSize', 10, 'Color', [1, 1, 1]);
            end
        end
    end

    box off;
    xtickangle(45);

    % Ensure figures directory exists and save with exportgraphics
    figures_dir = fullfile(job_dir, "figures");
    if ~exist(figures_dir, 'dir')
        mkdir(figures_dir);
    end
    outfile_pdf = fullfile(figures_dir, "pairwise_complementarity_matrix.pdf");
    outfile_png = fullfile(figures_dir, "pairwise_complementarity_matrix.png");

    exportgraphics(gcf, outfile_pdf, ...
        'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
    exportgraphics(gcf, outfile_png, ...
        'ContentType', 'image', 'Resolution', 600);

end

function [accent, investment_indicators] = parse_scenario_name(scenario_name)
%PARSE_SCENARIO_NAME Parse scenario names into accent and investment flags.

    accent = regexp(scenario_name, '(bcr|surplus)$', 'match', 'once');

    investments = {'advance_capacity', 'early_warning', 'neglected_pathogen', 'universal_flu'};

    investment_indicators = table('Size', [length(scenario_name) 4], ...
                                  'VariableTypes', {'logical', 'logical', 'logical', 'logical'}, ...
                                  'VariableNames', investments);

    for i = 1:length(investments)
        investment_indicators.(investments{i}) = contains(scenario_name, investments{i});
    end
end

function complementarity_table = compute_complementarity(summary_data, investments, raw_data)
%COMPUTE_COMPLEMENTARITY Compute complementarity net values for investment pairs.

    n_pairs = 0;
    for i = 1:length(investments)
        for j = (i+1):length(investments)
            has_both = false;
            for k = 1:height(summary_data)
                if summary_data.(investments{i})(k) && summary_data.(investments{j})(k)
                    has_both = true;
                    break;
                end
            end
            if has_both
                n_pairs = n_pairs + 1;
            end
        end
    end

    complementarity_table = table('Size', [n_pairs 3], ...
        'VariableTypes', {'string', 'string', 'double'});
    complementarity_table.Properties.VariableNames = {...
        'Investment', 'WithInvestment', 'NetValueComp'};

    row_idx = 1;
    for i = 1:length(investments)
        for j = (i+1):length(investments)
            investment1 = investments{i};
            investment2 = investments{j};

            with_scenario = [];
            for k = 1:height(summary_data)
                is_active = table2array(summary_data(k, investments));
                if summary_data.(investment1)(k) && summary_data.(investment2)(k) && sum(is_active) == 2
                    with_scenario = summary_data.Scenario(k);
                    break;
                end
            end
            if isempty(with_scenario)
                continue;
            end

            with_benefits = raw_data.(with_scenario).benefits;
            with_costs = raw_data.(with_scenario).costs;

            alone1_scenario = [];
            for k = 1:height(summary_data)
                is_active = table2array(summary_data(k, investments));
                if summary_data.(investment1)(k) && sum(is_active) == 1
                    alone1_scenario = summary_data.Scenario(k);
                    break;
                end
            end
            if isempty(alone1_scenario)
                warning('No alone scenario found for %s', investment1);
                continue;
            end
            alone1_benefits = raw_data.(alone1_scenario).benefits;
            alone1_costs = raw_data.(alone1_scenario).costs;

            alone2_scenario = [];
            for k = 1:height(summary_data)
                is_active = table2array(summary_data(k, investments));
                if summary_data.(investment2)(k) && sum(is_active) == 1
                    alone2_scenario = summary_data.Scenario(k);
                    break;
                end
            end
            if isempty(alone2_scenario)
                warning('No alone scenario found for %s', investment2);
                continue;
            end
            alone2_benefits = raw_data.(alone2_scenario).benefits;
            alone2_costs = raw_data.(alone2_scenario).costs;

            net_with = mean(with_benefits - with_costs);
            net_alone1 = mean(alone1_benefits - alone1_costs);
            net_alone2 = mean(alone2_benefits - alone2_costs);
            net_value_comp = net_with - net_alone1 - net_alone2;

            complementarity_table(row_idx, :) = {investment1, investment2, net_value_comp};
            row_idx = row_idx + 1;
        end
    end
end

function clean_name = get_clean_investment_name(investment)
%GET_CLEAN_INVESTMENT_NAME Map internal investment name to display label.

    clean_map = dictionary(["advance_capacity", "early_warning", "neglected_pathogen", "universal_flu"], ...
                           ["Advance capacity", "Improved early warning", "Prototype vaccine R&D", "Universal flu vaccine R&D"]);

    clean_name = clean_map(investment);
end

