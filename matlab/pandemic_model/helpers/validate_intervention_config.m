function cfg = validate_intervention_config(cfg, name, required_fields, defaults)
% Validate and clean an intervention config struct.
%
% If active: errors if any required field is empty.
% If inactive: warns if any field is non-empty, then resets all to defaults.
%
% Args:
%   cfg:             Intervention config struct (must have .active field)
%   name:            Display name for error/warning messages
%   required_fields: Cell array of field names that must be non-empty when active
%   defaults:        Struct with default values for each required field (used when inactive)
    if cfg.active
        for i = 1:length(required_fields)
            if isempty(cfg.(required_fields{i}))
                error('%s active but field ''%s'' is empty.', name, required_fields{i});
            end
        end
    else
        any_nonempty = any(cellfun(@(f) ~isempty(cfg.(f)), required_fields));
        if any_nonempty
            warning('%s inactive but some fields are non-empty. Resetting to defaults.', name);
        end
        for i = 1:length(required_fields)
            cfg.(required_fields{i}) = defaults.(required_fields{i});
        end
    end
end
