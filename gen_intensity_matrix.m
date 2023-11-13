function gen_intensity_matrix(has_false_pos, sim_cnt)

	rng(1);
	save_output = 1;

    draw_lower = 0.867; % this is the cumulative prob for mu < 10^{-3} 

    if has_false_pos == 1
        draw_upper = 0.9988; % if the uniform draw exceeds this, cannot invert (set to mu_prime_prime)
    else
        draw_upper = 0.9994; % if the uniform draw exceeds this, cannot invert (set to mu_prime_prime)
    end

    params = params_default;
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

	int_matrix = NaN(sim_cnt, periods+1);

	for s = 1:sim_cnt

        r = unifrnd(0, 1, periods, 1); % array of uniform random variables for the periods
        i_arr = NaN(periods, 1); % array of intensities (inverted from the uniform variables)
        
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

        int_matrix(s, 1) = s;
        int_matrix(s, 2:end) = i_arr';

    end

    if save_output == 1
    	outfilename = sprintf('int_matrix_has_false_%d.mat', has_false_pos);

    	save(outfilename, 'int_matrix'); % save overwrites any existing file with this name

        fprintf('saved intensity matrix to %s\n', outfilename);
    end

end