% Define arrival distribution interface
classdef ArrivalDist
    properties
        max_severity
    end
    
    methods (Abstract)
        severity = get_severity(obj, unifrnd_draw)
        rank = get_severity_rank(obj, severity)
    end
end
