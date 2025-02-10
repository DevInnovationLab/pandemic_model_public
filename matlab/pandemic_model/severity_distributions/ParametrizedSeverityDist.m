
classdef ParametrizedSeverityDist < SeverityDist
    properties
        pd % Probability distribuion
        min_severity
        arrival_rate
    end
    
    methods
        function obj = ParametrizedSeverityDist(distName, arrival_rate, min_severity, max_severity, distParams)
            arguments
                distName (1,1) string
                arrival_rate (1,1) double {mustBeInRange(arrival_rate,0,1)}
                min_severity (1,1) double {mustBePositive}
                max_severity (1,1) double {mustBePositive}
                distParams
            end
            
            distParams = struct_to_named_args(distParams);
            obj.pd = makedist(distName, distParams{:});
            obj.min_severity = min_severity;
            obj.arrival_rate = arrival_rate;
            obj.max_severity = max_severity;
        end
        
        function severity = get_severity(obj, unifrnd_draw)
            severity = zeros(size(unifrnd_draw));

            % Rescale rank distribution for Pareto iCDF. 
            cum_prob_at_threshold = 1 - obj.arrival_rate;
            above_threshold = unifrnd_draw > cum_prob_at_threshold;
            rescaled_rank = (unifrnd_draw(above_threshold) - cum_prob_at_threshold) ./ obj.arrival_rate;

            severity(~above_threshold) = obj.min_severity;
            severity(above_threshold) = obj.pd.icdf(rescaled_rank);
            severity(severity > obj.max_severity) = obj.max_severity;
        end

        function rank = get_severity_rank(obj, severity)
            arguments
                obj
                severity (:,:) {mustBeNumeric}
            end

            rank = zeros(size(severity));
            cum_prob_at_threshold = 1 - obj.arrival_rate;
            rank(severity <= obj.min_severity) = cum_prob_at_threshold;
            rank(severity > obj.min_severity) = obj.pd.cdf(severity) .* obj.arrival_rate + cum_prob_at_threshold; % Rescale to interval
            rank(severity >= obj.max_severity) = 1;

        end
    end
end