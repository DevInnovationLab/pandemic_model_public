% Clean viral family data -- arrival rates and whether they already have vaccine R&D
% Arrival rates obtained from expert surves, vaccine status primarily obtained from CDC website.
% Run from command line with `matlab -batch "clean_viral_family_data"`

vf_data = readtable(fullfile("./data/raw/Viral family review - Viral family summary.csv"));

% Rename columns
vf_data.Properties.VariableNames = {...
    'viral_family', ...
    'arrival_share_all', ...
    'arrival_share_select', ... % Based on expert survey answers whose percentages (almost) summed to 100%.
    'has_prototype', ...
    'airborne' ...
    };

% Make viral families lower case
vf_data.viral_family = lower(vf_data.viral_family);

% Convert arrival rate shares to percentages
vf_data.arrival_share_all = str2double(erase(vf_data.arrival_share_all, "%")) ./ 100;
vf_data.arrival_share_select = str2double(erase(vf_data.arrival_share_select, "%")) ./ 100;

% Destring has advance R&D
has_prototype = NaN(height(vf_data), 1);
has_prototype(strcmpi(vf_data.has_prototype, "yes")) = true;
has_prototype(strcmpi(vf_data.has_prototype, "no")) = false;
vf_data.has_prototype = has_prototype;
vf_data.has_prototype = logical(vf_data.has_prototype);

% Check all had adv RD status
if ~islogical(vf_data.has_prototype) || any(~ismember(vf_data.has_prototype, [true, false]))
    error("has_prototype contains non-logical values.");
end

% Save arrival share distributions
arrival_share_sources = ["all", "select"];

for i = 1:numel(arrival_share_sources)
    source = arrival_share_sources(i);
    arrival_share_col = strcat("arrival_share_", source);
    
    % Create a list of columns to exclude (the arrival share columns)
    var_names = cellstr(vf_data.Properties.VariableNames);
    exclude_cols = strcat('arrival_share_', arrival_share_sources); 
    keep_cols = var_names(~ismember(var_names, exclude_cols));
    keep_cols = [arrival_share_col, keep_cols];

    % Subset and rename to arrival share
    clean_vf_data = vf_data(:, keep_cols);
    clean_vf_data.Properties.VariableNames{arrival_share_col} = 'arrival_share';

    fp = sprintf("./data/clean/vf_data_arrival_%s.csv", source);
    writetable(clean_vf_data, fp);
    
    % Create airborne dataset
    airborne_data = clean_vf_data(strcmpi(vf_data.airborne, 'Yes') | strcmpi(vf_data.airborne, 'Unknown'), :);
    
    % Reweight arrival shares to sum to 1
    airborne_data.arrival_share = airborne_data.arrival_share ./ sum(airborne_data.arrival_share);
    
    fp_airborne = sprintf("./data/clean/vf_data_arrival_%s_airborne.csv", source);
    writetable(airborne_data, fp_airborne);
end