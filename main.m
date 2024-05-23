%%% calling file

addpath(genpath('./pandemic_model'));

sim_cnt = 10000;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% generate simluation scenarios
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

i_COVID = 0.32;	% COVID intensity (annual deaths per thousand)
i_star_threshold = i_COVID / 2; % min intensity for next pandemic

%%% all the calls that have randomization are performed here

rng(1);

has_false_pos = 1;

params_dft = params_default();

gen_all_sim_scens(has_false_pos, sim_cnt, i_star_threshold, params_dft.RD_family_freq_table);

[z_m, z_o] = get_adv_capacity(params_dft); % get advanced capacity

adv_ratios = [0 0.25];
cnt_adv = length(adv_ratios);

output_benefits = NaN(cnt_adv*2, 4);
output_costs = NaN(cnt_adv*2, 4);
output_net = NaN(cnt_adv*2, 4);

i=1;
for c=1:cnt_adv
    adv_ratio = adv_ratios(c);

    for ind_RD=0:1
        
        params_user = [];
        params_user.has_RD = ind_RD;
        params_user.save_output = 1;

        params_user.has_user_cap_setting = 1;
        params_user.user_z_m = z_m*adv_ratio;
        params_user.user_z_o = z_o*adv_ratio;

        threshold_surveil_arr = [0 0]; % action threshold for no surveil and with surveil

        has_surveil = 0;
        outfile_label = sprintf('false_1_adv_%0.2f_RD_%d_surveil_%d_thold_%0.2f', adv_ratio, ind_RD, has_surveil, threshold_surveil_arr(1));
        [net_ns, benefits_ns, costs_ns] = monte_carlo_sims_new(params_user, outfile_label, has_false_pos, has_surveil, threshold_surveil_arr);

        output_net(i,1:3)      = [adv_ratio ind_RD round(net_ns,1)     ];
        output_benefits(i,1:3) = [adv_ratio ind_RD round(benefits_ns,1)];
        output_costs(i,1:3)    = [adv_ratio ind_RD round(costs_ns,1)   ];

        has_surveil = 1;
        outfile_label = sprintf('false_1_adv_%0.2f_RD_%d_surveil_%d_thold_%0.2f', adv_ratio, ind_RD, has_surveil, threshold_surveil_arr(end));
        [net_ws, benefits_ws, costs_ws] = monte_carlo_sims_new(params_user, outfile_label, has_false_pos, has_surveil, threshold_surveil_arr);

        output_net(i, 4) = round(net_ws,1);
        output_benefits(i, 4) = round(benefits_ws,1);
        output_costs(i, 4) = round(costs_ws,1); 

        i = i+1;
    end
end


