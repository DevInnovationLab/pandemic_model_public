function [adv_cap_mrna, adv_cap_trad] = get_adv_capacity(params)

	% returns total amount of advance capacity, by platform, in millions
	max_cap_mrna = params.mRNA_share .* params.max_capacity; % total target capacity mRNA
	max_cap_trad = (1-params.mRNA_share) * params.max_capacity; % total target capacity traditional

	assert(max_cap_mrna >= params.base_cap_mrna, "mRNA max capacity is less than base capacity");
	assert(max_cap_trad >= params.base_cap_trad, "traditional max capacity is less than base capacity");

	adv_cap_mrna = params.advance_capacity.share_target_advance_capacity .* (max_cap_mrna - params.base_cap_mrna);
	adv_cap_trad = params.advance_capacity.share_target_advance_capacity .* (max_cap_trad - params.base_cap_trad);
end