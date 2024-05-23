% these filenames are created by monte_carlo_sims.m

filename_1 = 'sim_results_adv_1.xlsx';
filename_0 = 'sim_results_adv_0.xlsx';

outfilename = 'hist_combined';

if ~isfile(filename_1) || ~isfile(filename_0)
    fprintf('no stored data; run monte_carlo_sims_v2.m with save output turned on \n');
else
    sim_results_0 = readtable(filename_0,'Sheet','Sheet1');
    sim_results_1 = readtable(filename_1,'Sheet','Sheet1');
    
    % diff series
    vax_benefits_bn_arr = sim_results_1.vax_benefits_bn_arr - sim_results_0.vax_benefits_bn_arr;
    vax_costs_bn_arr = sim_results_1.vax_costs_bn_arr - sim_results_0.vax_costs_bn_arr;
    vax_net_benefits_bn_arr = sim_results_1.vax_net_benefits_bn_arr - sim_results_0.vax_net_benefits_bn_arr;
    sim_results_d = table(vax_benefits_bn_arr, vax_costs_bn_arr, vax_net_benefits_bn_arr);

    graphmin = -100;
    graphmax = 2000;
    tot = size(sim_results_0, 1);
    y_axis_max = 0.4;
    clf
    
    t = tiledlayout(3,3);
    t.TileIndexing = 'columnmajor';
%     t.TileSpacing = "tight";

    sim_results_list = {sim_results_1, sim_results_0, sim_results_d};
    table_names = ["with adv", "no adv", "diff"];
    
    for j = 1:3
        fprintf(table_names(j)+'\n');

        sim_results = sim_results_list{j}; 

        %%% BENEFITS
        nexttile
        histogram(sim_results.vax_benefits_bn_arr, 'Normalization', 'probability', ...
            'BinLimits',[graphmin,graphmax]);
        ylim([0 y_axis_max]);
        title('Benefits (bn), '+table_names(j))
        cov1 = sum(sim_results.vax_benefits_bn_arr <= graphmax & sim_results.vax_benefits_bn_arr >= graphmin)/tot;
        
        %%% COSTS
        nexttile
        histogram(sim_results.vax_costs_bn_arr, 'Normalization', 'probability', ...
            'BinLimits',[graphmin,graphmax]);
        ylim([0 y_axis_max]);
        title('Costs (bn), '+table_names(j))
        cov2 = sum(sim_results.vax_costs_bn_arr <= graphmax & sim_results.vax_costs_bn_arr >= graphmin)/tot;
        
        %%% NET
        nexttile
        histogram(sim_results.vax_net_benefits_bn_arr, 'Normalization', 'probability', ...
            'BinLimits',[graphmin,graphmax]);
        ylim([0 y_axis_max]);
        title('Net value (bn), '+table_names(j))
        cov3 = sum(sim_results.vax_net_benefits_bn_arr <= graphmax & sim_results.vax_net_benefits_bn_arr >= graphmin)/tot;
        
        fprintf('Pct of obs covered on x-axis (benefits, costs, net):\n')
        cov = [cov1 cov2 cov3]
        
        fprintf('mean | median (net):\n')
        sumstats = [mean(sim_results.vax_net_benefits_bn_arr, 1) median(sim_results.vax_net_benefits_bn_arr)]
    end

    print(outfilename,'-dpdf','-bestfit')

end