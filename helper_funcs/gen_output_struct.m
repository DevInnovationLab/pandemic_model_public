function res = gen_output_struct(tbl_row, z_m, z_o, vax_benefits, vax_fraction_cum, in_p_marg_costs, in_p_fill_finish_costs)

	res = tbl_row;
    res.cap_avail_m = z_m; % billion of units of annual capacity
    res.cap_avail_o = z_o; % billion of units of annual capacity
    res.vax_benefits = vax_benefits;
    res.vax_fraction_cum = vax_fraction_cum;
    res.in_pandemic_marg_costs = in_p_marg_costs;
    res.in_pandemic_fill_finish_costs = in_p_fill_finish_costs;

end