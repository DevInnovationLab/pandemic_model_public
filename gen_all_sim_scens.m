function gen_all_sim_scens(has_false_pos, sim_cnt, i_star_threshold, RD_family_freq_table)
	
	gen_intensity_matrix(has_false_pos, sim_cnt); 
	gen_sim_scens_new(has_false_pos, i_star_threshold, RD_family_freq_table);

end