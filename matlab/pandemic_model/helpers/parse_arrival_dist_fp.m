function meta = parse_arrival_dist_fp(fp)
% Parse metadata from a GPD arrival distribution directory stem (see docs/naming_convention.md).
%
%   {lineage}__filt__{filter_slug}__arr__gpd_{fit}_{arrival}_{trunc}_u{U}_n{n}_s{seed}
%
% Mirrors Python parse_arrival_dist_id / pandemic_statistics.pipeline_names.parse_arrival_dir_stem.

    if isstring(fp)
        fp = char(fp);
    end

    [~, stem, ~] = fileparts(fp);

    if ~contains(stem, "__arr__")
        error("pandemic_model:parse_arrival_dist_fp:BadStem", ...
            "Arrival stem must contain __arr__, got: %s", stem);
    end

    parts = split(stem, "__arr__");
    head = parts{1};
    arr_tail = parts{2};

    filt_parts = split(head, "__filt__");
    if numel(filt_parts) ~= 2
        error("pandemic_model:parse_arrival_dist_fp:BadStem", ...
            "Expected {lineage}__filt__{filter_slug}, got: %s", stem);
    end

    lineage = filt_parts{1};
    filter_slug = filt_parts{2};
    meta.lineage = lineage;
    meta.filter_slug = filter_slug;

    pf = parse_filter_slug_mex(filter_slug);
    meta.scope = pf.scope;
    meta.filt_measure = pf.filt_measure;
    meta.lower_threshold = pf.lower_threshold;
    meta.year_min = pf.year_min;
    meta.incl_unid = pf.incl_unid;
    meta.year_thresh_only = pf.year_thresh_only;

    meta.has_unid_token = ~isempty(strfind(filter_slug, "_incl_unid"));
    if meta.incl_unid
        meta.unid_status = "incl_unid";
    else
        meta.unid_status = "excl_unid";
    end

    if ~startsWith(arr_tail, "gpd_")
        error("pandemic_model:parse_arrival_dist_fp:BadTail", ...
            "Expected gpd_ tail, got: %s", arr_tail);
    end
    rest = extractAfter(arr_tail, "gpd_");

    tok = regexp(rest, '^(?<fit>.+?)_(?<arrival>[a-z][a-z0-9]*)_(?<trunc>[^_]+)_u(?<u>[^_]+)_n(?<n>\d+)_s(?<s>\d+)$', 'names');
    if isempty(tok)
        error("pandemic_model:parse_arrival_dist_fp:BadGpd", ...
            "Could not parse GPD tail: %s", rest);
    end

    meta.fit_measure = tok.fit;
    meta.arrival_dist_type = string(tok.arrival);
    meta.trunc_method = tok.trunc;
    meta.trunc_type = meta.trunc_method;
    meta.trunc_value = str2double(tok.u);
    meta.n = str2double(tok.n);
    meta.seed = str2double(tok.s);

    if isnan(meta.trunc_value) || isnan(meta.n) || isnan(meta.seed)
        error("pandemic_model:parse_arrival_dist_fp:BadNumber", ...
            "Non-numeric upper/n/seed in: %s", arr_tail);
    end
end

function pf = parse_filter_slug_mex(slug)
% Parse filter slug like all_int_0d01_1900 with optional trailing flags.
    parts = strsplit(slug, '_');
    incl_unid = false;
    year_thresh_only = false;

    while numel(parts) >= 1
        last = parts{end};
        if strcmp(last, "yearthreshonly")
            year_thresh_only = true;
            parts = parts(1:end-1);
            continue;
        end
        if numel(parts) >= 2 && strcmp(parts{end-1}, "incl") && strcmp(parts{end}, "unid")
            incl_unid = true;
            parts = parts(1:end-2);
            continue;
        end
        break;
    end

    if numel(parts) ~= 4
        error("pandemic_model:parse_arrival_dist_fp:BadFilterSlug", ...
            "Expected 4 core tokens in filter slug, got: %s", slug);
    end

    scope = parts{1};
    fm = parts{2};
    lth = parts{3};
    ymn = parts{4};

    fm_map = struct('sev', "severity", 'int', "intensity");
    if isfield(fm_map, fm)
        filt_measure = fm_map.(fm);
    else
        filt_measure = fm;
    end

    lower_threshold = str2double(strrep(lth, 'd', '.'));
    year_min = str2double(ymn);

    pf.scope = scope;
    pf.filt_measure = filt_measure;
    pf.lower_threshold = lower_threshold;
    pf.year_min = year_min;
    pf.incl_unid = incl_unid;
    pf.year_thresh_only = year_thresh_only;
end
