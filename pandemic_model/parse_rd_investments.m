function adv_RD_families = parse_rd_investments(rd_investment_config, vf_data)
    % Can pick specific diseases, random portfolio, and most profitable

    baseline_RD_families = vf_data.viral_family(vf_data.has_adv_RD == true);
    eligible_idx = ~vf_data.has_adv_RD & ~strcmp(vf_data.viral_family, "unknown");
    vfd_no_adv_RD = vf_data(eligible_idx, :); % Get viral families that don't already have advanced R&D

    rd_strategy = rd_investment_config.strategy;

    if strcmp(rd_strategy, "top")
        invest_num = rd_investment_config.num;
        sorted_vfs = sortrows(vfd_no_adv_RD, 'arrival_share', "descend");
        new_invested_families = sorted_vfs.viral_family(1:invest_num);
        adv_RD_families = [baseline_RD_families; new_invested_families];
    elseif strcmp(rd_strategy, "random")
        invest_num = rd_investment_config.num;
        shuffled_vfs = vfd_no_adv_RD(randperm(height(vfd_no_adv_RD)), :); % This would require a lot of randomization
        new_invested_families = shuffled_vfs.viral_family(1:invest_num);
        adv_RD_families = [baseline_RD_families; new_invested_families];
    elseif strcmp(rd_strategy, "specific")
        new_invested_families = rd_investment_config.invest_families; % Make sure this is just a vector

        if ~all(ismember(vfd_no_adv_RD.viral_family, invest_families))
            error("Viral familiy targeted for advance R&D not eligible.")
        end

        adv_RD_families = [baseline_RD_families; new_invested_families];
    end
end