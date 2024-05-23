function prep_start_month_arr = run_surveillance(posterior1, posterior2, is_false_arr, has_surveil, threshold_surveil_arr)
	% only computes, no random number generation

	threshold_no_surveil = threshold_surveil_arr(1);
	threshold_surveil = threshold_surveil_arr(2);

	cnt = length(is_false_arr);
	prep_start_month_arr = zeros(cnt, 1);

	for i=1:cnt
	
		is_pandemic_0 = ~is_false_arr(i); % true state of the world

		if has_surveil == 1
			prepare_for_pandemic1 = posterior1(i) > threshold_surveil; % decision rule from first set of signals
		else
			prepare_for_pandemic1 = posterior1(i) > threshold_no_surveil;
		end

		if has_surveil && ~prepare_for_pandemic1 % a second signal if has surveillance and hasn't acted

			prepare_for_pandemic2 = posterior2(i) > threshold_surveil; % decision rule from second set of signals
		end
		
		if has_surveil == 1 % has access to two sets of signals
			
			if prepare_for_pandemic1
				prep_start_month = 0;
            elseif prepare_for_pandemic2
				prep_start_month = 1;
			else
				
				if is_pandemic_0
					prep_start_month = 2;
				else
					prep_start_month = NaN; % correctly anticipated no pandemic
				end

			end
		
		else % no surveil == access to only one set of signals
		
			if prepare_for_pandemic1 % only has access to one set of signals but one month later
				prep_start_month = 1;
			else
				if is_pandemic_0
					prep_start_month = 2;
				else
					prep_start_month = NaN; % correctly anticipated no pandemic
				end
			end
		
		end

		prep_start_month_arr(i) = prep_start_month;
		
	end
end