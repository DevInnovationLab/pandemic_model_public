classdef ArrivalDist
    properties
        pd
        min_severity_exceed_prob
        min_severity
        max_severity
    end

    methods
        function adist = ArrivalDist(distName, min_severity_exceed_prob, min_severity, max_severity, distParams)
            distParams = struct_to_named_args(distParams);
            adist.pd = makedist(distName, distParams{:});
            adist.min_severity_exceed_prob = min_severity_exceed_prob;
            adist.min_severity = min_severity;
            adist.max_severity = max_severity;
        end
        
        function severity = get_severity(adist, unifrnd_draw)
            severity = zeros(size(unifrnd_draw));
            above_threshold = unifrnd_draw > (1 - adist.min_severity_exceed_prob);
            severity(~above_threshold) = adist.min_severity; % Could just set zeros.
            severity(above_threshold) = adist.pd.random(size(unifrnd_draw(above_threshold)));
            severity(severity > adist.max_severity) = adist.max_severity;
        end

    end

end