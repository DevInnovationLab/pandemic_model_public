classdef EconLossModel 
    properties
        family
        intercept
        coefs
    end

    methods
        function obj = EconLossModel(family, intercept, coefs)
            arguments
                family (1,1) {mustBeMember(family, {'linear', 'poisson', 'loglogreg'})}
                intercept (1, 1) {mustBeNumeric}
                coefs (:, 1) {mustBeNumeric}
            end

            obj.family = family;
            obj.intercept = intercept;
            obj.coefs = coefs;
        end

        % Predict share GDP loss (fraction)
        function y_hat = predict(obj, intensity)
            arguments
                obj
                intensity (:,:) {mustBeNumeric}
            end

            if height(obj.coefs) ~= width(intensity)
                error("Matrices must conform")
            end

            if obj.family == "loglogreg"
                y_hat = exp(log(intensity) * obj.coefs+ obj.intercept);
            elseif obj.family == "linear"
                y_hat = log(intensity) * obj.coefs + obj.intercept;
            elseif obj.family == "poisson"
                y_hat = exp(log(intensity) * obj.coefs + obj.intercept);
            end
        end
    end
end