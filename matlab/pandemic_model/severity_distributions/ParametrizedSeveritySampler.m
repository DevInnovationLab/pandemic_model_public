classdef ParametrizedSeveritySampler < SeverityDist
    properties
        min_severity
        param_table
        lower_bound % Added this property as a hacky fix to make compatible with legacy code.
    end

    methods
        function obj = ParametrizedSeveritySampler(param_table, min_severity, max_severity)
            % Create a severity sampler that samples from multiple parameter combinations
            %
            % Args:
            %   dist_name: Name of the distribution to sample from
            %   param_table: Table containing parameter combinations, one row per draw
            %   max_severity: Maximum allowed severity
            arguments
                param_table
                min_severity (1,1) double {mustBePositive}
                max_severity (1,1) double {mustBePositive}
            end

            obj.min_severity = min_severity;
            obj.lower_bound = min_severity;
            obj.max_severity = max_severity;
            obj.param_table = param_table;
        end

        function severity = get_severity(obj, unifrnd_draw)
            % Sample severities using parameter combinations from param_table
            %
            % Args:
            %   unifrnd_draw: Matrix of uniform random draws, must have same number
            %                 of rows as param_table
            %
            % Returns:
            %   severity: Vector of sampled severities
            
            assert(size(unifrnd_draw,1) == height(obj.param_table), ...
                'Number of draws must match number of parameter combinations');

            severity = zeros(size(unifrnd_draw));

            cum_prob_at_threshold = 1 - obj.param_table.p;
            [row_idx, col_idx] = find(unifrnd_draw > cum_prob_at_threshold);
            linear_idx = sub2ind(size(unifrnd_draw), row_idx, col_idx);
            rescaled_rank = (unifrnd_draw(linear_idx) - cum_prob_at_threshold(row_idx)) ./ obj.param_table.p(row_idx);

            severity(:) = obj.min_severity;
            severity(linear_idx) = gpinv(rescaled_rank, obj.param_table.xi(row_idx), obj.param_table.sigma(row_idx), obj.min_severity);
            severity(severity > obj.max_severity) = obj.max_severity;
        end

        function rank = get_severity_rank(obj, severity)
            % Get rank (CDF value) for given severity values
            %
            % Args:
            %   severity: Vector of severity values
            %
            % Returns:
            %   rank: Vector of CDF values
            
            rank = zeros(size(severity));

            cum_prob_at_threshold = 1 - obj.param_table.p;
            rank(severity <= obj.min_severity) = cum_prob_at_threshold;
            rank(severity > obj.min_severity) = gpcdf(severity, obj.param_table.xi, obj.param_table.sigma, obj.min_severity) .* obj.param_table.p + cum_prob_at_threshold; % Rescale to interval
            rank(severity >= obj.max_severity) = 1;
        end

        function severity = ppf(obj, unifrnd_draw)
            severity = obj.get_severity(unifrnd_draw);
        end

        function rank = cdf(obj, severity)
            rank = obj.get_severity_rank(severity);
        end
    end
end