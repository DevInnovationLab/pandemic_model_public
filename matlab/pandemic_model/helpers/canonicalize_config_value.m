function serialized = canonicalize_config_value(value)
    % Serialize a config value for stable baseline identity keys (same logic as sensitivity manifest).

    if isstruct(value)
        fns = sort(fieldnames(value));
        parts = cell(length(fns), 1);
        for i = 1:length(fns)
            fn = fns{i};
            parts{i} = sprintf('%s:%s', fn, canonicalize_config_value(value.(fn)));
        end
        serialized = ['{' strjoin(parts, ',') '}'];
    elseif iscell(value)
        parts = cell(length(value), 1);
        for i = 1:length(value)
            parts{i} = canonicalize_config_value(value{i});
        end
        serialized = ['[' strjoin(parts, ',') ']'];
    elseif isnumeric(value) || islogical(value)
        serialized = mat2str(value);
    elseif isstring(value)
        serialized = ['"' char(value) '"'];
    elseif ischar(value)
        serialized = ['"' value '"'];
    else
        serialized = ['<' class(value) '>'];
    end
end
