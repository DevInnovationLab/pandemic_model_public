function [ind_m, ind_o] = get_capacity_indicators(rd_state)
    % Return binary platform-availability indicators from rd_state codes.
    %
    % Uses rd_state_codes() to decode whether each vaccine platform succeeded.
    %
    % Args:
    %   rd_state  [E x 1] Integer codes (1=both, 2=mRNA, 3=trad, 4=none) or NaN.
    %
    % Returns:
    %   ind_m  [E x 1] double; 1 if mRNA platform active, 0 otherwise.
    %   ind_o  [E x 1] double; 1 if traditional platform active, 0 otherwise.
    c = rd_state_codes();
    assert(all(ismember(rd_state, 1:4) | isnan(rd_state)), 'rd_state must be 1-4 or NaN');
    ind_m = double(ismember(rd_state, [c.both, c.mrna]));
    ind_o = double(ismember(rd_state, [c.both, c.trad]));
end