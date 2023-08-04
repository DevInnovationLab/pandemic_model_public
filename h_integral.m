function [h_sum, vax_fraction_sum] = h_integral(params, state)

	%%% calculates the integral of h(hat_x(tau)) from tau=0 to tau=T
	
	taus = 1:params.T;

	h_sum = 0;
	vax_fraction_sum = 0;

    
    for ind = 1:length(taus)
        
        vax_fraction_sum0 =  vax_fraction_sum; % fraction of pop vaccinated at beginning of period
        
        tau = taus(ind);
        x_hat = production_capacity(tau, params, state) / params.P0;
		vax_fraction_sum = vax_fraction_sum + x_hat;

        if params.conservative == 1
            y = h(vax_fraction_sum0); % harm avoided is based on total fraction vaccinated at beginning of period (conservative)
        else
            y = h(vax_fraction_sum); % harm avoided is based on total fraction vaccinated up through the current period
        end
       
        h_sum = h_sum + y;
        
	end

end