function meta = parse_arrival_dist_fp(fp)
% Parse metadata from an arrival distribution filename into a struct.
%
%   meta = parse_arrival_dist_fp(fp)
%
%   Parses filenames of either form:
%   gpd_<scope>_filt_<filt_measure>_fit_<fit_measure>_<lower_threshold>_<year_min>_<arrival_dist>_<trunc_method>_upper_<upper>_n_<n>_seed_<seed>.yaml
%   gpd_<scope>_(incl_unid|excl_unid)_filt_<filt_measure>_fit_<fit_measure>_<lower_threshold>_<year_min>_<arrival_dist>_<trunc_method>_upper_<upper>_n_<n>_seed_<seed>.yaml
%
%   Notes:
%   - The optional unid flag appears as two underscore-delimited tokens in the
%     filename: 'incl_unid' -> {'incl','unid'}, 'excl_unid' -> {'excl','unid'}.
%
%   Args:
%       fp (char or string): Path to the arrival distribution file.
%
%   Returns:
%       meta (struct): Struct with fields:
%           - scope (char)
%           - has_unid_token (logical)
%           - incl_unid (logical or [])
%           - unid_status (char or "")
%           - filt_measure (char)
%           - fit_measure (char)
%           - lower_threshold (double)
%           - year_min (double)
%           - arrival_dist_type (char)
%           - trunc_method (char)
%           - trunc_type (char) (same as trunc_method; retained for compatibility)
%           - trunc_value (double) (upper bound)
%           - n (double)
%           - seed (double)
%
%   Raises:
%       Error if the filename does not match the expected format.

    % Get the file stem (filename without extension)
    [~, stem, ~] = fileparts(fp);

    % Split the filename by underscores
    parts = strsplit(stem, '_');

    meta.scope = parts{2};

    % Optional incl_unid/excl_unid token pair immediately after scope
    meta.has_unid_token = false;
    meta.incl_unid = [];
    meta.unid_status = "";
    if numel(parts) >= 4 && any(strcmp(parts{3}, {'incl', 'excl'})) && strcmp(parts{4}, 'unid')
        meta.has_unid_token = true;
        meta.incl_unid = strcmp(parts{3}, 'incl');
        meta.unid_status = sprintf('%s_unid', parts{3});
    end

    % Map short names to canonical measure strings
    measure_map = struct( ...
        'sev', 'severity', ...
        'int', 'intensity', ...
        'severity', 'severity', ...
        'intensity', 'intensity' ...
    );

    % Parse based on tokens to avoid brittle fixed indices
    filt_idx = find(strcmp(parts, 'filt'), 1);
    if isempty(filt_idx) || filt_idx + 1 > numel(parts)
        error('Filename must contain ''filt_<measure>'' token pair; got stem: %s', stem);
    end

    fit_idx = find(strcmp(parts, 'fit'), 1);
    if isempty(fit_idx) || fit_idx + 3 > numel(parts)
        error('Filename must contain ''fit_<measure>_<lower_threshold>_<year_min>''; got stem: %s', stem);
    end

    % Filter measure is the part after 'filt'
    filt_measure_raw = parts{filt_idx + 1};
    if isfield(measure_map, filt_measure_raw)
        meta.filt_measure = measure_map.(filt_measure_raw);
    else
        meta.filt_measure = filt_measure_raw;
    end

    % Fit measure is the part after 'fit'
    fit_measure_raw = parts{fit_idx + 1};
    if isfield(measure_map, fit_measure_raw)
        meta.fit_measure = measure_map.(fit_measure_raw);
    else
        meta.fit_measure = fit_measure_raw;
    end

    % The lower_threshold and year_min are after the fit_measure
    lower_threshold_str = parts{fit_idx + 2};
    year_min_str = parts{fit_idx + 3};

    meta.lower_threshold = str2double(strrep(lower_threshold_str, 'd', '.'));
    meta.year_min = str2double(year_min_str);
    if isnan(meta.lower_threshold) || isnan(meta.year_min)
        error('Could not parse lower_threshold/year_min from stem: %s', stem);
    end

    % Arrival distribution and truncation method are the next two tokens after year_min
    meta.arrival_dist_type = "";
    meta.trunc_method = "";
    meta.trunc_type = ""; % retained for callers that expect trunc_type
    if fit_idx + 4 <= numel(parts)
        meta.arrival_dist_type = parts{fit_idx + 4};
    end
    if fit_idx + 5 <= numel(parts)
        meta.trunc_method = parts{fit_idx + 5};
        meta.trunc_type = meta.trunc_method;
    end

    % Find the index of 'upper', 'n', and 'seed'
    upper_idx = find(strcmp(parts, 'upper'), 1);
    n_idx = find(strcmp(parts, 'n'), 1);
    seed_idx = find(strcmp(parts, 'seed'), 1);

    if isempty(upper_idx) || upper_idx + 1 > numel(parts)
        error('Filename must contain ''upper_<value>'' token pair; got stem: %s', stem);
    end
    if isempty(n_idx) || n_idx + 1 > numel(parts)
        error('Filename must contain ''n_<value>'' token pair; got stem: %s', stem);
    end
    if isempty(seed_idx) || seed_idx + 1 > numel(parts)
        error('Filename must contain ''seed_<value>'' token pair; got stem: %s', stem);
    end

    meta.trunc_value = str2double(parts{upper_idx + 1});
    meta.n = str2double(parts{n_idx + 1});
    meta.seed = str2double(parts{seed_idx + 1});

    if isnan(meta.trunc_value) || isnan(meta.n) || isnan(meta.seed)
        error('Could not parse upper/n/seed numeric values from stem: %s', stem);
    end
end
