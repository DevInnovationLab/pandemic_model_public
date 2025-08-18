
pathogen_data = readtable("./data/clean/pathogen_data_arrival_all.csv");

pathogen_data = sortrows(pathogen_data, 'arrival_share', 'descend');
pathogen_data.pathogen = cellfun(@(x) strcat(upper(x(1)), lower(x(2:end))), pathogen_data.pathogen, 'UniformOutput', false); % Capitalize the first letter of each pathogen

% Prepare data for the bar plot
x = categorical(pathogen_data.pathogen);
x = reordercats(x, pathogen_data.pathogen); % Keep order as in the sorted table
y = pathogen_data.arrival_share;
colors = pathogen_data.has_prototype;

% Calculate total share of viral families with adv RD
total_prototype_share = sum(pathogen_data.arrival_share(pathogen_data.has_prototype == 1));

% Create the bar plot
figure;
b = bar(x, y, 'FaceColor', 'flat');

% Assign colors
cmap = [1.0 0.4 0.4; 0.2 0.6 1.0; 0.5 0.5 0.5]; % Blue for 1, Red for 0, Grey for "unknown"
for i = 1:length(colors)
    if strcmp(pathogen_data.pathogen{i}, 'Unknown') % Grey for "unknown"
        b.CData(i, :) = cmap(3, :);
    else
        b.CData(i, :) = cmap(colors(i) + 1, :);
    end
end

% Rotate the x-axis labels for better readability
ax = gca;
ax.XTickLabelRotation = 45;
ax.Box = 'off';

% Add labels and title
xlabel('Viral family');
ylabel('Share of pandemics');
title('Viral family distribution');

% Add a custom legend% Add a custom legend manually
hold on;
dummy1 = plot(nan, nan, 's', 'Color', cmap(2, :), 'MarkerFaceColor', cmap(2, :));
dummy2 = plot(nan, nan, 's', 'Color', cmap(1, :), 'MarkerFaceColor', cmap(1, :));
dummy3 = plot(nan, nan, 's', 'Color', cmap(3, :), 'MarkerFaceColor', cmap(3, :));
legend([dummy1, dummy2, dummy3], {'Has prototype', 'No prototype', 'Unknown'}, ...
    'Location', 'northeast', 'FontSize', 10);
hold off;

print(gcf, fullfile("output/pandemic_pathogen_share_all.jpg"), '-djpeg', '-r400');
