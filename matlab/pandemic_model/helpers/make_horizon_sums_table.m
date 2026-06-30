function sums_table = make_horizon_sums_table(annual_results, sum_horizons, num_simulations)
% Build a per-simulation horizon-sums table from an annual-results struct.
%
% For each field in annual_results, produces columns:
%   <field>_<h>_years  for each h in sum_horizons
%   <field>_full       sum over all periods
%
% Args:
%   annual_results:  struct where each field is a num_simulations x num_periods matrix
%   sum_horizons:    numeric vector of horizon lengths (e.g. [10 30 50])
%   num_simulations: number of rows in each matrix
%
% Returns:
%   sums_table: table with num_simulations rows
    result_names = fieldnames(annual_results);
    num_horizons = length(sum_horizons) + 1;
    num_cols = length(result_names) * num_horizons;

    sums_table = table('Size', [num_simulations, num_cols], ...
        'VariableTypes', repmat({'double'}, 1, num_cols));

    for j = 1:length(result_names)
        result = result_names{j};
        data = annual_results.(result);
        col_idx = (j - 1) * num_horizons + 1;
        for k = 1:length(sum_horizons)
            h = sum_horizons(k);
            sums_table.Properties.VariableNames{col_idx} = strcat(result, '_', num2str(h), '_years');
            sums_table{:, col_idx} = sum(data(:, 1:h), 2);
            col_idx = col_idx + 1;
        end
        sums_table.Properties.VariableNames{col_idx} = strcat(result, '_full');
        sums_table{:, col_idx} = sum(data, 2);
    end
end
