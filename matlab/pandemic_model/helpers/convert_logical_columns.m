function tbl = convert_logical_columns(tbl)
    % Convert string 'TRUE'/'FALSE'/NA columns to numeric 1/0/NaN.
    %
    % Applies to the columns has_prototype and airborne, which may be read as
    % strings when loaded from CSV via readtable. This normalizes them to
    % numeric values (1 = TRUE, 0 = FALSE/NA) for downstream computation.
    %
    % Args:
    %   tbl (table): Input table with possible string logical columns.
    %
    % Returns:
    %   tbl (table): Table with logical columns converted to numeric.

    logical_colnames = {'has_prototype', 'airborne'};
    for i = 1:length(logical_colnames)
        col = logical_colnames{i};
        if ismember(col, tbl.Properties.VariableNames)
            col_data = tbl.(col);
            col_str = string(col_data);
            col_numeric = nan(height(tbl), 1);
            col_numeric(strcmpi(col_str, "TRUE")) = 1;
            col_numeric(strcmpi(col_str, "FALSE")) = 0;
            col_numeric(strcmpi(col_str, "NA")) = 0;
            tbl.(col) = col_numeric;
        end
    end
end
