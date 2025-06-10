classdef ParametrizedSeveritySampler < SeverityDist
    properties
        min_severity
        param_table
        lower_bound % Added this property as a hacky fix to make compatible with legacy code.
    end

    methods
        function obj = ParametrizedSeveritySampler(param_table, min_severity)
            % Create a severity sampler that samples from multiple parameter combinations
            %
            % Args:
            %   dist_name: Name of the distribution to sample from
            %   param_table: Table containing parameter combinations, one row per draw
            %   max_severity: Maximum allowed severity
            arguments
                param_table
                min_severity (1,1) double {mustBePositive}
            end

            obj.min_severity = min_severity;
            obj.lower_bound = min_severity;
            obj.param_table = param_table;

            assert(all(param_table.max_value == param_table.max_value(1)));
            obj.max_severity = obj.param_table.max_value(1);

        end

        % ---------------------------------------------------------------------
        function severity = get_severity(obj, unifrnd_draw)
            % Draw severities from a GPD tail that is
            %  – left-truncated  at  min_severity  (threshold)
            %  – right-truncated at  max_severity
            %
            % The mass (1-p) sits at the threshold, the remaining p is spread
            % over (min_severity , max_severity].
            assert(size(unifrnd_draw,1) == height(obj.param_table), ...
                'Number of draws must match number of parameter combinations');

            severity = obj.min_severity * ones(size(unifrnd_draw)); % default
            p_tail = obj.param_table.p;
            xi = obj.param_table.xi;
            sigma = obj.param_table.sigma;

            % --- which uniforms fall into the tail? --------------------------------
            cum_prob_at_th = 1 - p_tail;                         % P(Y = min_severity)
            [row, col] = find(unifrnd_draw > cum_prob_at_th);
            lin = sub2ind(size(unifrnd_draw), row, col);

            % --- rescale uniforms to (0,1) conditional on being in the tail --------
            u = (unifrnd_draw(lin) - cum_prob_at_th(row)) ./ p_tail(row);   % U~Unif(0,1)

            % inverse CDF gives a draw in (min_severity , max_severity]
            severity(lin) = taleb_inverse( ...
                gpinv(u, xi(row), sigma(row), obj.min_severity), ...
                obj.min_severity, ...
                obj.max_severity ...
            );

            assert(all(severity <= obj.max_severity, 'all'));
        end

        % ---------------------------------------------------------------------
        function rank = get_severity_rank(obj, severity)
            % Truncated tail CDF mapped back to the mixed distribution:
            %   F_trunc(y) = (F(y) - F(threshold)) / (F(max) - F(threshold))
            %
            % Overall rank = (1-p)  on the atom  +  p · F_trunc(y)
            
            assert(~(severity > obj.max_severity), "Severity out of range");

            rank = zeros(size(severity));

            p_tail = obj.param_table.p;
            xi = obj.param_table.xi;
            sigma = obj.param_table.sigma;
            cum_prob_at_th = 1 - p_tail;

            % Case 1: at or below the threshold (atom)
            idx_th = severity <= obj.min_severity;
            rank(idx_th) = cum_prob_at_th;

            % Case 2: between threshold and max_severity
            idx_mid = severity > obj.min_severity & severity < obj.max_severity;
            [row_mid, col_mid] = find(idx_mid);

            if any(idx_mid(:))
                unconstrained_sev = taleb_transform(severity(idx_mid), obj.min_severity, obj.max_severity);
                F_y = gpcdf(unconstrained_sev, xi(row_mid), sigma(row_mid), obj.min_severity);
                rank(idx_mid) = cum_prob_at_th(row_mid) ...
                                + p_tail(row_mid) .* F_y;
            end

            % Case 3: at or above the upper truncation point
            assert(all(isbetween(rank, 0, 1), 'all'));
        end

        function severity = ppf(obj, unifrnd_draw)
            severity = obj.get_severity(unifrnd_draw);
        end

        function rank = cdf(obj, severity)
            rank = obj.get_severity_rank(severity);
        end
    end
end