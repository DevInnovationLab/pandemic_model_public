function outpath = gen_sim_scens_new(include_false_positives, i_star_threshold, viral_family_frequency_table, int_matrix_path, outdirpath)
    % Generate simulation senarios: allow for multiple pandemics

    % load severity matrix
    load(int_matrix_path, 'int_matrix');

    % Initialize scenario table
    i_arr = int_matrix(:, 2:end);
    ind = i_arr > i_star_threshold; % indicator array for whether the severity in each period exceeds some threshold
    yr_start_arr = find(ind); % the years in which severity exceeds threshold
    row_cnt = size(yr_start_arr, 1);

    % Create table of pandemic scenarios
    sim_num = mod(yr_start_arr - 1, size(i_arr, 1)) + 1;
    yr_start = ceil(yr_start_arr / size(i_arr, 1));
    severity = i_arr(yr_start_arr);
    
    if include_false_positives == 1
        draw_is_false = unifrnd(0, 1, row_cnt, 1);
        is_false = draw_is_false < .5;
    else
        is_false = false(row_cnt, 1);
    end

    % Create a column of random variable to denote if RD successful (if there is RD)
    viral_family_score = unifrnd(0, 1, row_cnt, 1); 
    pathogen_family  = map_RD_score_to_pathogen_family(viral_family_score, viral_family_frequency_table);
    rd_state       = unifrnd(0, 1, row_cnt, 1);
    draw_natural_dur = unifrnd(0, 1, row_cnt, 1);

    [posterior1, posterior2] = gen_surveil_signals(is_false);

    % Create table of pandemic scenarios
    sim_scens = table(sim_num, yr_start, severity, ...
        is_false, viral_family_score, pathogen_family, rd_state, ...
        draw_natural_dur, posterior1, posterior2);

    sim_scens = sortrows(sim_scens, {'sim_num', 'yr_start'});

    outpath = fullfile(outdirpath, sprintf('sim_scens_has_false_%d', include_false_positives));
    save(outpath,'sim_scens');
    fprintf('printed output to %s.mat\n', outpath);

end
