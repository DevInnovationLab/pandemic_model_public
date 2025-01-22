function [deaths, mortality_losses, output_losses, learning_losses] = ...
    get_pandemic_losses(params, econ_loss_model, yr_start, pandemic_natural_dur, actual_dur, severity)

	% run simulation for a pandemic of significant size (not false pos)
    monthly_intensity = severity / (pandemic_natural_dur * 12);
    monthly_econ_loss = econ_loss_model.predict(severity) / (pandemic_natural_dur * 12); % total months of pandemic
    actual_dur_months = actual_dur * 12;

	% Calculate growth rate and pv factor
    months_arr = (1:actual_dur_months)';
    growth_rate = (1+params.y)^(yr_start-1) .* (1+params.y).^(1/12 .* months_arr);
    PV_factor = (1/(1+params.r))^(yr_start-1) .* (1/(1+params.r)).^(1/12 .* months_arr); % Discount factor

    % Calc losses
    deaths = params.P0 / 10000 .* monthly_intensity .* growth_rate; % Growth rate accounts for population growth.
    mortality_losses = params.value_of_death .* deaths .* PV_factor; % mortality lossses during pandemic
    output_losses = (params.Y0 .* params.P0 / 100) .* monthly_econ_loss .* growth_rate .* PV_factor; % output losses for during pandemic
    learning_losses = (10/13.8) .* output_losses; 
end