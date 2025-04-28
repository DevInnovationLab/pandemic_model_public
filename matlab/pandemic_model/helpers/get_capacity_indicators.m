function [ind_m, ind_o] = get_capacity_indicators(rd_state)
    % Get indicators for usable capacity types depending on which vaccine platforms succeeded.
    assert(ismember(rd_state, 1:4), 'rd_state must be 1-4');
    ind_m = double(ismember(rd_state, [1, 2]));  % 1 if mRNA platform is available
    ind_o = double(ismember(rd_state, [1, 3]));  % 1 if traditional platform is available
end