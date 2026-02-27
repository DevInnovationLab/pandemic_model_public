% Cleans COVID19 mortality estimates from the Economist.
% https://ourworldindata.org/grapher/excess-deaths-cumulative-economist-single-entity
% Run from command line with `matlab -batch "clean_covid19_mortality"`

covid19_mortality = readtable("./data/raw/excess-deaths-cumulative-economist-single-entity.csv");

% Rename columns
covid19_mortality.Properties.VariableNames = {...
    'entity', ...
    'code', ...
    'day', ...
    'cum_excess_death_central', ...
    'cum_confirmed_covid19_morality', ...
    'cum_excess_death_upper', ...
    'cum_excess_death_lower'...
    };

% Remove dates after end of 2022 and get data for whole world
% Data starts Jan 1, 2022
covid19_mortality(covid19_mortality.day > datetime(2022, 12, 31), :) = [];
covid19_mortality(covid19_mortality.entity ~= "World", :) = [];

% Interpolate from weekly to daily
columns_to_interpolate = {'cum_excess_death_central', ...
                          'cum_excess_death_upper', ...
                          'cum_excess_death_lower'};

% Apply 'fillmissing' to each specified column using varfun
covid19_mortality(:, columns_to_interpolate) = varfun(@(x) fillmissing(x, 'linear'), ...
                                      covid19_mortality(:, columns_to_interpolate));

% Add a column for the year
covid19_mortality.Year = year(covid19_mortality.day);
covid19_mortality = sortrows(covid19_mortality, 'day');

% Get the last entry for each year
[unique_years, idx_last] = unique(covid19_mortality.Year, 'last');  % Get the last row for each year

% Extract the cumulative deaths at the last day of each year
cumulative_deaths_annual = covid19_mortality.cum_excess_death_central(idx_last);

% Compute the number of deaths per year by subtracting cumulative values
% deaths in the first year are just the cumulative deaths of that year
deaths_per_year = [cumulative_deaths_annual(1); 
                   diff(cumulative_deaths_annual)];

% Create a table with the results
yearly_deaths = table(unique_years, deaths_per_year, 'VariableNames', {'Year', 'Deaths'});

writetable(yearly_deaths, './data/clean/covid19_annual_excess_mortality_central_economist.csv');

%% Get COVID-19 intensity

% Load population data
population_data = readtable('./data/raw/population.csv', 'VariableNamingRule', 'preserve');

% Clean population data
% Rename columns for consistency
population_clean = population_data(:, {'Year', 'Population - Sex: all - Age: all - Variant: estimates'});
population_clean.Properties.VariableNames = {'Year', 'population'};

% Merge the datasets
merged_data = innerjoin(yearly_deaths, population_clean, 'Keys', 'Year');

% Calculate deaths per 10,000 inhabitants (intensity)
merged_data.intensity = (merged_data.Deaths ./ merged_data.population) * 10000;

% Plot deaths per 10,000 inhabitants over time
figure;
plot(merged_data.Year, merged_data.intensity, 'r-', 'LineWidth', 2);
title('COVID-19 Excess Deaths per 10,000');
xlabel('Year');
ylabel('Deaths per 10,000');
grid on;

% Save the figure to output
print(gcf, './output/covid19_deaths_per_10k_economist_plot', '-dpng', '-r600');

% Save the cleaned and merged data
writetable(merged_data, './data/clean/covid19_deaths_per_10k_economist.csv');
