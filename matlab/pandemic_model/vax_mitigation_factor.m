function y = vax_mitigation_factor(vax_fractions)
    % Piecewise linear vaccination damage mitigation factor (the "h" function).
    % Maps vaccination coverage fraction to the fraction of harm mitigated.
    % Per footnote 17 of IMF paper, the function is pinned at:
    %   h(0    ) = 0
    %   h(0.13 ) = 0.395
    %   h(0.5  ) = 0.816
    %   h(>=0.7) = 1
	
	% Validate inputs 
	assert(all(vax_fractions >= 0 | vax_fractions <= 1, 'all'))

	% Initialize constants and output container
	slope_1 = 3.038462;
    slope_2 = 1.137838;
    slope_3 = 0.92;
	intercept_2 = 0.395;
    intercept_3 = 0.816;
	y = zeros(size(vax_fractions));
	
	% Segment masks
	mask1 = vax_fractions <= 0.13;
	mask2 = vax_fractions > 0.13 & vax_fractions <= 0.5;
	mask3 = vax_fractions > 0.5 & vax_fractions <= 0.7;
	mask4 = vax_fractions > 0.7;

	% Apply piecewise linear function
	y(mask1) = slope_1 * vax_fractions(mask1);
	y(mask2) = intercept_2 + slope_2 * (vax_fractions(mask2) - 0.13);
	y(mask3) = intercept_3 + slope_3 * (vax_fractions(mask3) - 0.5);
	y(mask4) = 1;
end