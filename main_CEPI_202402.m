addpath(genpath('/Users/catherineche/Documents/github/pandemic_model/helper_funcs'));
addpath(genpath('/Users/catherineche/Documents/github/pandemic_model/arrival_distributions'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%% Runs for what Saul wants on Feb 21, 2024
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

include_false_positives = 1; % use this setting for all

%%% LEVEL 1
has_full_adv_cap = 0;

params_user = [];
outfile_label = 'PoS_base';
monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, include_false_positives);

params_user.p_b = 0.45;
params_user.p_o = 0.125;
params_user.p_m = 0.125;

%%% LEVEL 2
has_full_adv_cap = 0;

params_user = [];
params_user.has_RD = 1; % sample use: params_user.tau_A = 100;
outfile_label = 'level2';
monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, include_false_positives);

%%% LEVEL 3 (50% advanced capacity)
has_full_adv_cap = 0;

[z_m, z_o] = get_adv_capacity(params_default()); % get advanced capacity

params_user = [];
params_user.has_RD = 1;
params_user.has_user_cap_setting = 1;
params_user.user_z_m = z_m*0.5;
params_user.user_z_o = z_o*0.5;

outfile_label = 'level3';
monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, include_false_positives);

%%% LEVEL 4 (100% / full advanced capacity)
has_full_adv_cap = 1;

params_user = [];
params_user.has_RD = 1;
outfile_label = 'level4';
monte_carlo_sims_new(params_user, outfile_label, has_full_adv_cap, include_false_positives);
