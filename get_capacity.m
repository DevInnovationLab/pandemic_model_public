function [x_m x_o z_m z_o] = get_capacity(has_adv_cap, params)

	% returns total amount of advance and target capacity, by platform, in outright units

	if has_adv_cap == 1
		x_tot = params.x_target; % total desired capacity, annualized
		x_m = params.mRNA_share * x_tot; % total capacity mRNA
		x_o = (1-params.mRNA_share) * x_tot; % total capacity traditional

		z_tot = params.x_target - (1-params.theta) * params.x_avail; % total advance capacity, annualized
		z_m = params.mRNA_share * z_tot; % advance capacity mRNA
		z_o = (1-params.mRNA_share) * z_tot; % advance capacity traditional
	else
		x_tot = params.x_avail; % total desired capacity, annualized
		x_m = params.mRNA_share * x_tot; % total capacity mRNA
		x_o = (1-params.mRNA_share) * x_tot; % total capacity traditional

		z_m = 0;
		z_o = 0;
	end

end