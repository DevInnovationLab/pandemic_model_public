function cell_array = struct_to_named_args(s)
    % Convert a struct to a flat cell array of name-value pairs.
    %
    % Args:
    %   s  Struct with any fields.
    %
    % Returns:
    %   cell_array  1 x 2N cell: {name1, val1, name2, val2, ...}.
    cell_array = [fieldnames(s), struct2cell(s)].';
end