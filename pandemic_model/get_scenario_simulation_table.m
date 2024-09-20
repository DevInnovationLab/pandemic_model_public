% Would love to clean this up later.
function new_simulation_table = get_scenario_simulation_table(base_simulation_table, params)
	% add production state and pandemic natural dur to simulation scenarios table
    new_simulation_table = base_simulation_table;
    dur_thresholds = cumsum(params.pandemic_dur_probs);
    rd_thresholds = cumsum([params.p_b, params.p_m, params.p_o]);

	% Determine natural duration (1: one year, 2: two years, 3: three years)
    % Could move to base scenario generation.
	new_simulation_table.natural_dur = sum(new_simulation_table.draw_natural_dur >= dur_thresholds(1:2), 2) + 1;

    % Add surveillance outcomes
    new_simulation_table.prep_start_month = run_surveillance(new_simulation_table.posterior1, ...
                                                             new_simulation_table.posterior2, ...
                                                             new_simulation_table.is_false, ...
                                                             params.enhanced_surveillance, ...
                                                             params.surveillance_thresholds);

	% Handle RD benefits
	if params.has_RD == 1
		rd_eligible = new_simulation_table.yr_start > params.adv_RD_benefit_start;
		family_researched = ismember(new_simulation_table.pathogen_family, params.viral_families_researched);
		has_RD_benefit = rd_eligible & family_researched;
        new_simulation_table.has_RD_benefit = has_RD_benefit;

		% Adjust thresholds for RD benefits when research eligible
		rd_adjustment = params.RD_success_rate_increase_per_platform * [2, 1, 1];
		adjusted_thresholds = rd_thresholds + (cumsum(rd_adjustment) * has_RD_benefit);
		
		new_simulation_table.rd_state = sum(new_simulation_table.rd_state >= adjusted_thresholds, 2) + 1;
    else
        % Determine state (1: both, 2: mRNA only, 3: traditional only, 4: none)
        new_simulation_table.has_RD_benefit = false(size(new_simulation_table, 1), 1);
        new_simulation_table.rd_state = sum(new_simulation_table.rd_state >= rd_thresholds, 2) + 1;
	end

	% Identify and remove overlapping pandemics
	sorted_table = sortrows(new_simulation_table, {'sim_num', 'yr_start'});
	yr_end = sorted_table.yr_start + sorted_table.natural_dur - 1;
	
	% Identify overlapping pandemics within each simulation
	is_overlapping = [false; 
		sorted_table.sim_num(2:end) == sorted_table.sim_num(1:(end-1)) & ...
		sorted_table.yr_start(2:end) <= yr_end(1:(end-1))];
	
	% Keep only non-overlapping pandemics
	new_simulation_table = sorted_table(~is_overlapping, :);
	new_simulation_table = sortrows(new_simulation_table, {'sim_num', 'yr_start'});

    new_simulation_table.rd_state_desc = repmat({""}, size(new_simulation_table, 1), 1);
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==1) = {"both"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==2) = {"mRNA_only"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==3) = {"trad_only"};
    new_simulation_table.rd_state_desc(new_simulation_table.rd_state==4) = {"none"};
    new_simulation_table.rd_state_desc(isnan(new_simulation_table.rd_state)) = {"no_pandemic"};

end


function prep_start_month_arr = run_surveillance(posterior1, posterior2, is_false, enhanced_surveillance, threshold_surveil_arr)
	% only computes, no random number generation

	% Extract thresholds
	threshold_no_surveil = threshold_surveil_arr(1);
	threshold_surveil = threshold_surveil_arr(2);

	% Compute true state and prepare decisions
	prepare_decision1 = posterior1 > (enhanced_surveillance * threshold_surveil + ~enhanced_surveillance * threshold_no_surveil);
	prepare_decision2 = posterior2 > threshold_surveil;

	% Initialize prep_start_month_arr with default value
	prep_start_month_arr = 2 * ones(size(is_false));

	if enhanced_surveillance
		% Enhanced surveillance logic
		prep_start_month_arr(prepare_decision1) = 0;
		prep_start_month_arr(~prepare_decision1 & prepare_decision2) = 1;
	else
		% No surveillance logic
		prep_start_month_arr(prepare_decision1) = 1;
	end

	% Handle cases where no pandemic was correctly anticipated
	no_pandemic_correctly_anticipated = ((~enhanced_surveillance & ~prepare_decision1) | (enhanced_surveillance & ~prepare_decision1 & ~prepare_decision2));
	prep_start_month_arr(no_pandemic_correctly_anticipated) = NaN;

	% Ensure prep_start_month_arr is a column vector
	prep_start_month_arr = prep_start_month_arr(:);
end