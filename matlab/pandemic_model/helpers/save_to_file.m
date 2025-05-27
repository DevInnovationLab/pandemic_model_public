function save_to_file(scenario_name, outdirpath, sim_results, ...
                      sim_out_arr_costs_adv_cap_nom, sim_out_arr_costs_adv_cap_PV, ...
                      sim_out_arr_costs_adv_RD_nom, sim_out_arr_costs_adv_RD_PV, ...
                      sim_out_arr_costs_ufv_RD_nom, sim_out_arr_costs_ufv_RD_PV, ...
                      sim_out_arr_costs_surveil_nom, sim_out_arr_costs_surveil_PV, ...
                      sim_out_arr_costs_inp_cap_nom, sim_out_arr_costs_inp_cap_PV, ...
                      sim_out_arr_costs_inp_marg_nom, sim_out_arr_costs_inp_marg_PV, ...
                      sim_out_arr_costs_inp_tailoring_nom, sim_out_arr_costs_inp_tailoring_PV, ...
                      sim_out_arr_costs_inp_RD_nom, sim_out_arr_costs_inp_RD_PV, ...
                      sim_out_arr_u_deaths, sim_out_arr_m_deaths, ...
                      sim_out_arr_m_mortality_losses, sim_out_arr_m_output_losses, ...
                      sim_out_arr_learning_losses, sim_out_arr_benefits_vaccine, ...
                      sim_out_arr_benefits_vaccine_nom)
 
    % Save model outputs
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'adv_cap_n');
    writematrix(sim_out_arr_costs_adv_cap_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'adv_cap_p');
    writematrix(sim_out_arr_costs_adv_cap_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'adv_RD_n');
    writematrix(sim_out_arr_costs_adv_RD_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'adv_RD_p');
    writematrix(sim_out_arr_costs_adv_RD_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'ufv_RD_n');
    writematrix(sim_out_arr_costs_ufv_RD_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'ufv_RD_p');
    writematrix(sim_out_arr_costs_ufv_RD_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'surveil_n');
    writematrix(sim_out_arr_costs_surveil_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'surveil_p');
    writematrix(sim_out_arr_costs_surveil_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'inp_cap_n');
    writematrix(sim_out_arr_costs_inp_cap_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'inp_cap_p');
    writematrix(sim_out_arr_costs_inp_cap_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'inp_marg_n');
    writematrix(sim_out_arr_costs_inp_marg_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'inp_marg_p');
    writematrix(sim_out_arr_costs_inp_marg_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'inp_tail_n');
    writematrix(sim_out_arr_costs_inp_tailoring_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'inp_tail_p');
    writematrix(sim_out_arr_costs_inp_tailoring_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'inp_RD_n');
    writematrix(sim_out_arr_costs_inp_RD_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'inp_RD_p');
    writematrix(sim_out_arr_costs_inp_RD_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'benefits');
    writematrix(sim_out_arr_benefits_vaccine, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'benefits_nom');
    writematrix(sim_out_arr_benefits_vaccine_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'u_deaths');
    writematrix(sim_out_arr_u_deaths, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'm_deaths'); 
    writematrix(sim_out_arr_m_deaths, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'm_mortality_losses');
    writematrix(sim_out_arr_m_mortality_losses, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'm_output_losses');
    writematrix(sim_out_arr_m_output_losses, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    
    out_arr_name = sprintf('%s/%s_ts_%s.csv', outdirpath, scenario_name, 'm_learning_losses');
    writematrix(sim_out_arr_learning_losses, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
    fprintf('printed output time series to file\n');

    out_filename = sprintf('%s/%s_pandemic_table.csv', outdirpath, scenario_name);
    writetable(sim_results, out_filename)
    fprintf('printed output to %s\n', out_filename);

end