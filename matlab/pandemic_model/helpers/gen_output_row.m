function row = gen_output_row(sim_scens_row, cap_avail_m, cap_avail_o, u_deaths, m_deaths, ...
    vax_benefits, m_mortality_losses, m_output_losses, m_learning_losses, ex_post_severity, ...
    vax_fraction_end, inp_marg_costs, inp_tailoring_costs, inp_RD_costs, inp_cap_costs)
% Generates an output structure with default values for pandemic simulation results
%
% Args:
%   sim_scens_s: Simulation scenarios table
%   cap_avail_m: Available mRNA capacity
%   cap_avail_o: Available other capacity
%   u_deaths: Unmitigated deaths
%   m_deaths: Mitigated deaths
%   vax_benefits: Vaccine benefits
%   m_mortality_losses: Mitigated mortality losses
%   m_output_losses: Mitigated output losses
%   m_learning_losses: Mitigated learning losses
%   vax_fraction_end: Vaccine fraction at end
%   inp_marg_costs: Input marginal costs
%   inp_tailoring_costs: Input tailoring costs
%   inp_RD_costs: Input R&D costs
%   inp_cap_costs: Input capacity costs
%
% Returns:
%   row: Table row with initialized output fields

    row = sim_scens_row;
    row.cap_avail_m = cap_avail_m;
    row.cap_avail_o = cap_avail_o;
    row.u_deaths = u_deaths;
    row.m_deaths = m_deaths;
    row.vax_benefits = vax_benefits;
    row.m_mortality_losses = m_mortality_losses;
    row.m_output_losses = m_output_losses;
    row.m_learning_losses = m_learning_losses;
    row.ex_post_severity = ex_post_severity;
    row.vax_fraction_end = vax_fraction_end;
    row.inp_marg_costs = inp_marg_costs;
    row.inp_tailoring_costs = inp_tailoring_costs;
    row.inp_RD_costs = inp_RD_costs;
    row.inp_cap_costs = inp_cap_costs;
end