function adv_RD_families = parse_rd_investments(rd_investment_config, vf_data)
    % Can pick specific diseases, random portfolio, and most profitable
    % Consider handling success probabilities in here

    baseline_RD_families = vf_data.viral_family(vf_data.has_adv_RD == true);
    eligible_idx = ~vf_data.has_adv_RD & ~strcmp(vf_data.viral_family, "unknown");
    vfd_no_adv_RD = vf_data(eligible_idx, :); % Get viral families that don't already have advanced R&D
    rd_strategy = rd_investment_config.strategy;

    if strcmp(rd_strategy, "none")
        adv_RD_families = baseline_RD_families;
    elseif strcmp(rd_strategy, "top")
        invest_num = rd_investment_config.num;
        assert(invest_num > 0, "Must invest in more than one viral family if rd_strategy is not none")
        sorted_vfs = sortrows(vfd_no_adv_RD, 'arrival_share', "descend");
        invest_num = min(invest_num, height(sorted_vfs)); % Don't invest in more than available
        new_invested_families = sorted_vfs.viral_family(1:invest_num);
        adv_RD_families = [baseline_RD_families; new_invested_families];
    elseif strcmp(rd_strategy, "random")
        invest_num = rd_investment_config.num;
        invest_num = min(invest_num, height(vfd_no_adv_RD)); % Don't invest in more than available
        shuffled_vfs = vfd_no_adv_RD(randperm(height(vfd_no_adv_RD)), :);
        new_invested_families = shuffled_vfs.viral_family(1:invest_num);
        adv_RD_families = [baseline_RD_families; new_invested_families];
    elseif strcmp(rd_strategy, "specific")
        new_invested_families = rd_investment_config.invest_families;

        if ~all(ismember(new_invested_families, vfd_no_adv_RD.viral_family))
            error("Viral family targeted for advance R&D not eligible.")
        end

        adv_RD_families = [baseline_RD_families; new_invested_families];
    end
end