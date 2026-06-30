% Define duration distribution interface
classdef DurationDist
    methods (Abstract)
        duration = get_duration_months(obj, unifrnd_draw)
    end
end
