classdef TPDSeverityDist < SeverityDist
    % Truncated Pareto Severity Distribution
    properties % Follows SciPy implementation
        b
        c
        loc
        scale
        min_severity
        arrival_rate
    end

    methods
        function obj = TPDSeverityDist(b, c, loc, scale, arrival_rate)
            % Constructor for truncated Pareto distribution
            % Args:
            %   b (double): Shape parameter
            %   arrival_rate (double): Probability of exceeding minimum severity
            %   min_severity (double): Minimum severity value
            %   max_severity (double): Maximum severity value
            %   scale (double): Scale parameter
            arguments
                b (1,1) double {mustBePositive}
                c (1,1) double {mustBePositive}
                loc (1,1) double {mustBeNumeric}
                scale (1,1) double {mustBePositive}
                arrival_rate (1,1) double {mustBeInRange(arrival_rate,0,1)}
            end
            
            obj.b = b;
            obj.c = c;
            obj.loc = loc;
            obj.scale = scale;
            obj.arrival_rate = arrival_rate;
            obj.min_severity = obj.scale + obj.loc;
            obj.max_severity = obj.c * obj.scale + obj.loc;
        end

        function prob = cdf(obj, x)
            % Cumulative distribution function for truncated Pareto distribution
            % Args:
            %   x (double): Input value(s)
            % Returns:
            %   prob (double): Probability that random variable is less than x
            arguments
                obj
                x {mustBeNumeric, mustBeReal}
            end
            
            % CDF formula for truncated Pareto
            numerator = 1 - ((x - obj.loc) / obj.scale)^-obj.b;
            denominator = 1 - (obj.c^-obj.b);
            prob = numerator ./ denominator;
            
            % Set probabilities for out-of-bounds values
            prob(x > obj.max_severity) = nan;
            prob(x < obj.min_severity) = 0;
        end

        function x = icdf(obj, prob)
            % Inverse cumulative distribution function for truncated Pareto distribution
            % Args:
            %   prob (double): Probability value(s) between 0 and 1
            % Returns:
            %   x (double): Corresponding quantile value(s)
            arguments
                obj
                prob {mustBeNumeric, mustBeReal}
            end
            
            x = obj.loc + obj.scale .* (1 - prob .* (1 - obj.c^-obj.b)).^(-1/obj.b);
        end

        function severity = get_severity(obj, unifrnd_draw)
            % Get severity value for given uniform random draw
            % Args:
            %   unifrnd_draw (double): Uniform random number between 0 and 1
            % Returns:
            %   severity (double): Corresponding severity value
            arguments
                obj
                unifrnd_draw {mustBeNumeric, mustBeReal, mustBeInRange(unifrnd_draw,0,1)}
            end
            
            severity = zeros(size(unifrnd_draw));

            % Rescale rank distribution for Pareto iCDF
            cum_prob_at_threshold = 1 - obj.arrival_rate;
            above_threshold = unifrnd_draw > cum_prob_at_threshold;
            rescaled_rank = (unifrnd_draw(above_threshold) - cum_prob_at_threshold) ./ obj.arrival_rate;

            severity(~above_threshold) = obj.min_severity;
            severity(above_threshold) = obj.icdf(rescaled_rank);
            severity(severity > obj.max_severity) = obj.max_severity;
        end

        function rank = get_severity_rank(obj, severity)
            % Get probability rank for given severity value
            % Args:
            %   severity (double): Severity value
            % Returns:
            %   rank (double): Corresponding probability rank
            arguments
                obj
                severity {mustBeNumeric, mustBeReal, mustBePositive}
            end
            
            rank = zeros(size(severity));
            cum_prob_at_threshold = 1 - obj.arrival_rate;
            rank(severity <= obj.min_severity) = cum_prob_at_threshold;
            rank(severity > obj.min_severity) = obj.cdf(severity) .* obj.arrival_rate + cum_prob_at_threshold;
            rank(severity >= obj.max_severity) = nan;
        end
    end
end