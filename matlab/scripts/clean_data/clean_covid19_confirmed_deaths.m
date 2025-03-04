% clean_covid19_confirmed_deaths.m
%
% This script loads daily COVID-19 deaths data, cleans it, and calculates 
% the annual number of people who died from COVID-19 per 10,000 inhabitants.
% Note: The data contains individual daily values, not rolling averages.

% Load COVID-19 deaths data (daily deaths per million people)
covid_data = readtable('./data/raw/daily-new-confirmed-covid-19-deaths-per-million-people.csv', 'ReadVariableNames', false);
covid_data.Properties.VariableNames = {'entity', 'date', 'deaths_per_million'};

% Convert date strings to datetime
covid_data.date = datetime(covid_data.date, 'InputFormat', 'yyyy-MM-dd');

% Extract year from date
covid_data.year = year(covid_data.date);

% Filter for world data only
world_data = covid_data(strcmp(covid_data.entity, 'World'), :);

% Group by year and sum the daily deaths per million
annual_data = grpstats(world_data, 'year', {'sum'}, 'DataVars', 'deaths_per_million');
annual_data.Properties.VariableNames{3} = 'total_daily_deaths_per_million';

% Calculate annual deaths per 10,000 people
% Convert from per million to per 10,000 by dividing by 100
annual_data.deaths_per_10k = annual_data.total_daily_deaths_per_million / 100;

% Sort by year
annual_data = sortrows(annual_data, 'year');

% Plot deaths per 10,000 inhabitants over time
figure;
plot(annual_data.year, annual_data.deaths_per_10k, 'b-', 'LineWidth', 2);
hold on;
yline(0.01, 'r--', 'Threshold: 0.01 deaths per 10,000', 'LineWidth', 1.5);
title('COVID-19 Annual Deaths per 10,000');
xlabel('Year');
ylabel('Deaths per 10,000');
grid on;
hold off;

% Save the figure to output
saveas(gcf, './output/covid19_confirmed_deaths_per_10k_plot.png');

% Save the cleaned data
writetable(annual_data, './data/clean/covid19_deaths_per_10k.csv');
