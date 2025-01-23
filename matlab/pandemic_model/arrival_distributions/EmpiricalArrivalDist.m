classdef EmpiricalArrivalDist < ArrivalDist
    properties
        severity_values
        exceed_probs
        interp_method
        loginterp
    end
    
    methods
        function obj = EmpiricalArrivalDist(severity_values, exceed_probs, interp_method, loginterp)
            arguments
                severity_values (:,1) {mustBeNumeric, mustBeReal, mustBePositive, mustBeIncreasing}
                exceed_probs (:,1) {mustBeNumeric, mustBeReal, mustBePositive, mustBeDecreasing, mustBeLessThanOrEqual(exceed_probs, 1)}
                interp_method (1,1) {mustBeMember(interp_method, ["linear", "spline", "pchip"])} = "linear"
                loginterp (1,1) {mustBeNumericOrLogical} = true
            end

            % Ensure severity_values and exceed_probs are the same size
            mustBeSameSize(severity_values, exceed_probs);

            % Check if exceed_probs has a 1, if not add it and a corresponding 0 to severity_values
            % if exceed_probs(1) ~= 1
            %     exceed_probs = [1; exceed_probs];
            %     severity_values = [0; severity_values]; % Not zero so we can still log transform.
            % end

            obj.severity_values = severity_values;
            obj.exceed_probs = exceed_probs;
            obj.max_severity = max(severity_values);
            obj.interp_method = interp_method;
            obj.loginterp = loginterp;
        end
        

        function severity = get_severity(obj, unifrnd_draw)
            arguments
                obj
                unifrnd_draw {mustBeNumeric, mustBeReal, mustBeInUnitInterval}
            end

            % Implement log interpolation later if you'd like
            if obj.loginterp == true
                severity = exp(interp1(log(obj.exceed_probs), log(obj.severity_values), log(unifrnd_draw), obj.interp_method, 'extrap'));
            else
                severity = interp1(obj.exceed_probs, obj.severity_values, unifrnd_draw, obj.interp_method, 'extrap');
            end
            severity(severity < 0) = 0;
            % severity(severity < obj.min_severity) = obj.min_severity;
            severity(severity > obj.max_severity) = obj.max_severity;
        end


        function rank = get_severity_rank(obj, severity)
            arguments
                obj
                severity {mustBeNumeric, mustBeReal, mustBePositive}
            end

            if obj.loginterp == true
                exceed_prob = exp(interp1(log(obj.severity_values), log(obj.exceed_probs), log(severity), obj.interp_method, 'extrap'));
            else
                exceed_prob = interp1(obj.severity_values, obj.exceed_probs, severity, obj.interp_method, 'extrap');
            end

            exceed_prob(severity > obj.max_severity) = 0;
            exceed_prob(exceed_prob > 1) = 1;
            rank = 1 - exceed_prob;
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


function mustBeDecreasing(x)
    if ~all(diff(x) <= 0)
        eid = 'Input:notDecreasing';
        msg = 'Input must be a decreasing sequence.';
        error(eid, msg)
    end
end


function mustBeIncreasing(x)
    if ~all(diff(x) >= 0)
        eid = 'Input:notIncreasing';
        msg = 'Input must be an increasing sequence.';
        error(eid, msg)
    end
end


function mustBeInUnitInterval(x)
    if any(x < 0, 'all') || any(x > 1, 'all')
        eid = 'Input:notBetweenZeroAndOne';
        msg = 'Input must be between 0 and 1.';
        error(eid, msg)
    end
end
