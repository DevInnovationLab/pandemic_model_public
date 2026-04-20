function plot_vaccine_readiness_cmf(job_dir)
    % Plot cumulative distribution of vaccine-available months during pandemics.
    %
    % Generates a two-subplot figure (surplus-accepting and BCR-accepting scenarios)
    % showing, per scenario, the share of pandemic months in which a vaccine was
    % already available.
    %
    % Args:
    %   job_dir  Path to the job output directory (contains run_config.yaml and raw/).

    % Load job configuration and scenario names
    run_config = yaml.loadFile(fullfile(job_dir, "run_config.yaml"));
    scenarios = fieldnames(run_config.scenarios);
    disp(scenarios)
    raw_dir = fullfile(job_dir, "raw");

    % Classify scenarios into Surplus and BCR (Benefit-Cost Ratio) based on their names
    surplus_idx = contains(lower(scenarios), 'surplus');
    bcr_idx = contains(lower(scenarios), 'bcr');
    % If no 'bcr' or 'surplus' is found, fallback to split by a common substring if possible.
    % This fallback can be customized for the specific project scenario names.

    % Set up the figure with two subplots
    spec = get_paper_figure_spec("grid_2xn");
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 spec.width_in spec.height_in], 'Visible', 'off');

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
        chunk_dirs = list_chunk_dirs(raw_dir);
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
            'LineWidth', spec.stroke.primary, ...
            'Color', color_palette_1(ii,:));

        leg_entries_1{end+1} = scenario;
    end
    xlabel('Months with vaccine', 'FontSize', spec.typography.axis_label, 'FontWeight', 'normal', 'FontName', spec.font_name);
    ylabel('Cumulative share of outbreaks', 'FontSize', spec.typography.axis_label, 'FontWeight', 'normal', 'FontName', spec.font_name);
    if ~isempty(leg_entries_1)
        legend(convert_varnames(leg_entries_1), ...
            'Location', 'southeast', ...
            'Box', 'on', ...
            'FontSize', spec.typography.legend, 'FontName', spec.font_name);
    end
    ax1 = gca;
    apply_paper_axis_style(ax1, spec);
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
        chunk_dirs = list_chunk_dirs(raw_dir);
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
            'LineWidth', spec.stroke.primary, ...
            'Color', color_palette_2(ii,:));
        leg_entries_2{end+1} = scenario;
    end
    xlabel('Months with vaccine', 'FontSize', spec.typography.axis_label, 'FontWeight', 'normal', 'FontName', spec.font_name);
    ylabel('Cumulative share of outbreaks', 'FontSize', spec.typography.axis_label, 'FontWeight', 'normal', 'FontName', spec.font_name);
    if ~isempty(leg_entries_2)
        legend(convert_varnames(leg_entries_2), ...
            'Location', 'southeast', ...
            'Box', 'on', ...
            'FontSize', spec.typography.legend, 'FontName', spec.font_name);
    end
    ax2 = gca;
    apply_paper_axis_style(ax2, spec);
    ax2.GridColor = [0.6 0.6 0.6];
    hold off;

    % Create figure directory if it does not exist
    figure_dir = fullfile(job_dir, "figures");
    if ~exist(figure_dir, 'dir')
        mkdir(figure_dir);
    end

    % Save the figure as high-resolution vector PDF
    export_figure(fig, fullfile(figure_dir, 'vaccine_readiness_cmf_subplots.pdf'));
    close(fig);
end