classdef ParametrizedDurationDist < DurationDist
    properties
        pd
    end

    methods
        function obj = ParametrizedDurationDist(dist_name, dist_params, max_duration)
            arguments
                dist_name
                dist_params
                max_duration = Inf
            end

            obj.max_duration = max_duration;
            dist_params = struct_to_named_args(dist_params);
            obj.pd = makedist(dist_name, dist_params{:});
        end

        function duration = get_duration(obj, unifrnd_draw)
            duration = round(obj.pd.icdf(unifrnd_draw));
            duration(duration > obj.max_duration) = obj.max_duration; % Censor at max duration
        end
    end
end