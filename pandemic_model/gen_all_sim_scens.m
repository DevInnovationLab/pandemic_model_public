function sim_scens_path = gen_all_sim_scens(arrival_params, include_false_positives, sim_cnt, ...
	i_star_threshold, RD_family_freq_table, sim_periods, outdirpath)
	
	int_matrix_path = gen_intensity_matrix(arrival_params, include_false_positives, sim_cnt, sim_periods, outdirpath); 
	sim_scens_path = gen_sim_scens_new(include_false_positives, i_star_threshold, RD_family_freq_table, int_matrix_path, outdirpath);

end