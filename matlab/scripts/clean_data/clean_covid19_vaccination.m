cum_vaccinations = readtable("./data/raw/share-of-people-who-completed-the-initial-covid-19-vaccination-protocol");
cum_vaccinations.Properties.VariableNames = ["entity", "day", "cum_vax_share"];
cum_vaccinations.day = datetime(cum_vaccinations.day, 'InputFormat', 'yyyy-MM-dd');
cum_vaccinations.cum_vax_share = cum_vaccinations.cum_vax_share / 100;

% Get global vaccinations
world_cum_vaccinations = cum_vaccinations(strcmp(cum_vaccinations.entity, "World"), :);
months_years = unique(year(world_cum_vaccinations.day) * 100 + month(world_cum_vaccinations.day));

% Initialize results
mid_month_vax = table();

for i = 1:length(months_years)
    % Extract year and month
    year_month = months_years(i);
    year_val = floor(year_month / 100);
    month_val = mod(year_month, 100);
    
    % Get all rows for the current month
    this_month_data = world_cum_vaccinations(year(world_cum_vaccinations.day) == year_val & ...
                                              month(world_cum_vaccinations.day) == month_val, :);
    
    % Skip if no data available for the month
    if isempty(this_month_data)
        continue;
    end
    
    % Calculate the middle date of the month
    start_of_month = datetime(year_val, month_val, 1);
    end_of_month = dateshift(start_of_month, 'end', 'month');
    mid_date = start_of_month + days(floor(days(end_of_month - start_of_month) / 2));
    
    % Interpolate the vaccination share for the mid-date
    this_month_data_sorted = sortrows(this_month_data, 'day');
    interp_vax = interp1(datenum(this_month_data_sorted.day), ...
                         this_month_data_sorted.cum_vax_share, ...
                         datenum(mid_date), ...
                         'linear', 'extrap');
    
    % Append results
    mid_month_vax = [mid_month_vax; {mid_date, interp_vax}]; %#ok<AGROW>
end

% Sort the year-month combinations
months_years = sort(months_years);

% Check for contiguous months
differences = diff(months_years);
if all(differences == 1 | differences == 89) % 1 for same year, 88 for year transitions (e.g., Dec to Jan)
    disp('Year-months are contiguous.');
else
    disp('Year-months are not contiguous.');
end

% Output vaccination trend
mid_month_vax.Properties.VariableNames = ["date", "cum_vax_rate"];
mid_month_vax.rollout_month = (1:size(mid_month_vax, 1))';

writetable(mid_month_vax, "./data/clean/covid19_cum_vax_over_time.csv")