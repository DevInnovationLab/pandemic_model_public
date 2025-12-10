function clean_config = clean_scenario_config(scenario_config)

    clean_config = struct();

    clean_config.neglected_pathogen_rd = scenario_config.neglected_pathogen_rd;
    clean_config.advance_capacity.share_target_advance_capacity = scenario_config.advance_capacity.share_target_advance_capacity;

    % Check universal flu R&D correctly configured
    universal_flu_rd  = scenario_config.universal_flu_rd;
    if universal_flu_rd.active && (isempty(universal_flu_rd.platform_response_invest) || isempty(universal_flu_rd.initial_share_ufv))
        error("Universal flu vaccine investment active but platform response investment or initial share is empty.");
    end

    if ~universal_flu_rd.active
        if (~isempty(universal_flu_rd.platform_response_invest) || ~isempty(universal_flu_rd.initial_share_ufv))
            warning("Universal flu vaccine investment inactive but platform response investment or initial share is not empty. Setting default values of none and zero.");
        end
        universal_flu_rd.platform_response_invest = "none";
        universal_flu_rd.initial_share_ufv = 0;
    end

    clean_config.universal_flu_rd = universal_flu_rd;

    % Check improved early warning parameter correctly configured
    improved_early_warning = scenario_config.improved_early_warning;
    if improved_early_warning.active && (isempty(improved_early_warning.precision) || isempty(improved_early_warning.recall))
        error("Improved early warning active but precision or recall is empty");
    end

    if ~improved_early_warning.active 
        if (~isempty(improved_early_warning.precision) || ~isempty(improved_early_warning.recall))
            warning("Improved early warning inactive but precision or recall is not empty. Setting default values of zero.");
        end

        improved_early_warning.precision = 0;
        improved_early_warning.recall = 0;
    end

    clean_config.improved_early_warning = improved_early_warning;
end