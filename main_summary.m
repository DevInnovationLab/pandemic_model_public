% Create a table summarizing results for with / without RD, and with / without adv capacity
addpath(genpath('/Users/catherineche/Documents/github/pandemic_model/helper_funcs'));

reload_data    = 1;
save_sum_data  = 0;
save_fig       = 0;

if reload_data == 1
    avg_results = array2table(double.empty(0,9), 'VariableNames', {...
	    'scen_name', ...
        'vax_net_benefits_bn_arr', 'vax_benefits_bn_arr', 'vax_costs_bn_arr', ...
	    'vax_costs_RD_bn_arr', 'vax_costs_upfront_cap_bn_arr', 'vax_costs_in_p_cap_bn_arr', 'vax_costs_in_p_m_bn_arr', 'vax_costs_in_p_tailoring_bn_arr'
    });
    
    for ind_adv = 0:1
	    for ind_RD = 0:1
		    file_label = sprintf('adv_%d_false_1_RD_%d', ind_adv, ind_RD);
		    load_filename = sprintf('sim_results_%s_sum.xlsx', file_label); % this file is made by gen_sim_scens.m
		    sim_results = readtable(load_filename,'Sheet','Sheet1');
    
		    sim_results = removevars(sim_results, {'sim_num'}); % remove the sim num column
    
		    avg_res0 = varfun(@mean, sim_results); % collapse to a rown of avgs
		    avg_res0 = remove_mean_from_col_names(avg_res0); % remove "mean_" from var names

            avg_res0 = renamevars(avg_res0, 'vax_costs_in_p_ff_bn_arr', 'vax_costs_in_p_tailoring_bn_arr'); % TEMP
    
		    avg_res0.scen_name = file_label; % add a scen name col
		    avg_res = [avg_res0(:,end) avg_res0(:, 1:end-1)]; % make scen name be first column
    
		    avg_results = [avg_results; avg_res]; % add to results
	    end
    
    end
end

if save_sum_data == 1
    outfilename = 'sim_results_summary.xlsx';
    delete(outfilename);
    writetable(avg_results, outfilename,'Sheet',1);
    
    fprintf('printed output to %s\n', outfilename);
end

net_benefits = avg_results.vax_net_benefits_bn_arr;
costs = avg_results.vax_costs_bn_arr;

cost_RD         = avg_results.vax_costs_RD_bn_arr;
cost_upf_cap    = avg_results.vax_costs_upfront_cap_bn_arr;
cost_inp_cap    = avg_results.vax_costs_in_p_cap_bn_arr;
cost_inp_marg   = avg_results.vax_costs_in_p_m_bn_arr;
cost_inp_tailor = avg_results.vax_costs_in_p_tailoring_bn_arr;

y1 = [costs net_benefits];
y2 = [cost_upf_cap cost_inp_cap cost_inp_marg cost_inp_tailor cost_RD];

x = table2array(avg_results(:, 1)); % first column is label

x_cell = {};
sz = size(x);
row_cnt = sz(1);
for i = 1:row_cnt % remove "_false_1" and replace "_" with " " from label name
    val = x(i, :);
    val_new = erase(val,"_false_1");
    val_new = strrep(val_new, '_', " ");
    x_cell = [x_cell val_new];
end

xl = categorical(x_cell);
xl = reordercats(xl, x_cell);

% color1 = [121 93 93 ] ./ 255;
color1 = ["#DD6E55", "#4791D1"]; % for cost and benefit

% color2 = ["#039696", "#BFDAA7", "#517594", "#BBC2C4", "#A6A2C3"]; % for cost breakdown
color2 = ["#F4A171", "#722F37", "#FF8A8A", "#D10000", "#A8A8A8"]; % for cost breakdown

clf
tiledlayout(2,1);

ax1 = nexttile;
b1 = bar(ax1, y1, 'stacked');
b1(1).FaceColor = color1(1);
b1(1).EdgeColor = color1(1);

b1(2).FaceColor = color1(2);
b1(2).EdgeColor = color1(2);
title("Costs and benefits")
legend({'Costs','Benefits'}, 'FontSize', 14, 'Orientation','horizontal', 'Location','southoutside')
set(gca,'xticklabel', x_cell)
ylim([0 2500])
ax = gca;
ax.FontSize = 14;

% xlabel('scenario')
ylabel('$bn (pv)') 

ax2 = nexttile;

b2 = bar(ax2, y2, 'stacked');
for i=1:5
    b2(i).FaceColor = color2(i);
    b2(i).EdgeColor = color2(i);
end
title("Costs breakdown")
legend({'capacity (upf)','capacity (in-p)', 'marginal costs (in-p)', 'tailoring costs (in-p)', 'R&D'}, ...
    'FontSize', 12, 'Orientation','horizontal', 'NumColumns', 3, 'Location','southoutside')
set(gca,'xticklabel', x_cell)
ylim([0 120])
ax = gca;
ax.FontSize = 14;

% xlabel('scenario')
ylabel('$bn (pv)')

if save_fig == 1
	outfilename = 'sim_results_summary_figs';
	print(outfilename,'-dpdf', '-fillpage') %'-bestfit'
end
