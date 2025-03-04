classdef MEVD < SeverityDist
    properties
        base_pd
        window_counts
        non_zero_window_counts
        base_dist
        lower_bound
        upper_bound
    end
    
    methods
        function obj = MEVD(window_counts, base_dist_params, trunc_type, upper_bound)
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
            %   base_dist_type - String specifying the base distribution ('sharp' or 'truncpareto')
            %   base_dist_params - Structure with parameters for the base distribution
            %   max_severity - Maximum severity value
            
            arguments
                window_counts (:,1) {mustBeInteger, mustBeNonnegative}
                base_dist_params struct
                trunc_type (1,1) string {mustBeMember(trunc_type, ["sharp", "formal"])}
                upper_bound (1,1) double {mustBePositive} = Inf
            end
            obj.window_counts = window_counts;
            obj.non_zero_window_counts = window_counts(window_counts > 0);

            pd_params = struct_to_named_args(base_dist_params);
            obj.base_pd = makedist(distName, pd_params{:});
            obj.lower_bound = base_dist_params.theta;
            obj.trunc_type = trunc_type;
            obj.upper_bound = upper_bound;
        end
        
        function F = base_cdf(obj, x)
            % Compute the CDF of the base distribution
            if obj.trunc_tpe == "sharp"
                F = obj.base_pd.cdf(x);
                F(x >= obj.upper_bound) = 1;
                
            elseif obj.trunc_tpe == "formal"
                F_u = obj.base_pd.cdf(obj.upper_bound);
                F = obj.base_pd.cdf(x) ./ F_u;
            end
        end
        
        function f = base_pdf(obj, x)
            % Compute the PDF of the base distribution
            if obj.trunc_tpe == "sharp"
                f = obj.base_pd.pdf(x);
 
            elseif obj.trunc_tpe == "formal"
                F_u = obj.base_pd.cdf(x);
                f = obj.base_pd.pdf(x) ./ F_u;
            end
        end
        
        function F = cdf(obj, x)
            % CDF of the MEVD: F_MEVD(x) = (1/N) * sum_{i=1}^N [F_base(x)]^(n_i)
            F_base = obj.base_cdf(x);
            
            % Vectorized computation using matrix operations
            % This is more efficient than a loop in MATLAB
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
            F_base = obj.base_cdf(x);
            f_base = obj.base_pdf(x);
            
            % Use matrix operations for vectorized computation
            % Only consider non-zero window counts for efficiency
            F_base_mat = repmat(F_base(:)', length(obj.non_zero_window_counts), 1);
            f_base_mat = repmat(f_base(:)', length(obj.non_zero_window_counts), 1);
            counts_mat = repmat(obj.non_zero_window_counts, 1, numel(x));
            
            % Element-wise operations
            pdf_terms = counts_mat .* (F_base_mat .^ (counts_mat - 1)) .* f_base_mat;
            f = mean(pdf_terms, 1);
            
            % Reshape to match input dimensions
            f = reshape(f, size(x));
        end
        
        function x = ppf(obj, q, min_x, max_x, max_iter, tol)
            % Percent point function (inverse of CDF) using numerical methods
            arguments
                obj
                q {mustBeNumeric, mustBeReal, mustBeInUnitInterval}
                min_x double = obj.lower_bound
                max_x double = obj.upper_bound
                max_iter double = 20
                tol double = 1e-8
            end
            
            % Handle edge cases
            x = zeros(size(q));
            x(q <= 0) = min_x;
            x(q >= 1) = max_x;
            
            % Find indices that need solving
            mask = (q > 0) & (q < 1);
            if ~any(mask(:))
                return
            end
            
            % Extract values that need solving
            q_solve = q(mask);
            
            % For small number of points, use MATLAB's built-in fzero for better accuracy
            if numel(q_solve) <= 10
                % Use fsolve for vectorized root finding
                % Define the objective function: CDF(x) - q = 0
                objective = @(x) obj.cdf(x) - q_solve;
                
                % Create exponential spacing for initial guesses
                x_guess = exp(log(min_x) + (log(max_x) - log(min_x)) * q_solve);
                
                % Set options for fsolve
                options = optimoptions('fsolve', 'Display', 'off', 'FunctionTolerance', tol);
                
                % Use fsolve to find the roots
                [x_solve, ~, exitflag] = fsolve(objective, x_guess, options);
                
                % Apply bounds and handle any failed solutions
                x_solve = max(min_x, min(max_x, x_solve));
                
                % For any points where fsolve failed, fall back to bisection
                failed = (exitflag <= 0);
                if any(failed)
                   warning('Solver failed for some points.')
                end
                x(mask) = x_solve;
                return;
            end
            
            % For larger sets, use vectorized Newton-Raphson
            % Initial guess using exponential spacing
            x_current = exp(log(min_x) + (log(max_x) - log(min_x)) * q_solve);
            
            % Newton-Raphson method with safeguards
            converged = false;
            
            for i = 1:max_iter
                cdf_vals = obj.cdf(x_current);
                pdf_vals = obj.pdf(x_current);
                
                % Avoid division by zero
                valid_pdf = (pdf_vals > 1e-10);
                if ~any(valid_pdf)
                    break;
                end
                
                % Newton step with safeguards
                dx = zeros(size(x_current));
                dx(valid_pdf) = (cdf_vals(valid_pdf) - q_solve(valid_pdf)) ./ pdf_vals(valid_pdf);
                
                % Limit step size to prevent overshooting
                max_step = 0.5 * abs(x_current);
                dx = sign(dx) .* min(abs(dx), max_step);
                
                x_new = x_current - dx;
                
                % Apply bounds
                x_new = max(min_x, min(max_x, x_new));
                
                % Check convergence
                if all(abs(x_new - x_current) < tol * abs(x_current))
                    x_current = x_new;
                    converged = true;
                    break;
                end
                
                % Update for next iteration
                x_current = x_new;
            end
            
            if ~converged
                warning('Newton-Raphson method did not converge after %d iterations', max_iter);
            end
            
            % Store results
            x(mask) = x_current;
        end
    end
end
