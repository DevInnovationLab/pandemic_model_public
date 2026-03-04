classdef ArrivalDistSampler
    properties
        param_samples
        false_positive_rate
        trunc_method
        measure
    end

    methods
        function obj = ArrivalDistSampler(param_samples, trunc_method, false_positive_rate, measure)
            % Create a y_sample sampler that samples from multiple parameter combinations
            %
            % Args:
            %   dist_name: Name of the distribution to sample from
            %   param_table: Table containing parameter combinations, one row per draw
            %   max_y_sample: Maximum allowed y_sample
            arguments
                param_samples (:,5) table
                trunc_method (1,1) {mustBeMember(trunc_method, {'sharp', 'smooth'})}
                false_positive_rate (1,1) {mustBeNumeric, mustBeInRange(false_positive_rate, 0, 1)} = 0
                measure (1,1) string = "undefined"
            end

            obj.param_samples = param_samples;
            obj.false_positive_rate = false_positive_rate;
            obj.trunc_method = trunc_method;
            obj.measure = measure;
        end

        % ---------------------------------------------------------------------
        function y_sample = get_y_sample(obj, unifrnd_draw)
            % Draw severities from a GPD tail that is
            %  – left-truncated  at  min_y_sample  (threshold)
            %  – right-truncated at  max_y_sample
            %
            % The mass (1-p) sits at the threshold, the remaining p is spread
            % over (min_y_sample , max_y_sample].
            assert(height(unifrnd_draw) == height(obj.param_samples), 'First dimension of draws must match number of parameter samples');

            xi = obj.param_samples.xi;
            sigma = obj.param_samples.sigma;
            lambda_raw = obj.param_samples.lambda;
            mu = obj.param_samples.mu;
            max_val = obj.param_samples.max_value;
            y_sample = zeros(size(unifrnd_draw));

            % Adjust arrival probability for false positive rate
            lambda = lambda_raw ./ (1 - obj.false_positive_rate);

            % --- rescale uniforms to (0,1) conditional on being in the tail --------
            cum_prob_at_th = 1 - exp(-lambda);
            [row, col] = find(unifrnd_draw > cum_prob_at_th);
            lin_idx = sub2ind(size(unifrnd_draw), row, col);
            u_raw = (unifrnd_draw(lin_idx) - cum_prob_at_th(row)) ./ (exp(-lambda(row)));

            if strcmp(obj.trunc_method, "sharp")
                y_sample(lin_idx) = gpinv(u_raw, xi(row), sigma(row), mu(row));
                [row_over, col_over] = find(y_sample > max_val);
                y_sample(sub2ind([height(y_sample), width(y_sample)], row_over, col_over)) = max_val(row_over);
            elseif strcmp(obj.trunc_method, "smooth")
                F_max = gpcdf(max_val(row), xi(row), sigma(row), mu(row));
                u_trunc = u_raw .* F_max;
                y_sample(lin_idx) = gpinv(u_trunc, xi(row), sigma(row), mu(row));
                assert(all(y_sample <= max_val, 'all'));
            end
        end

        function rank = get_rank(obj, y_sample)
            % Truncated tail CDF mapped back to the mixed distribution:
            %   F_trunc(y) = (F(y) - F(threshold)) / (F(max) - F(threshold))
            %
            % Overall rank = (1-p)  on the atom  +  p · F_trunc(y)
            
            assert(~any(y_sample > obj.param_samples.max_value, 'all'), "Some values exceed the max values.");

            xi = obj.param_samples.xi;
            sigma = obj.param_samples.sigma;
            lambda_raw = obj.param_samples.lambda;
            mu = obj.param_samples.mu;
            max_val = obj.param_samples.max_value;
            rank = zeros(size(y_sample));

            % Adjust arrival probability for false positive rate
            lambda = lambda_raw ./ (1 - obj.false_positive_rate);
            cum_prob_at_th = 1 - exp(-lambda);

            % Case 1: at or below the threshold
            idx_th = y_sample <= mu;
            rank(idx_th) = cum_prob_at_th;

            % Case 2: between threshold and max_y_sample
            idx_mid = y_sample > mu & y_sample < max_val;
            [row_mid, ~] = find(idx_mid);
            idx_top = y_sample >= max_val;

            if strcmp(obj.trunc_method, "sharp")
                if any(idx_mid(:))
                    F_y = gpcdf(y_sample(idx_mid), xi(row_mid), sigma(row_mid), mu(row_mid));
                    rank(idx_mid) = cum_prob_at_th(row_mid) + exp(-lambda(row_mid)) .* F_y;
                    rank(idx_top) = 1.0;
                end
            elseif strcmp(obj.trunc_method, "smooth")
                if any(idx_mid(:))
                    F_y = gpcdf(severity(idx_mid), xi(row_mid), sigma(row_mid), mu(row_mid));
                    F_max = gpcdf(max_val(row_mid), xi(row_mid), sigma(row_mid), mu(row_mid)); 
                    rank(idx_mid) = cum_prob_at_th(row_mid) + exp(-lambda(row_mid)) .* (F_y ./ F_max);
                end
            end

            assert(all(isbetween(rank, 0, 1), 'all'));
        end

        function y_sample = ppf(obj, unifrnd_draw)
            y_sample = obj.get_y_sample(unifrnd_draw);
        end

        function rank = cdf(obj, y_sample)
            rank = obj.get_rank(y_sample);
        end
    end
end