function outpath = gen_severity_matrix(arrival_dist, include_false_positives, sim_cnt, sim_periods, outdirpath)
    % No functionality for including false positives yet. 
	int_matrix = arrival_dist.get_severity(unifrnd(0, 1, sim_cnt, sim_periods));
    int_matrix = [(1:sim_cnt)' int_matrix];

    outpath = fullfile(outdirpath, sprintf('int_matrix_has_false_%d.mat', include_false_positives));
    save(outpath, 'int_matrix');
    fprintf('saved severity matrix to %s\n', outpath);
end