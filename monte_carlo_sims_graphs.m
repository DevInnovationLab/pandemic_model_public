if ~isfile('sim_results.xlsx')
    fprintf('no stored data; run monte_carlo_sims.m with save output turned on \n');
else
    sim_results = readtable('sim_results.xlsx','Sheet','Sheet1');
    
    graphmin = -1000;
    graphmax = 1500;
    tot = size(sim_results, 1);
    
    clf
    
    tiledlayout(3,1)
    
    nexttile
    histogram(sim_results.vax_net_benefits_bn_arr, 'Normalization', 'probability', ...
        'BinLimits',[-100,1000]);
    title('Net benefits (bn)')
    
    cov1 = sum(sim_results.vax_net_benefits_bn_arr <= graphmax & sim_results.vax_net_benefits_bn_arr >= graphmin)/tot;
    
    nexttile
    histogram(sim_results.vax_costs_bn_arr, 'Normalization', 'probability', ...
        'BinLimits',[-100,1000]);
    title('Costs (bn)')
    
    cov2 = sum(sim_results.vax_costs_bn_arr <= graphmax & sim_results.vax_net_benefits_bn_arr >= graphmin)/tot;
    
    nexttile
    histogram(sim_results.vax_benefits_bn_arr, 'Normalization', 'probability', ...
        'BinLimits',[-100,1000]);
    title('Gross benefits (bn)')
    
    cov3 = sum(sim_results.vax_benefits_bn_arr <= graphmax & sim_results.vax_net_benefits_bn_arr >= graphmin)/tot;
    
    cov = [cov1 cov2 cov3]
    
    sumstats = [mean(sim_results.vax_net_benefits_bn_arr, 1) median(sim_results.vax_net_benefits_bn_arr)]

end