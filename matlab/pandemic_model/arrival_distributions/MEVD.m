classdef MEVD
    properties
        base_pd
        window_counts
        non_zero_window_counts
        base_dist
        trunc_method
        lower_bound
        upper_bound
    end
    
    methods
        function obj = MEVD(window_counts, dist_name, base_dist_params, trunc_method, upper_bound)
            % MEVD Metastatistical Extreme Value Distribution
            %
            % Metastatistical Extreme Value Distribution (MEVD) built from a base distribution
            % representing individual observations, then averaged over windows
            % using observation counts as geometric weights.
            %
            % For each window i with n_i observations, the maximum's CDF is:
            %     F_i(x) = [F_base(x)]^(n_i).
            %
            % The overall MEVD is:
            %     F_MEVD(x) = (1/N) * Σ_i [F_base(x)]^(n_i),
            % where N is the number of windows.
            %
            % Parameters:
            %   window_counts - Array of sizes for each window (n_i)
            %   dist_name - String specifying the base distribution type
            %   base_dist_params - Structure with parameters for the base distribution
            %   trunc_method - String specifying truncation type ('sharp' or 'smooth')
            %   upper_bound - Maximum value for truncation (default: Inf)
            arguments
                window_counts (:,1) {mustBeInteger, mustBeNonnegative}
                dist_name (1,1) string
                base_dist_params struct
                trunc_method (1,1) string {mustBeMember(trunc_method, ["sharp", "smooth"])}
                upper_bound (1,1) double {mustBePositive} = Inf
            end
            obj.window_counts = window_counts;
            obj.non_zero_window_counts = window_counts(window_counts > 0);

            pd_params = struct_to_named_args(base_dist_params);
            obj.base_pd = makedist(dist_name, pd_params{:});
            obj.lower_bound = base_dist_params.theta;
            obj.trunc_method = trunc_method;
            obj.upper_bound = upper_bound;
        end
        
        function F = base_cdf(obj, x)
            % Compute the CDF of the base distribution
            if obj.trunc_method == "sharp"
                F = obj.base_pd.cdf(x);
                F(x >= obj.upper_bound) = 1;
                
            elseif obj.trunc_method == "smooth"
                F_u = obj.base_pd.cdf(obj.upper_bound);
                F = obj.base_pd.cdf(x) ./ F_u;
                F(x >= obj.upper_bound) = 1;
            end
        end
        
        function f = base_pdf(obj, x)
            % Compute the PDF of the base distribution
            if obj.trunc_method == "sharp"
                f = obj.base_pd.pdf(x);
 
            elseif obj.trunc_method == "smooth"
                F_u = obj.base_pd.cdf(obj.upper_bound);
                f = obj.base_pd.pdf(x) ./ F_u;
                f(x >= obj.upper_bound) = 0;
            end
        end
        
        function F = cdf(obj, x)
            % CDF of the MEVD: F_MEVD(x) = (1/N) * sum_{i=1}^N [F_base(x)]^(n_i)
            F_base = obj.base_cdf(x);
            
            F_base_mat = repmat(F_base(:)', length(obj.window_counts), 1);
            window_counts_mat = repmat(obj.window_counts, 1, numel(x));
            
            % Element-wise power and mean across windows
            F_powers = F_base_mat .^ window_counts_mat;
            F = mean(F_powers, 1);
            
            % Reshape to match input dimensions
            F = reshape(F, size(x));
        end
        
        function f = pdf(obj, x)
            % PDF of the MEVD: f_MEVD(x) = (1/N) * sum_{i=1}^N n_i [F_base(x)]^(n_i-1) * f_base(x)
            F_base = obj.base_cdf(x); % (m, n)
            f_base = obj.base_pdf(x); % (m, n)
            
            % Use matrix operations for vectorized computation
            % Only consider non-zero window counts for efficiency
            F_base_mat = repmat(F_base(:)', length(obj.non_zero_window_counts), 1); % (k, m x n)
            f_base_mat = repmat(f_base(:)', length(obj.non_zero_window_counts), 1); % (k, m x n)
            counts_mat = repmat(obj.non_zero_window_counts, 1, numel(x)); % (k, m x n)
            
            % Element-wise operations
            pdf_terms = counts_mat .* (F_base_mat .^ (counts_mat - 1)) .* f_base_mat; % (k, m x n)
            f = mean(pdf_terms, 1); % (1, m x n)
            
            % Reshape to match input dimensions
            f = reshape(f, size(x)); % (m, n)
        end
        
        function x = ppf(obj, q, min_x, max_x, options)
            % Percent point function (inverse of CDF) using numerical methods
            %
            % Computes the inverse of the CDF (quantile function) using Newton-Raphson method
            % with safeguards for numerical stability, especially for extreme quantiles.
            %
            % Parameters:
            %   q - Probability values in range [0,1] for which to compute quantiles
            %   min_x - Lower bound for the solution (default: obj.lower_bound)
            %   max_x - Upper bound for the solution (default: obj.upper_bound)
            %   options.max_iter - Maximum number of iterations (default: 20)
            %   options.abstol - Absolute tolerance for convergence (default: 1e-4)
            %   options.reltol - Relative tolerance for convergence (default: 1e-6)
            %   options.bisect_fallback - Whether to use bisection as fallback (default: true)
            
            arguments
                obj
                q {mustBeNumeric, mustBeReal, mustBeInRange(q, 0, 1)}
                min_x double = obj.lower_bound
                max_x double = obj.upper_bound
                options.max_iter double = 1000
                options.abstol double = 1e-8
                options.reltol double = 1e-6
                options.bisect_fallback logical = true
            end

            % Handle edge cases
            q_const = sum(obj.window_counts == 0) / length(obj.window_counts);
            x = zeros(size(q));
            x(q <= q_const) = min_x;
            x(q >= 1) = max_x;
            
            % Find indices that need solving
            mask = (q > q_const) & (q < 1);
            if ~any(mask(:))
                return
            end
            
            % Extract values that need solving
            q_solve = q(mask);
            
            % Initial guess using exponential spacing
            x_current = exp(log(min_x) + (log(max_x) - log(min_x)) * q_solve);
            x_lower = min_x * ones(size(q_solve));
            x_upper = max_x * ones(size(q_solve));
            converged = false(size(q_solve));
            
            % Newton-Raphson method with safeguards
            for i = 1:options.max_iter
                % Compute CDF and PDF at current points
                cdf_vals = obj.cdf(x_current);
                pdf_vals = obj.pdf(x_current);
                
                % Update bounds based on CDF values
                too_low = cdf_vals < q_solve;
                too_high = cdf_vals > q_solve;
                x_lower(too_low) = x_current(too_low);
                x_upper(too_high) = x_current(too_high);
                
                % Avoid division by zero and very small PDF values
                valid_pdf = (pdf_vals > 1e-32);
                if ~any(valid_pdf)
                    break;
                end
                
                % Newton step with proper step limiting
                dx = zeros(size(x_current));
                dx(valid_pdf) = (cdf_vals(valid_pdf) - q_solve(valid_pdf)) ./ pdf_vals(valid_pdf);
                
                % More conservative step size for high quantiles
                high_q = q_solve > 0.99;
                if any(high_q & valid_pdf)
                    dx(high_q & valid_pdf) = dx(high_q & valid_pdf) * 0.3;  % Take smaller steps for high quantiles
                end
        
                % Adaptive step size based on distance to target and current value
                rel_error = abs(cdf_vals - q_solve) ./ max(q_solve, 1-q_solve);
                step_factor = 0.1 + 0.2 * exp(-5 * rel_error);  % Less aggressive damping
                dx = dx .* step_factor;
                
                x_new = x_current - dx;
                x_new = max(x_lower, min(x_upper, x_new));
                
                % Check convergence using both absolute and relative tolerance
                abs_diff = abs(x_new - x_current);
                rel_diff = abs_diff ./ (abs(x_current) + options.abstol);
                converged = (abs_diff < options.abstol) | (rel_diff < options.reltol);
                
                if all(converged)
                    x_current = x_new;
                    break;
                end
                
                % Update for next iteration, but only for non-converged points
                x_current(~converged) = x_new(~converged);
            end
            
            % Fallback to bisection method for non-converged points if requested
            if options.bisect_fallback && ~all(converged)
                not_done = ~converged;
                q_remain = q_solve(not_done);
                x_l = x_lower(not_done);
                x_u = x_upper(not_done);
                x_mid = x_current(not_done);
                
                % Bisection method for remaining points
                max_bisect_iter = 100;
                for j = 1:max_bisect_iter
                    cdf_mid = obj.cdf(x_mid);
                    too_low = cdf_mid < q_remain;
                    too_high = cdf_mid > q_remain;
                    
                    x_l(too_low) = x_mid(too_low);
                    x_u(too_high) = x_mid(too_high);
                    
                    % Use weighted geometric mean for better convergence near boundaries
                    weight = 0.5 * ones(size(x_mid));
                    high_q_idx = q_remain > 0.99;
                    if any(high_q_idx)
                        weight(high_q_idx) = 0.7;  % Bias toward upper bound for high quantiles
                    end
                    x_mid = exp((1-weight).*log(x_l) + weight.*log(x_u));
                    
                    if all(abs(x_u - x_l) < options.abstol)
                        break;
                    end
                end
                
                x_current(not_done) = x_mid;
            end
            
            % Store results and check accuracy
            x(mask) = x_current;
 
        end
    end
end
