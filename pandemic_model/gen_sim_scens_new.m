function outpath = gen_sim_scens_new(include_false_positives, i_star_threshold, viral_family_frequency_table, int_matrix_path, outdirpath)
    % Generate simulation senarios: allow for multiple pandemics

    save_output = 1;

    % load intensity matrix
    load(int_matrix_path,'int_matrix');
    sim_cnt = int_matrix(end, 1);

    % initialize scenario table
    sim_scens = array2table(double.empty(0, 3), 'VariableNames', {'sim_num', 'yr_start', 'intensity'} );

    % turns the intensity matrix (sim_cnt by sim periods) into a list of pandemics
    cluster = parcluster;
    parfor (s = 1:sim_cnt, cluster) % loop through each simulation scenario
    % for s = 1:sim_cnt

        i_arr = int_matrix(s, 2:end)';

        ind = i_arr > i_star_threshold; % indicator array for whether the intensity in each period exceeds some threshold
        yr_start_arr = find(ind); % the years in which intensity exceeds threshold
        
        a = {};
        if isempty(yr_start_arr) % no pandemic of at least threshold intensity in this simulation
            a.sim_num   = s;
            a.yr_start  = NaN;
            a.intensity = NaN;
            
            row = struct2table(a);

            sim_scens = [sim_scens; row];
        else

            for y=1:length(yr_start_arr) % loop through each pandemic in the simulation
                yr_start = yr_start_arr(y);
                intensity = i_arr(yr_start);

                a.sim_num   = s;
                a.yr_start  = yr_start;
                a.intensity = intensity;
                
                row = struct2table(a);

                sim_scens = [sim_scens; row];
            end

        end
        
        if mod(s, 1000) == 0
%           fprintf('finished sim num %d (elaspsed min: %d)\n', s, round(toc/60, 1));
            fprintf('finished reshaping int matrix for sim num %d\n', s);
        end
    end

    row_cnt = size(sim_scens,1); % num of sims times pandemics per sim
    
    if include_false_positives == 1
        draw_is_false = unifrnd(0, 1, row_cnt, 1);
        is_false_arr = draw_is_false < .5; % false pos half of the time
        sim_scens.is_false = double(is_false_arr);
    else
        sim_scens.is_false = zeros(row_cnt, 1);
    end

    RD_score         = unifrnd(0, 1, row_cnt, 1); % create a column of random variable to denote if RD successful (if there is RD) (this column not used if there is no RD)
    sim_scens.pathogen_family  = map_RD_score_to_pathogen_family(RD_score, viral_family_frequency_table);

    sim_scens.draw_state       = unifrnd(0, 1, row_cnt, 1);
    sim_scens.draw_natural_dur = unifrnd(0, 1, row_cnt, 1);

    out_posteriors = gen_surveil_signals(is_false_arr);
    sim_scens.posterior1 = out_posteriors(:, 1);
    sim_scens.posterior2 = out_posteriors(:, 2);

    if save_output == 1
        outpath = fullfile(outdirpath, sprintf('sim_scens_has_false_%d', include_false_positives));
        save(outpath,'sim_scens');
        fprintf('printed output to %s.mat\n', outpath);
    else
        outpath = NaN;
    end

end
