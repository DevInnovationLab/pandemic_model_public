function [deaths, mortality_losses, output_losses, learning_losses, ...
          mortality_losses_nom, output_losses_nom, learning_losses_nom] = ...
    get_pandemic_losses(params, econ_loss_model, yr_start, pandemic_natural_dur, actual_dur, severity)

    % run simulation for a pandemic of significant size (not false pos)
    monthly_intensity = severity / (pandemic_natural_dur * 12);
    monthly_econ_loss = econ_loss_model.predict(monthly_intensity * 12) / 12; % Econ loss is predicted as % annual GPD loss from annual intensity
    actual_dur_months = actual_dur * 12;

    % Calculate growth rate and pv factor
    months_arr = (1:actual_dur_months)';
    growth_rate = (1+params.y)^(yr_start-1) .* (1+params.y).^(1/12 .* months_arr);
    PV_factor = (1/(1+params.r))^(yr_start-1) .* (1/(1+params.r)).^(1/12 .* months_arr); % Discount factor

    % Calc losses
    deaths = params.P0 / 10000 .* monthly_intensity .* ones(size(months_arr));

    % Calculate nominal losses first
    mortality_losses_nom = params.value_of_death .* deaths .* growth_rate; % nominal mortality losses
    output_losses_nom = (params.Y0 .* params.P0) .* monthly_econ_loss .* growth_rate; % nominal output losses
    learning_losses_nom = (10/13.8) .* output_losses_nom; % nominal learning losses

    % Apply discount factor to get PV losses
    mortality_losses = mortality_losses_nom .* PV_factor;
    output_losses = output_losses_nom .* PV_factor;
    learning_losses = learning_losses_nom .* PV_factor;
end