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

    clean_config.universal_flu_rd = validate_intervention_config( ...
        scenario_config.universal_flu_rd, 'Universal flu vaccine investment', ...
        {'platform_response_invest', 'initial_share_ufv'}, ...
        struct('platform_response_invest', "none", 'initial_share_ufv', 0));

    clean_config.improved_early_warning = validate_intervention_config( ...
        scenario_config.improved_early_warning, 'Improved early warning', ...
        {'precision', 'recall'}, ...
        struct('precision', 0, 'recall', 0));
end