function create_folders_recursively(path)
    % Split the path into individual folders
    folders = strsplit(path, filesep);
    
    % Initialize an empty path
    currentPath = '';
    
    % Iterate over each folder and create it if it does not exist
    for i = 1:length(folders)
        currentPath = fullfile(currentPath, folders{i});
        if ~exist(currentPath, 'dir')
            mkdir(currentPath);
        end
    end
end