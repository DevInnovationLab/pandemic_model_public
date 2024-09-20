classdef ArrivalDist
    properties
        max_severity
    end
    
    methods (Abstract)
        severity = get_severity(obj, unifrnd_draw)
    end
end
