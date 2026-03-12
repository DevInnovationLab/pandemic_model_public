function sim_year_matrix = event_list_to_sim_year(values_matrix, sim_idx, year_idx, num_sims, max_years, accum_idx)
%EVENT_LIST_TO_SIM_YEAR Convert event x month matrix to simulation x year matrix.
%
%   sim_year_matrix = EVENT_LIST_TO_SIM_YEAR(values_matrix, sim_idx, year_idx, num_sims, max_years, accum_idx)
%
%   This helper mirrors the logic used in event_list_simulation.m to
%   aggregate event-by-month quantities into simulation-by-year totals.
%
%   Args:
%       values_matrix : E x M matrix of values
%       sim_idx       : flattened simulation indices (from event_list_to_sim_year_idx)
%       year_idx      : flattened year indices (from event_list_to_sim_year_idx)
%       num_sims      : number of simulations
%       max_years     : maximum number of years
%       accum_idx     : E x M logical matrix indicating which entries to accumulate
%
%   Returns:
%       sim_year_matrix : num_sims x max_years matrix of aggregated values

    arguments
        values_matrix (:,:) {mustBeNumeric}
        sim_idx (:,1) {mustBeNumeric}
        year_idx (:,1) {mustBeNumeric}
        num_sims (1,1) {mustBeNumeric}
        max_years (1,1) {mustBeNumeric}
        accum_idx (:,:) {mustBeNumeric}
    end

    values_mat_t = values_matrix.';
    values = values_mat_t((accum_idx == 1).');

    sim_year_matrix = accumarray([sim_idx, year_idx], ...
                                 values, ...
                                 [num_sims, max_years], ...
                                 @sum, ...
                                 0);
end

