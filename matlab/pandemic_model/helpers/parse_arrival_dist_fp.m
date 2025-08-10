function meta = parse_arrival_dist_fp(fp)
% Parse metadata from an arrival distribution filename into a struct.
%
%   meta = parse_arrival_dist_fp(fp)
%
%   Parses a filename of the form:
%   gpd_<scope>_filt_<filt_measure>_fit_<fit_measure>_<lower_threshold>_<year_min>_poisson_sharp_upper_<trunc>_n_<n>_seed_<seed>.yaml
%
%   Args:
%       fp (char or string): Path to the arrival distribution file.
%
%   Returns:
%       meta (struct): Struct with fields:
%           - scope (char)
%           - filt_measure (char)
%           - fit_measure (char)
%           - lower_threshold (double)
%           - year_min (double)
%           - trunc (double)
%           - n (double)
%           - seed (double)
%           - dist_type (char)
%           - arrival_dist_type (char)
%           - trunc_type (char)
%
%   Raises:
%       Error if the filename does not match the expected format.

    % Get the file stem (filename without extension)
    [~, stem, ~] = fileparts(fp);

    % Split the filename by underscores
    parts = strsplit(stem, '_');
    meta.scope = parts{2};

    % Filter measure is the part after 'filt'
    filt_measure_raw = parts{4};
    filt_measure_map = struct('sev', 'severity', 'int', 'intensity', ...
                              'severity', 'severity', 'intensity', 'intensity');
    if isfield(filt_measure_map, filt_measure_raw)
        meta.filt_measure = filt_measure_map.(filt_measure_raw);
    else
        meta.filt_measure = filt_measure_raw;
    end

    % Find the index of 'fit'
    fit_idx = find(strcmp(parts, 'fit'), 1);
    if isempty(fit_idx)
        error('Filename must contain ''fit'' token.');
    end

    % Fit measure is the part after 'fit'
    fit_measure_raw = parts{6};
    if isfield(filt_measure_map, fit_measure_raw)
        meta.fit_measure = filt_measure_map.(fit_measure_raw);
    else
        meta.fit_measure = fit_measure_raw;
    end

    % The lower_threshold and year_min are after the fit_measure
    lower_threshold_str = parts{7};
    year_min_str = parts{8};

    % Convert lower_threshold (replace 'd' with '.')
    meta.lower_threshold = str2double(strrep(lower_threshold_str, 'd', '.'));
    meta.year_min = str2double(year_min_str);

    % Find the index of 'upper', 'n', and 'seed'
    upper_idx = find(strcmp(parts, 'upper'), 1);
    n_idx = find(strcmp(parts, 'n'), 1);
    seed_idx = find(strcmp(parts, 'seed'), 1);

    meta.trunc_value = str2double(parts{upper_idx + 1});
    meta.n = str2double(parts{n_idx + 1});
    meta.seed = str2double(parts{seed_idx + 1});

    % Poisson type (e.g., 'poisson')
    % Find the index of 'poisson' if present
    meta.arrival_dist_type = parts{9};
    meta.trunc_type = parts{10};
end
