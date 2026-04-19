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

        function rank = get_rank(obj, duration)
            % Get the cumulative probability at each duration value
            %
            % Args:
            %   duration: Vector of duration values, must have same number
            %             of rows as param_table
            %
            % Returns:
            %   rank: Cumulative probability at each duration
            
            assert(size(duration,1) == height(obj.param_table), ...
                'Number of draws must match number of parameter combinations');

            % For durations at or above max, return 1
            rank = ones(size(duration));
            
            % For durations below max, compute CDF
            idx_below = duration < obj.max_duration;
            if any(idx_below)
                y = duration(idx_below) - obj.param_table.loc(idx_below);
                rank(idx_below) = logncdf(y, obj.param_table.mu(idx_below), obj.param_table.sigma(idx_below));
            end
        end

        function mass = get_integer_mass(obj, duration)
            % Get the probability mass at each integer duration value
            % This is the cumulative mass between duration-0.5 and duration+0.5
            %
            % Args:
            %   duration: Vector of integer duration values, must have same number
            %             of rows as param_table
            %
            % Returns:
            %   mass: Probability mass at each integer duration
            
            assert(size(duration,1) == height(obj.param_table), ...
                'Number of draws must match number of parameter combinations');
            
            % Get CDF at duration + 0.5 and duration - 0.5
            upper_bound = duration + 0.5;
            lower_bound = duration - 0.5;
            
            % Handle truncation at max_duration
            upper_bound(upper_bound > obj.max_duration) = obj.max_duration;
            lower_bound(lower_bound < obj.param_table.loc) = obj.param_table.loc(lower_bound < obj.param_table.loc);
            
            % Compute mass as difference in CDFs
            y_upper = upper_bound - obj.param_table.loc;
            y_lower = lower_bound - obj.param_table.loc;
            
            cdf_upper = logncdf(y_upper, obj.param_table.mu, obj.param_table.sigma);
            cdf_lower = logncdf(y_lower, obj.param_table.mu, obj.param_table.sigma);
            
            mass = cdf_upper - cdf_lower;
            
            % For durations at max, add any remaining tail probability
            idx_at_max = (duration >= obj.max_duration);
            if any(idx_at_max)
                y_max = obj.max_duration - obj.param_table.loc(idx_at_max);
                cdf_at_max = logncdf(y_max, obj.param_table.mu(idx_at_max), obj.param_table.sigma(idx_at_max));
                mass(idx_at_max) = 1 - cdf_at_max;
            end
        end
    end
end
