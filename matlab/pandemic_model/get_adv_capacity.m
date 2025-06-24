function [z_m, z_o] = get_adv_capacity(params)

	% returns total amount of advance capacity, by platform, in millions
	z_tot = (params.x_max_target - (1 - params.theta) .* params.x_avail) .* params.share_target_advanced_capacity;
	z_m = params.mRNA_share * z_tot; % advance capacity mRNA
	z_o = (1-params.mRNA_share) * z_tot; % advance capacity traditional
end