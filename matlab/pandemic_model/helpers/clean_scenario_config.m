function clean_config = clean_scenario_config(scenario_config)
    % Extract and validate scenario-specific fields from a raw scenario config struct.
    %
    % Normalises the raw YAML-loaded scenario config into a clean struct, applying
    % defaults and validating required sub-fields for each intervention type.
    %
    % Args:
    %   scenario_config  Struct loaded from a scenario YAML file. Must contain:
    %                    neglected_pathogen_rd, advance_capacity,
    %                    universal_flu_rd, improved_early_warning.
    %
    % Returns:
    %   clean_config  Struct with validated sub-structs: neglected_pathogen_rd,
    %                 advance_capacity, universal_flu_rd, improved_early_warning.

    clean_config = struct();

    clean_config.neglected_pathogen_rd = scenario_config.neglected_pathogen_rd;
    clean_config.advance_capacity.share_target_advance_capacity = scenario_config.advance_capacity.share_target_advance_capacity;

    clean_config.universal_flu_rd = ensure_intervention_fields( ...
        scenario_config.universal_flu_rd, ...
        {'active', 'platform_response_invest'}, ...
        struct('active', false, 'platform_response_invest', "none"));

    clean_config.improved_early_warning = ensure_intervention_fields( ...
        scenario_config.improved_early_warning, ...
        {'active'}, ...
        struct('active', false));
end


function cfg = ensure_intervention_fields(cfg, required_fields, defaults)
    % Ensure intervention sub-struct has expected fields, filling defaults.
    for i = 1:length(required_fields)
        f = required_fields{i};
        if ~isfield(cfg, f)
            cfg.(f) = defaults.(f);
        end
    end
end