function [sim_idx, year_idx] = event_list_to_sim_year_idx(sim_num, month_start, month_dur)
%EVENT_LIST_TO_SIM_YEAR_IDX Indices for mapping events-by-month to sim-by-year.
%
%   [sim_idx, year_idx] = EVENT_LIST_TO_SIM_YEAR_IDX(sim_num, month_start, month_dur)
%
%   This helper encapsulates the indexing logic used in
%   event_list_simulation.m to map an event x month matrix into a
%   simulation x year matrix via accumarray.
%
%   Args:
%       sim_num     : E x 1 simulation indices for each event
%       month_start : E x 1 starting month for each event (1-based)
%       month_dur   : E x 1 duration in months for each event
%
%   Returns:
%       sim_idx  : flattened simulation indices for accumarray
%       year_idx : flattened year indices for accumarray

    arguments
        sim_num (:,1) {mustBeNumeric}
        month_start (:,1) {mustBeNumeric}
        month_dur (:,1) {mustBeNumeric}
    end

    sim_idx = repelem(sim_num, month_dur, 1);

    month_idx = cell2mat(arrayfun(@(s, d) (s:(s + d - 1))', ...
                          month_start, month_dur, ...
                          'UniformOutput', false));

    year_idx = floor((month_idx - 1) ./ 12) + 1;
end

