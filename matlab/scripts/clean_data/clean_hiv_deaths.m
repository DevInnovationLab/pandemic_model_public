% clean_hiv_deaths.m
%
% This script loads HIV/AIDS deaths data and population data, cleans and merges them,
% and calculates the annual number of people who died from HIV/AIDS per 10,000 inhabitants.

% Load HIV/AIDS deaths data
hiv_data = readtable('./data/raw/hiv-aids-deaths.csv');
population_data = readtable('./data/raw/population.csv', 'VariableNamingRule', 'preserve');

% Extract relevant columns: year and number of deaths
hiv_clean = hiv_data(:, {'year', 'val'});
hiv_clean.Properties.VariableNames = {'year', 'deaths'};

% Clean population data
% Rename columns for consistency
population_clean = population_data(:, {'Year', 'Population - Sex: all - Age: all - Variant: estimates'});
population_clean.Properties.VariableNames = {'year', 'population'};

% Merge the datasets
merged_data = innerjoin(hiv_clean, population_clean, 'Keys', 'year')

% Calculate deaths per 10,000 inhabitants
merged_data.severity = (merged_data.deaths ./ merged_data.population) * 10000;

% Sort by year
merged_data = sortrows(merged_data, 'year');

% Plot deaths per 10,000 inhabitants over time
figure;
plot(merged_data.year, merged_data.severity, 'b-', 'LineWidth', 2);
hold on;
yline(0.01, 'r--', 'Threshold: 0.01 deaths per 10,000', 'LineWidth', 1.5);
title('HIV/AIDS Deaths per 10,000');
xlabel('Year');
ylabel('Deaths per 10,000');
grid on;
hold off;

% Save the figure to output
saveas(gcf, './output/hiv_deaths_per_10k_plot.png');

% Save the cleaned and merged data
writetable(merged_data, './data/clean/hiv_deaths_per_10k.csv');
