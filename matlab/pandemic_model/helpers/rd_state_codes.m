function codes = rd_state_codes()
% Return named constants for the rd_state encoding.
%
% rd_state encodes which vaccine platform(s) succeeded:
%   1 = both mRNA and traditional succeeded
%   2 = mRNA only
%   3 = traditional only
%   4 = neither (no vaccine)
%
% Usage:
%   c = rd_state_codes();
%   new_simulation_table.rd_state(:) = c.none;
    codes.both  = 1;
    codes.mrna  = 2;
    codes.trad  = 3;
    codes.none  = 4;
end
