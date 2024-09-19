function prep_start_month_arr = run_surveillance(posterior1, posterior2, is_false_arr, ...
	enhanced_surveillance, threshold_surveil_arr)
	% only computes, no random number generation

	% Extract thresholds
	threshold_no_surveil = threshold_surveil_arr(1);
	threshold_surveil = threshold_surveil_arr(2);

	% Compute true state and prepare decisions
	is_pandemic = ~is_false_arr;
	prepare_decision1 = posterior1 > (enhanced_surveillance * threshold_surveil + ~enhanced_surveillance * threshold_no_surveil);
	prepare_decision2 = posterior2 > threshold_surveil;

	% Initialize prep_start_month_arr with default value
	prep_start_month_arr = 2 * ones(size(is_false_arr));

	if enhanced_surveillance
		% Enhanced surveillance logic
		prep_start_month_arr(prepare_decision1) = 0;
		prep_start_month_arr(~prepare_decision1 & prepare_decision2) = 1;
	else
		% No surveillance logic
		prep_start_month_arr(prepare_decision1) = 1;
	end

	% Handle cases where no pandemic was correctly anticipated
	no_pandemic_correctly_anticipated = ~is_pandemic & ...
		((~enhanced_surveillance & ~prepare_decision1) | ...
		 (enhanced_surveillance & ~prepare_decision1 & ~prepare_decision2));
	prep_start_month_arr(no_pandemic_correctly_anticipated) = NaN;

	% Ensure prep_start_month_arr is a column vector
	prep_start_month_arr = prep_start_month_arr(:);
end