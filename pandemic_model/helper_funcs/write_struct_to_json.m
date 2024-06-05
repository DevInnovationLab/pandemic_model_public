function write_struct_to_json(struct, filename)    
    % Check if the filename already has the .json extension
    [~, ~, ext] = fileparts(filename);
    if ~strcmp(ext, '.json')
        filename = [filename, '.json'];
    end
    
    fid = fopen(filename, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', filename);
    end

    % Convert struct to JSON string
    json_string = jsonencode(struct);
    
    % Write JSON string to file
    fprintf(fid, '%s', json_string);
    
    % Close the file
    fclose(fid);
end