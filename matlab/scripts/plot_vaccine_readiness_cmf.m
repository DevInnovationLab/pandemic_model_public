function plot_vaccine_readiness_cmf(job_dir)
    % Plot the cumulative share of months with vaccine available during pandemics for each scenario.
    % Args:
    %   job_dir: Directory containing job configuration and results

    % Load job configuration and scenario names
    job_config = yaml.loadFile(fullfile(job_dir, "job_config.yaml"));
    scenarios = fieldnames(job_config.scenarios);
    disp(scenarios)
    raw_dir = fullfile(job_dir, "raw");

    % Set up figure for plotting
    fig = figure('Color', 'w', 'Position', [200 200 700 500]);
    hold on;

    % Define a color palette and line styles for clarity
    color_palette = lines(length(scenarios));

    % Plot the cumulative mass function (CMF) for each scenario
    for i = 1:length(scenarios)
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
            'Color', color_palette(i,:));
    end

    xlabel('Months with vaccine', 'FontSize', 14, 'FontWeight', 'normal');
    ylabel('Cumulative share of outbreaks', 'FontSize', 14, 'FontWeight', 'normal');
    title('Cumulative share of outbreaks by months with vaccine available', ...
        'FontSize', 16, 'FontWeight', 'normal', 'Units', 'normalized', 'Position', [0.5, 1.04, 0]);

    % Legend formatting
    disp(scenarios)
    leg = legend(convert_varnames(scenarios), ...
        'Location', 'southeast', ...
        'Box', 'on', ...
        'FontSize', 13);

    hold off;
    
    % Make grid faint for better visual clarity
    ax = gca;
    grid on;
    ax.GridAlpha = 0.3; % Make grid lines faint
    ax.GridColor = [0.6 0.6 0.6];

    % Create figure directory if it does not exist
    figure_dir = fullfile(job_dir, "figures");
    if ~exist(figure_dir, 'dir')
        mkdir(figure_dir);
    end

    % Save the figure as high-resolution PNG and PDF
    print(fig, fullfile(figure_dir, 'vaccine_readiness_cmf'), '-dpng', '-r400');
    close(fig);
end