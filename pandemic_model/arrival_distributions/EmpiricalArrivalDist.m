classdef EmpiricalArrivalDist < ArrivalDist
    properties
        severity_values
        exceed_probs
        interp_method
    end
    
    methods
        function obj = EmpiricalArrivalDist(severity_values, exceed_probs, interp_method)
            arguments
                severity_values (:,1) {mustBeNumeric, mustBeReal, mustBePositive}
                exceed_probs (:,1) {mustBeNumeric, mustBeReal, mustBePositive, mustBeLessThanOrEqual(exceed_probs, 1)}
                interp_method (1,1) {mustBeMember(interp_method, ["linear", "loglinear", "spline","pchip"])} = "loglinear"
            end

            % Ensure severity_values and exceed_probs are the same size
            mustBeSameSize(severity_values, exceed_probs);
            obj.severity_values = severity_values;
            obj.exceed_probs = exceed_probs;
            obj.max_severity = max(severity_values);
            obj.interp_method = interp_method;
        end
        
        function severity = get_severity(obj, unifrnd_draw)
            % Implement log interpolation later if you'd like
            if obj.interp_method == "loglinear"
                severity = interp1(log(obj.exceed_probs), log(obj.severity_values), unifrnd_draw, obj.interp_method, 'extrap');
            else
                severity = interp1(obj.exceed_probs, obj.severity_values, unifrnd_draw, obj.interp_method, 'extrap');
            end
            severity(severity < 0 ) = 0;
            % severity(severity < obj.min_severity) = obj.min_severity;
            severity(severity > obj.max_severity) = obj.max_severity;
        end
    end
end

function mustBeSameSize(a,b)
    % Test for equal size
    if ~isequal(size(a),size(b))
        eid = 'Size:notEqual';
        msg = 'Inputs must have equal size.';
        error(eid,msg)
    end
end