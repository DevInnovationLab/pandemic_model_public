classdef DurationSampler < DurationDist
    properties
        dist_name
        param_table
    end

    methods
        function obj = DurationSampler(param_table)
            % Create a duration sampler that samples from multiple parameter combinations
            %
            % Args:
            %   dist_name: Name of the distribution to sample from
            %   param_table: Table containing parameter combinations, one row per draw
            %   max_duration: Maximum allowed duration (default: Inf)
            arguments
                param_table
            end

            obj.param_table = param_table;
            assert(all(param_table.trunc_value == param_table.trunc_value(1), 'all'));
            obj.max_duration = param_table.trunc_value(1);
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
            y = logninv(unifrnd_draw, obj.param_table.mu, obj.param_table.sigma);
            duration = round(y + obj.param_table.loc);

            duration(duration > obj.max_duration) = obj.max_duration;
        end
    end
end
