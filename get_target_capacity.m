function [x_m, x_o] = get_target_capacity(params)
	% returns total amount of target capacity, by platform, in millions (params.x_target is in outright units)

	% target capacity
	x_m = params.mRNA_share * params.x_target / 10^6; % total target capacity mRNA
	x_o = (1-params.mRNA_share) * params.x_target / 10^6; % total target capacity traditional
	
end