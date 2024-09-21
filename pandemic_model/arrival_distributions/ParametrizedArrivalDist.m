
classdef ParametrizedArrivalDist < ArrivalDist
    properties
        pd
        min_severity
        min_severity_exceed_prob
    end
    
    methods
        function obj = ParametrizedArrivalDist(distName, min_severity_exceed_prob, min_severity, max_severity, distParams)
            obj.min_severity = min_severity;
            obj.max_severity = max_severity;
            obj.min_severity_exceed_prob = min_severity_exceed_prob;
            distParams = struct_to_named_args(distParams);
            obj.pd = makedist(distName, distParams{:});
        end
        
        function severity = get_severity(obj, unifrnd_draw)
            severity = zeros(size(unifrnd_draw));

            % Rescale rank distribution for Pareto iCDF. 
            cum_prob_at_threshold = (1 - obj.min_severity_exceed_prob);
            above_threshold = unifrnd_draw > cum_prob_at_threshold;
            rescaled_rank = (unifrnd_draw(above_threshold) - cum_prob_at_threshold) .* (1 ./ obj.min_severity_exceed_prob);

            severity(~above_threshold) = obj.min_severity;
            severity(above_threshold) = obj.pd.icdf(rescaled_rank);
            severity(severity > obj.max_severity) = obj.max_severity;
        end
    end
end