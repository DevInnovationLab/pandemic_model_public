% Generate simulation senarios: generate the table in sim_scens.xlsx

sim_cnt = 10000;
save_output = 1;
has_false_pos = 1;

rng(0);

draw_lower = 0.867; % this is the cumulative prob for mu < 10^{-3} 
draw_upper = 0.9994; % if the uniform draw exceeds this, cannot invert (set to mu_prime_prime)

pandemic_dur_probs = [1 0 0]; % prob of pandemic of duration 1y, 2y, 3y (respectively)
assert(sum(pandemic_dur_probs)==1)

yr_start_arr = NaN(sim_cnt, 1); % array of start yr of pandemic
intensity_arr = NaN(sim_cnt, 1); % array of pandemic intensities (assumed to be intensity associated with start yr)
state_arr = NaN(sim_cnt, 1); % array of state of production
natural_dur_arr = NaN(sim_cnt, 1); % array of natural pandemic durations
is_false_arr = NaN(sim_cnt, 1); % array of natural pandemic durations

params = params_default;
if has_false_pos == 1
    i_star_threshold = params.i_star_w_false;
else
    i_star_threshold = params.i_star;
end

arrival = params.arrival;

% parameters that need to be unpacked for functions to work

alpha = arrival.alpha;
mu = arrival.mu_prime;
mu_prime_prime = arrival.mu_prime_prime;
sigma = arrival.sigma;
xi = arrival.xi;

w = arrival.w;
ones = arrival.ones;
twos = arrival.twos;
threes = arrival.threes;
fours = arrival.fours;
fives = arrival.fives;

periods = params.sim_periods;
i0 = [mu, mu_prime_prime];

for s = 1:sim_cnt

    r = unifrnd(0, 1, periods, 1); % array of uniform random variables for the periods
    i_arr = zeros(periods, 1); % array of intensities (inverted from the uniform variables)
    
    for t = 1:periods
        val = r(t);

        if val <= draw_lower
            i = mu;
        elseif val >= draw_upper
            i = mu_prime_prime;
        else
            %%% invert cumulative prob to get at intensity

            % fprintf('%d \n', val)
            fun = @(i) f_cum(i, alpha, mu, sigma, xi, w, ones, twos, threes, fours, fives)- val;
            i = fzero(fun, i0);
        end

        i_arr(t) = i;
    end

    ind = i_arr > i_star_threshold; % indicator array for whether the intensity in each period exceeds some threshold
    yr_start = find(ind,1,'first'); % the first year in which intensity exceeds threshold
    
    if isempty(yr_start)
        yr_start = NaN; % no pandemic of at least threshold intensity in this simulation
    end

    yr_start_arr(s) = yr_start;
    
    if ~isnan(yr_start) % has a pandemic of significant size

    	intensity = i_arr(yr_start);
        intensity_arr(s) = intensity;
        if intensity >= params.i_star
            is_false = 0;
        else
            is_false = 1;
        end
        is_false_arr(s) = is_false;


        if ~is_false
    	    draw1 = rand(); % random draw 1 is for determining state of vaccine production
            
            % [0, 0.5) both technologies successful (state = 1)
            % [0.5, 0.65) only mRNA successful (state = 2)
            % [0.65, 0.8) only traditional successful (state = 3)
            % [0.8, 1] nothing is successful (state = 4)
    
            if draw1 < 0.5
                state = 1;
            elseif draw1 < 0.65
                state = 2;
            elseif draw1 < 0.8
                state = 3;
            else
                state = 4;
            end
            state_arr(s) = state;
    
            draw2 = rand(); % random var 2 is for determining pandemic duration
    
            if draw2 < pandemic_dur_probs(1)
                pandemic_natural_dur = 1;
            elseif draw2 < (pandemic_dur_probs(1) + pandemic_dur_probs(2))
                pandemic_natural_dur = 2;
            else
                pandemic_natural_dur = 3;
            end
    
            natural_dur_arr(s) = pandemic_natural_dur;
        end
    end

end

sim_scens = table(yr_start_arr, intensity_arr, is_false_arr, state_arr, natural_dur_arr);

sim_scens.state_desc = repmat({""}, size(sim_scens,1), 1);
sim_scens.state_desc(sim_scens.state_arr==1) = {"both"};
sim_scens.state_desc(sim_scens.state_arr==2) = {"mRNA_only"};
sim_scens.state_desc(sim_scens.state_arr==3) = {"trad_only"};
sim_scens.state_desc(sim_scens.state_arr==4) = {"none"};
sim_scens.state_desc(isnan(sim_scens.state_arr)) = {"no_pandemic"};

if save_output == 1
    outfilename = sprintf('sim_results_has_false_%d.xlsx', has_false_pos);
	delete(outfilename);
    writetable(sim_scens, outfilename,'Sheet',1);
end
