classdef ParametrizedDurationDist < DurationDist
    properties
        pd
        min_duration
    end

    methods
        function obj = ParametrizedDurationDist(dist_name, dist_params, max_duration, min_duration)
            arguments
                dist_name
                dist_params
                max_duration = Inf
                min_duration = 1
            end
            obj.max_duration = max_duration;
            obj.min_duration = min_duration;
            dist_params = struct_to_named_args(dist_params);
            obj.pd = truncate(makedist(dist_name, dist_params{:}), obj.min_duration - 0.5, obj.max_duration + 0.5); % Assuming we want discretized by increments of one.
        end

        function duration = get_duration(obj, unifrnd_draw)
            duration = round(obj.pd.icdf(unifrnd_draw)); % Rounding to nearest integer, so will sometimes have zero. Ask if this is correct.
            duration(duration > obj.max_duration) = obj.max_duration; % Eedge case at extreme where rounding takes you above max duration.
        end
    end
end