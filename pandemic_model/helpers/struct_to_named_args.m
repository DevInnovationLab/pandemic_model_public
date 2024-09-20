% Convert a struct to a cell array of name-value pairs
function cell_array = struct_to_named_args(s)
    cell_array = [fieldnames(s), struct2cell(s)].';
end