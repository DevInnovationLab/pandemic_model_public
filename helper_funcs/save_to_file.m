function save_to_file(outfile_label, sim_results_sum, sim_results, ...
        sim_out_arr_costs_adv_cap_nom,       sim_out_arr_costs_adv_cap_PV,       ...
        sim_out_arr_costs_adv_RD_nom,        sim_out_arr_costs_adv_RD_PV,        ...
        sim_out_arr_costs_surveil_nom,        sim_out_arr_costs_surveil_PV,      ...
        sim_out_arr_costs_inp_cap_nom,       sim_out_arr_costs_inp_cap_PV,       ...
        sim_out_arr_costs_inp_marg_nom,      sim_out_arr_costs_inp_marg_PV,      ...
        sim_out_arr_costs_inp_tailoring_nom, sim_out_arr_costs_inp_tailoring_PV, ...
        sim_out_arr_costs_inp_RD_nom,        sim_out_arr_costs_inp_RD_PV, ...
        sim_out_arr_benefits_vaccine_nom,    sim_out_arr_benefits_vaccine_PV )

    if ismac
        outpath = '/Users/catherineche/Library/CloudStorage/Box-Box/MSA/model_outputs';
    else
        % outpath = '/accounts/grad/cjche/Documents/pandemic_model_outputs';
        outpath = '/accounts/grad/cjche/scratch/pandemic_model_outputs/';
    end

	if isempty(outfile_label)
            out_filename_sum = sprintf('%s/sim_results_sum.xlsx', outpath);
            out_filename = sprintf('%s/sim_results.xlsx', outpath);
        else
            date_string = datestr(today, 'yyyymmdd');

            out_filename_sum = sprintf('%s/sim_results_%s_%s_sum.xlsx', outpath, outfile_label, date_string);
            out_filename = sprintf('%s/sim_results_%s_%s.xlsx', outpath, outfile_label, date_string);

            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'adv_cap_n');
            writematrix(sim_out_arr_costs_adv_cap_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'adv_cap_p');
            writematrix(sim_out_arr_costs_adv_cap_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'adv_RD_n');
            writematrix(sim_out_arr_costs_adv_RD_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'adv_RD_p');
            writematrix(sim_out_arr_costs_adv_RD_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'surveil_n');
            writematrix(sim_out_arr_costs_surveil_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'surveil_p');
            writematrix(sim_out_arr_costs_surveil_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'inp_cap_n');
            writematrix(sim_out_arr_costs_inp_cap_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'inp_cap_p');
            writematrix(sim_out_arr_costs_inp_cap_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'inp_marg_n');
            writematrix(sim_out_arr_costs_inp_marg_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'inp_marg_p');
            writematrix(sim_out_arr_costs_inp_marg_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'inp_tail_n');
            writematrix(sim_out_arr_costs_inp_tailoring_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'inp_tail_p');
            writematrix(sim_out_arr_costs_inp_tailoring_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'inp_RD_n');
            writematrix(sim_out_arr_costs_inp_RD_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'inp_RD_p');
            writematrix(sim_out_arr_costs_inp_RD_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');

            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'benefits_n');
            writematrix(sim_out_arr_benefits_vaccine_nom, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            out_arr_name = sprintf('%s/sim_ts_%s_%s_%s.csv', outpath, outfile_label, date_string, 'benefits_p');
            writematrix(sim_out_arr_benefits_vaccine_PV, out_arr_name, 'Delimiter','comma', 'WriteMode', 'overwrite');
            fprintf('printed output time series to file\n');
    end
        
    delete(out_filename_sum);
    writetable(sim_results_sum, out_filename_sum, 'Sheet', 1);
    fprintf('printed summary output to %s\n', out_filename_sum);

    delete(out_filename);
    writetable(sim_results, out_filename, 'Sheet', 1)
    fprintf('printed output to %s\n', out_filename);

end