function [ind_m, ind_o] = get_capacity_indicators(rd_state)
    % Get indicators for usable capacity types depending on which vaccine platforms succeeded.
    if rd_state == 1 % both successful
        ind_m = 1;
		ind_o = 1;
    elseif rd_state == 2 % only mRNA successful
        ind_m = 1;
		ind_o = 0;
    elseif rd_state == 3 % only traditional successful
        ind_m = 0;
		ind_o = 1;
    else % nothing is successful
        assert(rd_state == 4);
        ind_m = 0;
		ind_o = 0;
    end
end