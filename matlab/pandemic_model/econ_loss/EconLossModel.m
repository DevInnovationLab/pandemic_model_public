classdef EconLossModel 
    properties
        family
        intercept
        coefs
        input_variable
    end

    methods
        function obj = EconLossModel(family, intercept, coefs, input_variable)
            arguments
                family (1,1) {mustBeMember(family, {'linear', 'poisson', 'loglogreg'})}
                intercept (1, 1) {mustBeNumeric}
                coefs (:, 1) {mustBeNumeric}
                input_variable (1, 1) string = "unknown"
            end

            obj.family = family;
            obj.intercept = intercept;
            obj.coefs = coefs;
            obj.input_variable = input_variable;
        end

        % Predict share GDP loss (fraction)
        function y_hat = predict(obj, x, variable_name)
            arguments
                obj
                x (:,:) {mustBeNumeric}
                variable_name (1, 1) string = ""
            end

            if height(obj.coefs) ~= width(x)
                error("Matrices must conform")
            end

            if variable_name ~= "" && obj.input_variable ~= "unknown" && variable_name ~= obj.input_variable
                error("EconLossModel:InputVariableMismatch", ...
                    "Model was estimated on '%s' but predict was called with '%s'.", ...
                    obj.input_variable, variable_name);
            end

            if obj.family == "loglogreg"
                y_hat = exp(log(x) * obj.coefs + obj.intercept);
            elseif obj.family == "linear"
                y_hat = log(x) * obj.coefs + obj.intercept;
            elseif obj.family == "poisson"
                y_hat = exp(log(x) * obj.coefs + obj.intercept);
            end
        end
    end
end