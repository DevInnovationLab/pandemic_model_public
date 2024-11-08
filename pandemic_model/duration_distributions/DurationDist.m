% Define duration distribution interface
classdef DurationDist
    properties
        max_duration
    end

    methods (Abstract)
        duration = get_duration(obj, unifrnd_draw)
    end
end