function out = resolve_dir_absolute(dir_path)
    % Return absolute path string for an existing directory (for stable manifest paths).
    %
    % Args:
    %   dir_path  Path to a directory that exists on disk.

    dir_path = char(string(dir_path));
    if ~isfolder(dir_path)
        error('Directory does not exist: %s', dir_path);
    end
    [ok, info] = fileattrib(dir_path);
    if ~ok
        error('Could not resolve directory: %s', dir_path);
    end
    out = info.Name;
end
