function pathogens_with_prototype = parse_rd_investments(rd_investment_config, pathogen_data)
    % Can pick specific diseases, random portfolio, and most profitable
    % Consider handling success probabilities in here

    baseline_RD_families = pathogen_data.pathogen(pathogen_data.has_prototype == true);
    eligible_idx = ~pathogen_data.has_prototype & ~strcmpi(pathogen_data.pathogen, "unknown", '');
    vfd_no_prototype = pathogen_data(eligible_idx, :); % Get viral families that don't already have advanced R&D
    rd_strategy = rd_investment_config.strategy;

    if strcmpi(rd_strategy, "none")
        pathogens_with_prototype = baseline_RD_families;
    elseif strcmpi(rd_strategy, "top")
        invest_num = rd_investment_config.num;
        assert(invest_num > 0, "Must invest in more than one viral family if rd_strategy is not none")
        sorted_vfs = sortrows(vfd_no_prototype, 'arrival_share', "descend");
        invest_num = min(invest_num, height(sorted_vfs)); % Don't invest in more than available
        new_invested_families = sorted_vfs.pathogen(1:invest_num);
        pathogens_with_prototype = [baseline_RD_families; new_invested_families];
    elseif strcmpi(rd_strategy, "random")
        invest_num = rd_investment_config.num;
        invest_num = min(invest_num, height(vfd_no_prototype)); % Don't invest in more than available
        shuffled_vfs = vfd_no_prototype(randperm(height(vfd_no_prototype)), :);
        new_invested_families = shuffled_vfs.pathogen(1:invest_num);
        pathogens_with_prototype = [baseline_RD_families; new_invested_families];
    elseif strcmpi(rd_strategy, "specific")
        new_invested_families = rd_investment_config.invest_families;

        if ~all(ismember(new_invested_families, vfd_no_prototype.pathogen))
            error("Viral family targeted for advance R&D not eligible.")
        end

        pathogens_with_prototype = [baseline_RD_families; new_invested_families];
    end
end