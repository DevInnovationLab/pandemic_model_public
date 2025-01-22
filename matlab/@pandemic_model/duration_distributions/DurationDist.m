% Define duration distribution interface
classdef DurationDist
    properties
        max_duration = Inf
    end

    methods (Abstract)
        duration = get_duration(obj, unifrnd_draw)
    end
end