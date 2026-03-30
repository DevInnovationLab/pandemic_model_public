function plot_vaccine_readiness_cmf(job_dir)
    % Plot the cumulative share of months with vaccine available during pandemics for each scenario,
    % displaying surplus and BCR scenarios on two different subplots.
    % Args:
    %   job_dir: Directory containing job configuration and results

    % Load job configuration and scenario names
    job_config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = fieldnames(job_config.scenarios);
    disp(scenarios)
    raw_dir = fullfile(job_dir, "raw");

    % Classify scenarios into Surplus and BCR (Benefit-Cost Ratio) based on their names
    surplus_idx = contains(lower(scenarios), 'surplus');
    bcr_idx = contains(lower(scenarios), 'bcr');
    % If no 'bcr' or 'surplus' is found, fallback to split by a common substring if possible.
    % This fallback can be customized for the specific project scenario names.

    % Set up the figure with two subplots
    fig = figure('Color', 'w', 'Position', [200 200 1100 500]);

    % Surplus subplot
    subplot(1,2,1);
    hold on;
    s_inds = find(surplus_idx);
    color_palette_1 = lines(length(s_inds));
    leg_entries_1 = {};
    for ii = 1:length(s_inds)
        i = s_inds(ii);
        scenario = scenarios{i};

        % Load pandemic table from all chunks
        chunk_dirs = dir(fullfile(raw_dir, 'chunk_*'));
        pandemic_tables = cell(length(chunk_dirs), 1);

        for j = 1:length(chunk_dirs)
            chunk_dir = fullfile(chunk_dirs(j).folder, chunk_dirs(j).name);
            pandemic_file = fullfile(chunk_dir, sprintf("%s_pandemic_table.mat", scenario));

            if exist(pandemic_file, 'file')
                S = load(pandemic_file);
                pandemic_tables{j} = S.pandemic_table;
            end
        end

        % Remove empty cells and concatenate
        pandemic_tables = pandemic_tables(~cellfun('isempty', pandemic_tables));

        if isempty(pandemic_tables)
            warning('No pandemic table found for scenario: %s', scenario);
            continue;
        end

        pandemic_table = vertcat(pandemic_tables{:});

        % Filter to events with a start year
        has_event_table = pandemic_table(~isnan(pandemic_table.yr_start), :);
        month_any_vaccine_ready = ~has_event_table.ufv_protection .* has_event_table.month_response_vaccine_ready;

        % Calculate months with vaccine available
        months_with_vax = max(0, (has_event_table.rd_state ~= 4) .* (has_event_table.actual_dur .* 12) - month_any_vaccine_ready);

        % Remove NaNs or negative values if any
        months_with_vax = months_with_vax(~isnan(months_with_vax) & months_with_vax >= 0);

        % Sort and compute empirical CMF
        sorted_months = sort(months_with_vax);
        cmf = (1:length(sorted_months)) / length(sorted_months);

        % Plot CMF with distinct style
        stairs(sorted_months, cmf, ...
            'LineWidth', 2.5, ...
            'Color', color_palette_1(ii,:));

        leg_entries_1{end+1} = scenario;
    end
    xlabel('Months with vaccine', 'FontSize', 14, 'FontWeight', 'normal');
    ylabel('Cumulative share of outbreaks', 'FontSize', 14, 'FontWeight', 'normal');
    title('Surplus Scenarios', ...
        'FontSize', 16, 'FontWeight', 'normal', 'Units', 'normalized', 'Position', [0.5, 1.04, 0]);
    if ~isempty(leg_entries_1)
        legend(convert_varnames(leg_entries_1), ...
            'Location', 'southeast', ...
            'Box', 'on', ...
            'FontSize', 13);
    end
    grid on;
    ax1 = gca;
    ax1.GridAlpha = 0.3;
    ax1.GridColor = [0.6 0.6 0.6];
    hold off;

    % BCR subplot
    subplot(1,2,2);
    hold on;
    b_inds = find(bcr_idx);
    color_palette_2 = lines(length(b_inds));
    leg_entries_2 = {};
    for ii = 1:length(b_inds)
        i = b_inds(ii);
        scenario = scenarios{i};

        % Load pandemic table from all chunks
        chunk_dirs = dir(fullfile(raw_dir, 'chunk_*'));
        pandemic_tables = cell(length(chunk_dirs), 1);

        for j = 1:length(chunk_dirs)
            chunk_dir = fullfile(chunk_dirs(j).folder, chunk_dirs(j).name);
            pandemic_file = fullfile(chunk_dir, sprintf("%s_pandemic_table.mat", scenario));

            if exist(pandemic_file, 'file')
                S = load(pandemic_file);
                pandemic_tables{j} = S.pandemic_table;
            end
        end

        % Remove empty cells and concatenate
        pandemic_tables = pandemic_tables(~cellfun('isempty', pandemic_tables));

        if isempty(pandemic_tables)
            warning('No pandemic table found for scenario: %s', scenario);
            continue;
        end

        pandemic_table = vertcat(pandemic_tables{:});

        % Filter to events with a start year
        has_event_table = pandemic_table(~isnan(pandemic_table.yr_start), :);
        month_any_vaccine_ready = ~has_event_table.ufv_protection .* has_event_table.month_response_vaccine_ready;

        % Calculate months with vaccine available
        months_with_vax = max(0, (has_event_table.rd_state ~= 4) .* (has_event_table.actual_dur .* 12) - month_any_vaccine_ready);

        % Remove NaNs or negative values if any
        months_with_vax = months_with_vax(~isnan(months_with_vax) & months_with_vax >= 0);

        % Sort and compute empirical CMF
        sorted_months = sort(months_with_vax);
        cmf = (1:length(sorted_months)) / length(sorted_months);

        % Plot CMF with distinct style
        stairs(sorted_months, cmf, ...
            'LineWidth', 2.5, ...
            'Color', color_palette_2(ii,:));
        leg_entries_2{end+1} = scenario;
    end
    xlabel('Months with vaccine', 'FontSize', 14, 'FontWeight', 'normal');
    ylabel('Cumulative share of outbreaks', 'FontSize', 14, 'FontWeight', 'normal');
    title('BCR Scenarios', ...
        'FontSize', 16, 'FontWeight', 'normal', 'Units', 'normalized', 'Position', [0.5, 1.04, 0]);
    if ~isempty(leg_entries_2)
        legend(convert_varnames(leg_entries_2), ...
            'Location', 'southeast', ...
            'Box', 'on', ...
            'FontSize', 13);
    end
    grid on;
    ax2 = gca;
    ax2.GridAlpha = 0.3;
    ax2.GridColor = [0.6 0.6 0.6];
    hold off;

    % Create figure directory if it does not exist
    figure_dir = fullfile(job_dir, "figures");
    if ~exist(figure_dir, 'dir')
        mkdir(figure_dir);
    end

    % Save the figure as high-resolution vector PDF
    exportgraphics(fig, fullfile(figure_dir, 'vaccine_readiness_cmf_subplots.pdf'), ...
        'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none');
    close(fig);
end