function [adv_cap_mrna, adv_cap_trad] = get_adv_capacity(params)
    % Total target capacity per platform for the advance investment program.
    % Uses reference max (params.max_capacity): gap to this level defines the program.
    % Simulation ceiling may differ; see params.deployable_max_capacity in event_list_simulation.
    max_cap_mrna = params.mRNA_share .* params.max_capacity;
    max_cap_trad = (1 - params.mRNA_share) .* params.max_capacity;

    % Capacity gap per platform (floored at zero)
    gap_mrna = max(0, max_cap_mrna - params.base_cap_mrna);
    gap_trad = max(0, max_cap_trad - params.base_cap_trad);
    total_gap = gap_mrna + gap_trad;

    % Total advance capacity = share of total gap
    total_adv_cap = params.advance_capacity.share_target_advance_capacity .* total_gap;

    % Allocate in proportion to each platform's gap
    if total_gap > 0
        adv_cap_mrna = total_adv_cap .* (gap_mrna / total_gap);
        adv_cap_trad = total_adv_cap .* (gap_trad / total_gap);
    else
        adv_cap_mrna = 0;
        adv_cap_trad = 0;
    end
end