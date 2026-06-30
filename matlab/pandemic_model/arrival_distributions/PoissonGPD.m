classdef PoissonGPD
    properties
        lambda
        xi
        sigma
        mu
        max_value
    end

    methods
        function obj = PoissonGPD(lambda, xi, sigma, mu, max_value)
            arguments
                lambda (:,1) {mustBeNumeric}
                xi (:,1) {mustBeNumeric}
                sigma (:,1) {mustBeNumeric}
                mu (:,1) {mustBeNumeric}
                max_value (:,1) {mustBeNumeric}
            end

            obj.lambda = lambda;
            obj.xi = xi;
            obj.sigma = sigma;
            obj.mu = mu;
            obj.max_value = max_value;
        end

        function cdf = cdf(obj, x)
            [lam, xi_, sig, mu_, maxv] = obj.expandParamsToSize(size(x));

            below_t = x <= mu_;
            above_t = x > mu_;
            above_m = x > maxv;

            cdf = zeros(size(x));
            cdf(below_t) = exp(-lam(below_t));
            cdf(above_t) = exp(-lam(above_t) .* (1 - gpcdf(x(above_t), xi_(above_t), sig(above_t), mu_(above_t))));
            cdf(above_m) = 1;
        end

        function icdf = icdf(obj, p)
            [lam, xi_, sig, mu_, maxv] = obj.expandParamsToSize(size(p));

            below_t = p <= exp(-lam);
            above_t = p > exp(-lam);
            above_m = p >= obj.cdf(maxv);

            icdf = zeros(size(p));
            icdf(below_t) = mu_(below_t);
            icdf(above_t) = gpinv(1 + log(p(above_t)) ./ lam(above_t), xi_(above_t), sig(above_t), mu_(above_t));
            icdf(above_t) = min(icdf(above_t), maxv(above_t));
            icdf(above_m) = maxv(above_m);
        end

        function sf = sf(obj, x)
            sf = 1 - obj.cdf(x);
        end
    end

    methods (Access = private)
        function [lam, xi_, sig, mu_, maxv] = expandParamsToSize(obj, sz)
            % Expands parameter vectors to the given size for correct broadcasting.
            % Returns arrays of size sz matching obj.lambda, obj.xi, obj.sigma, obj.mu, obj.max_value.
            lam = obj.lambda .* ones(sz);
            xi_ = obj.xi .* ones(sz);
            sig = obj.sigma .* ones(sz);
            mu_ = obj.mu .* ones(sz);
            maxv = obj.max_value .* ones(sz);
        end
    end
end