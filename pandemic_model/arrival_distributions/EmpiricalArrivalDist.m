classdef EmpiricalArrivalDist < ArrivalDist
    properties
        severity_values
        exceed_probs
    end
    
    methods
        function obj = EmpiricalArrivalDist(severity_values, exceed_probs, interp_method)
            arguments
                severity_values (:,1) {mustBeNumeric, mustBeReal, mustBePositive}
                exceed_probs (:,1) {mustBeNumeric, mustBeReal, mustBePositive, mustBeLessThanOrEqual(exceed_probs, 1)}
                interp_method (1,1) {mustBeMember(interp_method, ["linear","spline","pchip"])} = "spline"
            end

            % Ensure severity_values and exceed_probs are the same size
            mustBeSameSize(severity_values, exceed_probs)
            obj.severity_values = severity_values;
            obj.exceed_probs = exceed_probs;
            obj.max_severity = max(severity_values);
            obj.interp_method = interp_method;
        end
        
        function severity = get_severity(obj, unifrnd_draw)
            % Implement log interpolation later if you'd like
            severity = interp1(obj.exceed_probs, obj.severity_values, unifrnd_draw, interp_method, 'extrap');
            % severity(severity < obj.min_severity) = obj.min_severity;
            severity(severity > obj.max_severity) = obj.max_severity;
        end
    end
end