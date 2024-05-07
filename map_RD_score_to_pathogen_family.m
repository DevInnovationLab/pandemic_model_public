function family_category = map_RD_score_to_pathogen_family(RD_score_arr, family_freq_table)
	% RD_score_arr is an array of uniform random variables

	%%% 
	% Let x denote a RD score. We will map x to a disease family using the mapping encoded in the family_feq_table.
	% For example, if the freq is the same for 10 disease families, then the mapping would look like this:
	% x \in [0 0.1) --> family 1
	% x \in [0.1 0.2) --> family 2
	% x \in [0.2 0.3) --> family 3
	% x \in [0.3 0.4) --> family 4
	% x \in [0.4 0.5) --> family 5
	% x \in [0.5 0.6) --> family 6
	% x \in [0.6 0.7) --> family 7
	% x \in [0.7 0.8) --> family 8
	% x \in [0.8 0.9) --> family 9
	% x \in [0.9 1) --> family 10
	%%%
	
	assert(round(sum(family_freq_table(:, 2)), 6) == 1); % probabilities add up to 1, need to wrap in a round call to make matlab register the correct number of decimals

	family_cnt = length(family_freq_table(:,1));
	current_val = 0;
	family_interval_arr = zeros(family_cnt, 2); % each row denotes the interval that corresponds to the family indexed by row number
	for i=1:family_cnt % loop through each family to construct its interval on the unit line
		len_i = family_freq_table(i, 2);
		i_start = current_val;
		i_end = current_val + len_i;
		current_val = i_end;

		family_interval_arr(i, :) = [i_start i_end];
	end

	row_cnt = length(RD_score_arr);

	family_category = NaN(row_cnt, 1);

	for i=1:family_cnt
		i_start = family_interval_arr(i, 1);
		i_end = family_interval_arr(i, 2);
		family_category(RD_score_arr >= i_start & RD_score_arr < i_end) = i;
	end

	assert(sum(isnan(family_category)) == 0); % check that all rows were assigned to a family
end