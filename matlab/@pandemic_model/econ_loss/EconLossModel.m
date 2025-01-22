classdef EconLossModel 
    properties
        family
        intercept
        coefs
    end

    methods
        function obj = EconLossModel(family, intercept, coefs)
            arguments
                family (1,1) {mustBeMember(family, {'linear', 'poisson'})}
                intercept (1, 1) {mustBeNumeric}
                coefs (:, 1) {mustBeNumeric}
            end

            obj.family = family;
            obj.intercept = intercept;
            obj.coefs = coefs;
        end

        function y_hat = predict(obj, severity)
            arguments
                obj
                severity (:,:) {mustBeNumeric}
            end

            if height(obj.coefs) ~= width(severity)
                error("Matrices must conform")
            end

            if obj.family == "linear"
                y_hat = log(severity) * obj.coefs + obj.intercept;
            end

            if obj.family == "poisson"
                y_hat = exp(log(severity) * obj.coefs + obj.intercept);
            end
        end
    end
end