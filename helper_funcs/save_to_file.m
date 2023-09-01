function save_to_file(outfile_label, sim_results_sum, sim_results)

	if isempty(outfile_label)
            out_filename_sum = 'sim_results_sum.xlsx';
            out_filename = 'sim_results.xlsx';
        else
            out_filename_sum = sprintf('sim_results_%s_sum.xlsx', outfile_label);
            out_filename = sprintf('sim_results_%s.xlsx', outfile_label);
    end
        
    delete(out_filename_sum);
    writetable(sim_results_sum, out_filename_sum, 'Sheet', 1);
    fprintf('printed summary output to %s\n', out_filename_sum);

    delete(out_filename);
    writetable(sim_results, out_filename, 'Sheet', 1)
    fprintf('printed output to %s\n', out_filename);

end