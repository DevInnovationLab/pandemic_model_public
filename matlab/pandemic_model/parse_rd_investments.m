function [pathogens_with_baseline_prototype, new_invested_pathogens] = parse_rd_investments(rd_investment_config, pathogen_arrival_rates)
    % Can pick specific diseases, random portfolio, and most profitable
    % Consider handling success probabilities in here

    pathogens_with_baseline_prototype = pathogen_arrival_rates.pathogen(pathogen_arrival_rates.has_prototype == true);
    eligible_idx = ~pathogen_arrival_rates.has_prototype & ...
                   ~strcmpi(pathogen_arrival_rates.pathogen, "unknown_virus") & ...
                   ~strcmpi(pathogen_arrival_rates.pathogen, "other_known_virus");
    pathogens_no_prototype = pathogen_arrival_rates(eligible_idx, :); % Get viral families that don't already have advanced R&D
    rd_strategy = rd_investment_config.strategy;

    if strcmpi(rd_strategy, "none")
        new_invested_pathogens = [];
    elseif strcmpi(rd_strategy, "top")
        invest_num = rd_investment_config.num;
        assert(invest_num > 0, "Must invest in more than one pathogen if rd_strategy is not none")
        sorted_pathogens = sortrows(pathogens_no_prototype, 'estimate', "descend");
        invest_num = min(invest_num, height(sorted_pathogens)); % Don't invest in more than available
        new_invested_pathogens = sorted_pathogens.pathogen(1:invest_num);
    elseif strcmpi(rd_strategy, "random")
        invest_num = rd_investment_config.num;
        invest_num = min(invest_num, height(pathogens_no_prototype)); % Don't invest in more than available
        shuffled_pathogens = pathogens_no_prototype(randperm(height(pathogens_no_prototype)), :);
        new_invested_pathogens = shuffled_pathogens.pathogen(1:invest_num);
    elseif strcmpi(rd_strategy, "specific")
        new_invested_pathogens = rd_investment_config.invest_families;

        if ~all(ismember(new_invested_pathogens, pathogens_no_prototype.pathogen))
            error("Viral family targeted for advance R&D not eligible.")
        end
    else
        error("Invalid RD investment strategy.")
    end
end