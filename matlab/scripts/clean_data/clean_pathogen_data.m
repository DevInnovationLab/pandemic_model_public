% Clean pathogen data -- arrival rates and whether they already have vaccine R&D
% Arrival rates obtained from expert surves, vaccine status primarily obtained from CDC website.
% Run from command line with `matlab -batch "cleaned_pathogen_data"`

pathogen_data = readtable(fullfile("./data/raw/Viral family review - Viral family summary.csv"));

% Rename columns
pathogen_data.Properties.VariableNames = {...
    'pathogen', ...
    'viral_family', ...
    'arrival_share_all', ...
    'arrival_share_select', ... % Based on expert survey answers whose percentages (almost) summed to 100%.
    'has_prototype', ...
    'airborne' ...
    };

% Make viral families lower case
pathogen_data.pathogen = lower(strrep(pathogen_data.pathogen, ' ', '_'));

% Convert arrival rate shares to percentages
pathogen_data.arrival_share_all = str2double(erase(pathogen_data.arrival_share_all, "%")) ./ 100;
pathogen_data.arrival_share_select = str2double(erase(pathogen_data.arrival_share_select, "%")) ./ 100;

% Destring has advance R&D
has_prototype = NaN(height(pathogen_data), 1);
has_prototype(strcmpi(pathogen_data.has_prototype, "yes")) = true;
has_prototype(strcmpi(pathogen_data.has_prototype, "no")) = false;
pathogen_data.has_prototype = has_prototype;
pathogen_data.has_prototype = logical(pathogen_data.has_prototype);

% Check all had adv RD status
if ~islogical(pathogen_data.has_prototype) || any(~ismember(pathogen_data.has_prototype, [true, false]))
    error("has_prototype contains non-logical values.");
end

% Save arrival share distributions
arrival_share_sources = ["all", "select"];

for i = 1:numel(arrival_share_sources)
    source = arrival_share_sources(i);
    arrival_share_col = strcat("arrival_share_", source);
    
    % Create a list of columns to exclude (the arrival share columns)
    var_names = cellstr(pathogen_data.Properties.VariableNames);
    exclude_cols = strcat('arrival_share_', arrival_share_sources); 
    keep_cols = var_names(~ismember(var_names, exclude_cols));
    keep_cols = [arrival_share_col, keep_cols];

    % Subset and rename to arrival share
    cleaned_pathogen_data = pathogen_data(:, keep_cols);
    cleaned_pathogen_data.Properties.VariableNames{arrival_share_col} = 'arrival_share';

    fp = sprintf("./data/clean/pathogen_data_arrival_%s.csv", source);
    writetable(cleaned_pathogen_data, fp);
    
    % Create airborne dataset
    airborne_data = cleaned_pathogen_data(strcmpi(pathogen_data.airborne, 'Yes') | strcmpi(pathogen_data.airborne, 'Unknown'), :);
    
    % Reweight arrival shares to sum to 1
    airborne_data.arrival_share = airborne_data.arrival_share ./ sum(airborne_data.arrival_share);
    
    fp_airborne = sprintf("./data/clean/pathogen_data_arrival_%s_airborne.csv", source);
    writetable(airborne_data, fp_airborne);
end