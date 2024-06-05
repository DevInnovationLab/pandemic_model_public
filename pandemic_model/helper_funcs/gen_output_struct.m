function res = gen_output_struct(tbl_row, z_m, z_o, vax_benefits, vax_fraction_cum, inp_marg_costs, inp_tailoring_costs, inp_RD_costs, inp_cap_costs)

	res = tbl_row;
    res.cap_avail_m = z_m; % billion of units of annual capacity
    res.cap_avail_o = z_o; % billion of units of annual capacity
    res.vax_benefits = vax_benefits;
    res.vax_fraction_cum = vax_fraction_cum;
    res.inp_marg_costs = inp_marg_costs;
    res.inp_tailoring_costs = inp_tailoring_costs;
    res.inp_RD_costs = inp_RD_costs;
    res.inp_cap_costs = inp_cap_costs;

end