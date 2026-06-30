classdef DurationSampler < DurationDist
    properties
        param_table
    end

    properties (Constant, Access = private)
        required_columns = ["mu", "sigma", "loc"]
    end

    methods
        function obj = DurationSampler(param_table)
            % Create a duration sampler that samples from multiple parameter combinations.
            %
            % Parameters mu, sigma, and loc are in years (as fitted). Samples are returned
            % as integer months: round(12 * continuous_years) with a floor at round(12 * loc).
            %
            % Args:
            %   param_table: Table with columns mu, sigma, and loc (one row per draw).
            arguments
                param_table table
            end

            obj.param_table = obj.validate_param_table(param_table);
        end

        function months = get_duration_months(obj, unifrnd_draw)
            % Sample durations using parameter combinations from param_table.
            %
            % Args:
            %   unifrnd_draw: Matrix of uniform random draws with one row per parameter draw.
            %
            % Returns:
            %   duration: Matrix of sampled integer durations in months (same size as unifrnd_draw).
            assert(size(unifrnd_draw, 1) == height(obj.param_table), ...
                'Number of draws must match number of parameter combinations');

            y = logninv(unifrnd_draw, obj.param_table.mu, obj.param_table.sigma);
            duration_years = y + obj.param_table.loc;
            min_months = round(12 * obj.param_table.loc);
            months = round(12 * duration_years);
            months = max(months, min_months);
        end

        function rank = get_rank(obj, months)
            % Cumulative distribution value at each sampled duration (months).
            assert(size(duration, 1) == height(obj.param_table), ...
                'Number of draws must match number of parameter combinations');

            years = months ./ 12;
            y = years - obj.param_table.loc;
            rank = logncdf(y, obj.param_table.mu, obj.param_table.sigma);
        end

        function mass = get_mass_months(obj, months)
            % Probability mass for each integer duration in months (bin width one month).
            assert(size(duration, 1) == height(obj.param_table), ...
                'Number of draws must match number of parameter combinations');

            upper_bound = months + 0.5;
            lower_bound = months - 0.5;
            lower_years = lower_bound ./ 12;
            upper_years = upper_bound ./ 12;
            lower_years(lower_years < obj.param_table.loc) = obj.param_table.loc(lower_years < obj.param_table.loc);

            y_upper = upper_years - obj.param_table.loc;
            y_lower = lower_years - obj.param_table.loc;

            cdf_upper = logncdf(y_upper, obj.param_table.mu, obj.param_table.sigma);
            cdf_lower = logncdf(y_lower, obj.param_table.mu, obj.param_table.sigma);
            mass = cdf_upper - cdf_lower;
        end
    end

    methods (Static, Access = private)
        function param_table = validate_param_table(param_table)
            required = DurationSampler.required_columns;
            columns = string(param_table.Properties.VariableNames);
            missing = setdiff(required, columns);
            assert(isempty(missing), ...
                "Duration parameter CSV is missing columns: %s", strjoin(missing, ", "));
            extra = setdiff(columns, required);
            assert(isempty(extra), ...
                "Duration parameter CSV has unexpected columns: %s", strjoin(extra, ", "));
            param_table = param_table(:, cellstr(required));
        end
    end
end
