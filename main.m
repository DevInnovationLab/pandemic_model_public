%%% calling file

params = params_default();

[vax_benefits, pv_tln, h_sum, vax_fraction_sum] = advance_prep_benefits(params);
vax_costs = advance_prep_costs(params);

vax_value = (vax_benefits - vax_costs);
vax_value_bn = vax_value / 10^9
