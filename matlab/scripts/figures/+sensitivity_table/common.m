classdef common
    % Shared helpers for status-quo and advance-investment sensitivity tables.
    %
    % Call as sensitivity_table.common.<method>(...).

    methods (Static)
        function tf = is_numeric_sensitivity_sweep(entry)
            % True when the YAML entry is a one-parameter two-value sweep.

            tf = iscell(entry) || isnumeric(entry);
        end

        function tf = is_alternative_spec_sensitivity(entry)
            % True when the YAML entry is a struct override (single scenario).

            tf = isstruct(entry) && ~isempty(fieldnames(entry));
        end

        function tf = is_arrival_dist_sensitivity(param_name)
            % True when the sensitivity key denotes an arrival-distribution override.

            tf = strcmp(param_name, 'arrival_dist_config') || startsWith(param_name, 'severity_trunc_');
        end

        function [low_value, high_value, low_metric, high_metric] = order_sensitivity_pair( ...
                value_1, metric_1, value_2, metric_2, param_name)
            % Order two sensitivity draws as low/high for table display.

            if sensitivity_table.common.is_arrival_dist_sensitivity(param_name)
                u1 = sensitivity_table.common.parse_arrival_trunc_u(value_1);
                u2 = sensitivity_table.common.parse_arrival_trunc_u(value_2);
                if ~isnan(u1) && ~isnan(u2)
                    if u1 <= u2
                        low_value = value_1;
                        high_value = value_2;
                        low_metric = metric_1;
                        high_metric = metric_2;
                    else
                        low_value = value_2;
                        high_value = value_1;
                        low_metric = metric_2;
                        high_metric = metric_1;
                    end
                    return;
                end
            end

            if isnumeric(value_1) && isnumeric(value_2) && isscalar(value_1) && isscalar(value_2)
                if value_1 <= value_2
                    low_value = value_1;
                    high_value = value_2;
                    low_metric = metric_1;
                    high_metric = metric_2;
                else
                    low_value = value_2;
                    high_value = value_1;
                    low_metric = metric_2;
                    high_metric = metric_1;
                end
                return;
            end

            low_value = value_1;
            high_value = value_2;
            low_metric = metric_1;
            high_metric = metric_2;
        end

        function u = parse_arrival_trunc_u(path_spec)
            % Parse severity truncation u from an arrival distribution path.

            p = char(path_spec);
            tok = regexp(p, '_u(\d+)_', 'tokens', 'once');
            if isempty(tok)
                u = NaN;
                return;
            end
            u = str2double(tok{1});
        end

        function s = format_arrival_severity_trunc(path_spec)
            % Format arrival-distribution path as a severity truncation label.

            u = sensitivity_table.common.parse_arrival_trunc_u(path_spec);
            if isnan(u)
                s = 'Baseline';
                return;
            end
            s = sprintf('$u = %d$', u);
        end

        function s = format_epidemic_sample_label(sample_id)
            % Format epidemic-sample sensitivity labels.

            switch char(sample_id)
                case 'baseline_sample'
                    s = 'Baseline filtering';
                case 'include_unid_yearthreshonly'
                    s = 'Include unidentified (year threshold only)';
                otherwise
                    s = strrep(char(sample_id), '_', ' ');
            end
        end

        function label = format_severity_trunc_param_label(param_name)
            % Display label for arrival_dist_config or legacy severity_trunc_* keys.

            if strcmp(param_name, 'arrival_dist_config') || startsWith(param_name, 'severity_trunc_')
                label = 'Severity truncation ceiling';
            else
                label = param_name;
            end
        end
    end
end
