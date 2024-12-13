function h = plot_realized_intensity_exceedance(simulation_table, min_severity_exceed_prob, sim_periods, num_simulations)

    intensity = sort(simulation_table.intensity);
    cd = (1:numel(intensity)) ./ (sim_periods * num_simulations); % Cumulative density
    exceedance = (1 - cd) * min_severity_exceed_prob;

    h = histogram(simulation_table.intensity, 'Normalization', 'probability');
    h.Values = h.Values .* min_severity_exceed_prob;

    xlabel("")
end