function gen_sim_scens_new(sim_cnt, has_false_pos)
    % Generate simulation senarios: allow for multiple pandemics

    rng(1);
    save_output = 1;

    draw_lower = 0.867; % this is the cumulative prob for mu < 10^{-3} 

    if has_false_pos == 1
        draw_upper = 0.9988; % if the uniform draw exceeds this, cannot invert (set to mu_prime_prime)
    else
        draw_upper = 0.9994; % if the uniform draw exceeds this, cannot invert (set to mu_prime_prime)
    end

    params = params_default;

    i_star_threshold = params.i_star;

    arrival = params.arrival;

    % parameters that need to be unpacked for functions to work

    alpha = arrival.alpha;
    mu = arrival.mu_prime;
    mu_prime_prime = arrival.mu_prime_prime;
    sigma = arrival.sigma;
    xi = arrival.xi;

    if has_false_pos == 1
        w = arrival.w/2;
    else
        w = arrival.w;
    end

    ones = arrival.ones;
    twos = arrival.twos;
    threes = arrival.threes;
    fours = arrival.fours;
    fives = arrival.fives;

    periods = params.sim_periods;
    i0 = [mu, mu_prime_prime];

    % thresholds for determining state of vaccine availability technology

    % [0, params.p_b) both technologies successful (state = 1)
    % [params.p_b, params.p_b + params.p_m) only mRNA successful (state = 2)
    % [params.p_b + params.p_m, params.p_b + params.p_m + params.p_o) only traditional successful (state = 3)
    % [params.p_b + params.p_m + params.p_o, 1] nothing is successful (state = 4)

    sim_scens = array2table(double.empty(0, 4), 'VariableNames', {'sim_num', 'yr_start', 'intensity', 'is_false'} );

    for s = 1:sim_cnt

        r = unifrnd(0, 1, periods, 1); % array of uniform random variables for the periods
        i_arr = zeros(periods, 1); % array of intensities (inverted from the uniform variables)
        
        for t = 2:periods-1 % don't want pandemic in first or last year (for calculation/indexing reasons)
            val = r(t);

            if val <= draw_lower
                i = mu;
            elseif val >= draw_upper
                i = mu_prime_prime;
            else
                %%% invert cumulative prob to get at intensity

    %             fprintf('%d \n', val)
                fun = @(i) f_cum(i, alpha, mu, sigma, xi, w, ones, twos, threes, fours, fives)- val;
                i = fzero(fun, i0);
            end

            i_arr(t) = i;
        end

        ind = i_arr > i_star_threshold; % indicator array for whether the intensity in each period exceeds some threshold
        yr_start_arr = find(ind); % the years in which intensity exceeds threshold
        
        if isempty(yr_start_arr) % no pandemic of at least threshold intensity in this simulation
            a.sim_num = s;
            a.yr_start = NaN; 
            a.intensity = NaN;
            a.is_false = NaN;
            
            row = struct2table(a);

            sim_scens = [sim_scens; row];
        else

            for y=1:length(yr_start_arr) % loop through each pandemic in the simulation
                yr_start = yr_start_arr(y);
                intensity = i_arr(yr_start);

                if has_false_pos == 1
                    draw_false_pos = rand();
                    if draw_false_pos < 0.5 % false pos half of the time
                        is_false = 1;
                    else
                        is_false = 0;
                    end
                else
                    is_false = 0;
                end

                a.sim_num = s;
                a.yr_start = yr_start; 
                a.intensity = intensity;
                a.is_false = is_false;
                
                row = struct2table(a);

                sim_scens = [sim_scens; row];
            end

        end
        
    end

    row_cnt = size(sim_scens,1);

    sim_scens.RD_score = unifrnd(0, 1, row_cnt, 1); % create a column of random variable to denote if RD successful (if there is RD) (this column not used if there is no RD)
    sim_scens.draw_state = unifrnd(0, 1, row_cnt, 1);
    sim_scens.draw_natural_dur = unifrnd(0, 1, row_cnt, 1);

    if save_output == 1
        outfilename = sprintf('sim_scens_has_false_%d.xlsx', has_false_pos);
    	delete(outfilename);
        writetable(sim_scens, outfilename,'Sheet',1);

        fprintf('printed output to %s\n', outfilename);
    end

end