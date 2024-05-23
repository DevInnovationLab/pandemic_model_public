function y = h(vax_fraction_sum)

    % per footnote 17 of IMF paper, the h function is specified as a
    % piecewise linear function pinned down by
    % h(0    ) = 0
    % h(0.13 ) = .395
    % h(0.5  ) = .816
    % h(>=0.7) = 1
    slope_1 = 3.038462;
    
    slope_2 = 1.137838;
    intercept_2 = 0.247081;

    slope_3 = 0.92;
    intercept_3 = 0.356000;

    if vax_fraction_sum <= 0.13
		y = 0 + slope_1 * vax_fraction_sum;
	elseif vax_fraction_sum <= 0.5
		y = intercept_2 + slope_2 * vax_fraction_sum;
    elseif vax_fraction_sum <= 0.7
		y = intercept_3 + slope_3 * vax_fraction_sum;
	else
		y = 1;
    end

end