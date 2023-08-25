function [h_arr, vax_fraction_cum] = h_integral(params, tot_months, cap_m_arr, cap_o_arr)

	%%% calculates two arrays: h_arr is the vector of harm pct avoided; vax_fraction_cum is vector of frac of pop vaccinated at end of each period

	h_arr = zeros(tot_months, 1);
	vax_fraction_cum = zeros(tot_months, 1);

    vax_fraction_sum = 0;
    
    for tau = 1:tot_months        
        vax_fraction_sum0 =  vax_fraction_sum; % fraction of pop vaccinated at beginning of period
        
        x_tot = (cap_m_arr(tau) + cap_o_arr(tau)); % in million
        x_hat = x_tot * 10^6/ params.P0;
		vax_fraction_sum = vax_fraction_sum + x_hat; % fraction of pop vaccinated at end of period

        if params.conservative == 1
            y = h(vax_fraction_sum0); % harm avoided is based on total fraction vaccinated at beginning of period (conservative)
        else
            y = h(vax_fraction_sum); % harm avoided is based on total fraction vaccinated up through the current period
        end
       
        vax_fraction_cum(tau) = vax_fraction_sum;

        h_arr(tau) = y;
	end

end