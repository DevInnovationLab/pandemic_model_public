%%% calling file

addpath(genpath('/Users/catherineche/Documents/github/pandemic_model/helper_funcs'));
addpath(genpath('/Users/catherineche/Documents/github/pandemic_model/arrival_distributions'));

has_false_pos = 1; % use this setting for all
sim_cnt = 10000;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% generate simluation scenarios
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% gen_intensity_matrix(has_false_pos, sim_cnt);

i_COVID = 0.32;	% COVID intensity (annual deaths per thousand)
i_star_threshold = i_COVID / 2; % min intensity for next pandemic

% gen_sim_scens_new(has_false_pos, i_star_threshold);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% run simulation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
params_user = []; % sample use: params_user.tau_A = 100;

for ind_adv = 0:1
    for ind_RD = 0:1
        params_user = [];
        params_user.has_RD = ind_RD;
        has_full_adv_cap = ind_adv;
        outfile_label = sprintf('adv_%d_false_1_RD_%d', ind_adv, ind_RD);
        monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, has_false_pos);
    end
end
