
vf_data = readtable("./data/clean/vf_data_arrival_all.csv");

vf_data = sortrows(vf_data, 'arrival_share', 'descend');
vf_data.viral_family = cellfun(@(x) strcat(upper(x(1)), lower(x(2:end))), vf_data.viral_family, 'UniformOutput', false); % Capitalize the first letter of each viral_family

% Prepare data for the bar plot
x = categorical(vf_data.viral_family);
x = reordercats(x, vf_data.viral_family); % Keep order as in the sorted table
y = vf_data.arrival_share;
colors = vf_data.has_adv_RD;

% Calculate total share of viral families with adv RD
total_adv_rd_share = sum(vf_data.arrival_share(vf_data.has_adv_RD == 1));

% Create the bar plot
figure;
b = bar(x, y, 'FaceColor', 'flat');

% Assign colors
cmap = [1.0 0.4 0.4; 0.2 0.6 1.0; 0.5 0.5 0.5]; % Blue for 1, Red for 0, Grey for "unknown"
for i = 1:length(colors)
    if strcmp(vf_data.viral_family{i}, 'Unknown') % Grey for "unknown"
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
ylabel('Share pandemics');
title('Viral family distribution of pandemics');

% Add a custom legend% Add a custom legend manually
hold on;
dummy1 = plot(nan, nan, 's', 'Color', cmap(1, :), 'MarkerFaceColor', cmap(1, :));
dummy2 = plot(nan, nan, 's', 'Color', cmap(2, :), 'MarkerFaceColor', cmap(2, :));
dummy3 = plot(nan, nan, 's', 'Color', cmap(3, :), 'MarkerFaceColor', cmap(3, :));
legend([dummy1, dummy2, dummy3], {'No prototype', 'Has prototype', 'Unknown'}, ...
    'Location', 'northeast', 'FontSize', 10);
hold off;

saveas(gca, fullfile("output/pandemic_viral_family_share_select.jpg"));
