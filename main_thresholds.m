%%% calling file

if ismac
    addpath(genpath('/Users/catherineche/Documents/github/pandemic_model/helper_funcs'));
    addpath(genpath('/Users/catherineche/Documents/github/pandemic_model/arrival_distributions'));
else
    addpath(genpath('/accounts/grad/cjche/Documents/pandemic_model/helper_funcs'));
    addpath(genpath('/accounts/grad/cjche/Documents/pandemic_model/arrival_distributions'));
end

sim_cnt = 10000;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% generate simluation scenarios
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

i_COVID = 0.32;	% COVID intensity (annual deaths per thousand)
i_star_threshold = i_COVID / 2; % min intensity for next pandemic

%%% all the calls that have randomization are performed here

rng(1);

has_false_pos = 1;
gen_all_sim_scens(has_false_pos, sim_cnt, i_star_threshold); 

ind_adv = 0;
ind_RD = 0;

params_user = [];
params_user.has_RD = ind_RD;
params_user.save_output = 0;

has_full_adv_cap = ind_adv;

thold_rng = 0:0.1:1;
output_net = zeros(length(thold_rng), 3);

i=1;
for thold = thold_rng
        threshold_surveil_arr = repmat(thold, 1, 2); % action threshold for no surveil and with surveil

        has_surveil = 0;
        outfile_label = sprintf('adv_%d_false_1_RD_%d_surveil_%d_thold_%0.2f', ind_adv, ind_RD, has_surveil, thold);
        [net_no_surveil, ~, ~] = monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, has_false_pos, has_surveil, threshold_surveil_arr);

        has_surveil = 1;
        outfile_label = sprintf('adv_%d_false_1_RD_%d_surveil_%d_thold_%0.2f', ind_adv, ind_RD, has_surveil, thold);
        [net_with_surveil, ~, ~] = monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, has_false_pos, has_surveil, threshold_surveil_arr);

        output_net(i,:) = [thold round(net_no_surveil,1) round(net_with_surveil,1)];
        i = i+1;
end


