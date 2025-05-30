classdef DurationSampler < DurationDist
    properties
        dist_name
        param_table
    end

    methods
        function obj = DurationSampler(param_table, max_duration)
            % Create a duration sampler that samples from multiple parameter combinations
            %
            % Args:
            %   dist_name: Name of the distribution to sample from
            %   param_table: Table containing parameter combinations, one row per draw
            %   max_duration: Maximum allowed duration (default: Inf)
            arguments
                param_table
                max_duration = Inf
            end

            obj.max_duration = max_duration;
            obj.param_table = param_table;
        end

        function duration = get_duration(obj, unifrnd_draw)
            % Sample durations using parameter combinations from param_table
            %
            % Args:
            %   unifrnd_draw: Matrix of uniform random draws, must have same number
            %                 of rows as param_table
            %
            % Returns:
            %   duration: Vector of sampled durations
            
            assert(size(unifrnd_draw,1) == height(obj.param_table), ...
                'Number of draws must match number of parameter combinations');
            
            % Note that the below might run slowly. You should profile it.
            duration = round(logninv(unifrnd_draw, obj.param_table.mu, obj.param_table.sigma));

            duration(duration > obj.max_duration) = obj.max_duration;
        end
    end
end
