
pathogen_data = readtable("./data/clean/pathogen_data_arrival_all.csv");

pathogen_data = sortrows(pathogen_data, 'arrival_share', 'ascend');
pathogen_data.pathogen = replace(pathogen_data.pathogen, '_', ' ');
pathogen_data.pathogen = cellfun(@(x) strcat(upper(x(1)), lower(x(2:end))), pathogen_data.pathogen, 'UniformOutput', false); % Capitalize the first letter of each pathogen
pathogen_data.pathogen = replace(pathogen_data.pathogen, 'Crimean-congo hemorrhagic fever', 'CCHF');

% Prepare data for the bar plot
x = categorical(pathogen_data.pathogen);
x = reordercats(x, pathogen_data.pathogen); % Keep order as in the sorted table
y = pathogen_data.arrival_share;
colors = pathogen_data.has_prototype;

% Calculate total share of pathogens with adv RD
total_prototype_share = sum(pathogen_data.arrival_share(pathogen_data.has_prototype == 1));

% Create the horizontal bar plot
figure;
b = barh(x, y, 'FaceColor', 'flat');

% Assign colors
cmap = [1.0 0.4 0.4; 0.2 0.6 1.0]; % Blue for 1, Red for 0
for i = 1:length(colors)
    b.CData(i, :) = cmap(colors(i) + 1, :);
end

% Adjust axes for horizontal bar plot
ax = gca;
ax.YDir = 'normal'; % Ensure order is top-to-bottom as in data
ax.Box = 'off';

% Add labels and title (sentence case)
xlabel('Share of pandemics');
ylabel('Pathogen');
title('Relative pandemic emergence risk across pathogens');

% Add a custom legend manually
hold on;
dummy1 = plot(nan, nan, 's', 'Color', cmap(2, :), 'MarkerFaceColor', cmap(2, :));
dummy2 = plot(nan, nan, 's', 'Color', cmap(1, :), 'MarkerFaceColor', cmap(1, :));
legend([dummy1, dummy2], {'Has prototype vaccine', 'No prototype vaccine'}, ...
    'Location', 'southeast', 'FontSize', 10);
hold off;

print(gcf, fullfile("output/pandemic_pathogen_share_all.jpg"), '-djpeg', '-r600');
