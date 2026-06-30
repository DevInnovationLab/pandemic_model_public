function create_folders_recursively(path)
% Create a directory and all necessary parent directories.
% No-op if the directory already exists.
    if ~exist(path, 'dir')
        parent = fileparts(path);
        if ~isempty(parent) && ~exist(parent, 'dir')
            create_folders_recursively(parent);
        end
        mkdir(path);
    end
end
