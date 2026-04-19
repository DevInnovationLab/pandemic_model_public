function y = h_function(vax_fractions)
    % Piecewise linear vaccination damage mitigation factor (the "h" function).
    %
    % Parameterisation:
    %   theta  – steepness multiplier for the first segment
    %   lp     – first kink  (lambda_prime, 0.11)
    %   ld     – second kink (lambda_double, 0.40)
    %   lt     – third kink  (lambda_triple, 0.70)
    %
    % The base slope s is chosen so that f(lt) = 1 exactly.

	theta = 5.23;
	lp = 0.11;
	ld = 0.40;
	lt = 0.70;

    % Validate inputs
    assert(all(vax_fractions >= 0 & vax_fractions <= 1, 'all'))

    % Solve for the base slope so that the function reaches 1 at lt
    s = 1 / (theta * lp + (ld - lp) + 0.5 * (lt - ld));

    % Cumulative values at kink points
    fd_at_lp = theta * s * lp;
    fd_at_ld = fd_at_lp + s * (ld - lp);

    % Segment masks
    mask1 = vax_fractions <= lp;
    mask2 = vax_fractions > lp  & vax_fractions <= ld;
    mask3 = vax_fractions > ld  & vax_fractions <= lt;
    mask4 = vax_fractions > lt;

    % Apply piecewise linear function
    y = zeros(size(vax_fractions));
    y(mask1) = theta * s * vax_fractions(mask1);
    y(mask2) = fd_at_lp + s * (vax_fractions(mask2) - lp);
    y(mask3) = fd_at_ld + (s / 2) * (vax_fractions(mask3) - ld);
    y(mask4) = 1;
end