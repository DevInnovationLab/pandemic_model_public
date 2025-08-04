function [z_m, z_o] = get_adv_capacity(params)

	% returns total amount of advance capacity, by platform, in millions
	tot_base_cap = params.base_cap_mrna + params.base_cap_trad;
	z_tot = (params.x_max_target - (1 - params.theta) .* tot_base_cap) .* params.share_target_advanced_capacity;
	z_m = params.mRNA_share * z_tot; % advance capacity mRNA
	z_o = (1-params.mRNA_share) * z_tot; % advance capacity traditional
end