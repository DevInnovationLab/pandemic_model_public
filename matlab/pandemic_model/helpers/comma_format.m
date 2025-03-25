function formatted_str = comma_format(input)
    % COMMA_FORMAT Format a number or array of numbers with commas as thousands separators
    %
    % Syntax:
    %   formatted_str = comma_format(input)
    %
    % Inputs:
    %   input - A numeric value, array, or string to be formatted
    %
    % Outputs:
    %   formatted_str - A string or cell array of strings with numbers formatted with commas
    %
    % Examples:
    %   formatted_str = comma_format(1234567.89)
    %   % Returns: '1,234,567.89'
    %
    %   formatted_str = comma_format([1234, 5678, 91011])
    %   % Returns: {'1,234', '5,678', '91,011'}
    %
    %   formatted_str = comma_format(["1234", "5678", "91011"])
    %   % Returns: ["1,234", "5,678", "91,011"]

    % Handle different input types
    if isnumeric(input)
        if isscalar(input)
            % Single number
            formatted_str = format_single_number(input);
        else
            % Array of numbers
            formatted_str = strings(size(input));
            for i = 1:numel(input)
                formatted_str(i) = format_single_number(input(i));
            end
            
            % If input was a vector, return as a vector
            if isrow(input)
                formatted_str = formatted_str(:)';
            elseif iscolumn(input)
                formatted_str = formatted_str(:);
            end
        end
    elseif isstring(input)
        % String array
        formatted_str = strings(size(input));
        for i = 1:numel(input)
            % Try to convert to number first, then format
            try
                num_val = str2double(input(i));
                if ~isnan(num_val)
                    formatted_str(i) = string(format_single_number(num_val));
                else
                    % If conversion fails, try to format the string directly
                    formatted_str(i) = string(format_single_string(char(input(i))));
                end
            catch
                % If all else fails, keep original
                formatted_str(i) = input(i);
            end
        end
    elseif ischar(input)
        % Single string
        try
            num_val = str2double(input);
            if ~isnan(num_val)
                formatted_str = format_single_number(num_val);
            else
                formatted_str = format_single_string(input);
            end
        catch
            formatted_str = input;
        end
    elseif iscell(input)
        % Cell array
        formatted_str = strings(size(input));
        for i = 1:numel(input)
            if isnumeric(input{i})
                formatted_str(i) = format_single_number(input{i});
            elseif ischar(input{i})
                try
                    num_val = str2double(input{i});
                    if ~isnan(num_val)
                        formatted_str(i) = format_single_number(num_val);
                    else
                        formatted_str(i) = format_single_string(input{i});
                    end
                catch
                    formatted_str(i) = input{i};
                end
            else
                formatted_str(i) = input{i};
            end
        end
    else
        % Unsupported type
        error('Input type not supported for comma formatting');
    end
end

function formatted_str = format_single_number(number)
    % Format a single number with commas
    
    % Convert number to string
    str = num2str(number);
    
    % Find decimal point position if it exists
    decimal_pos = find(str == '.', 1);
    
    if isempty(decimal_pos)
        % No decimal point, format the whole number
        integer_part = str;
        decimal_part = '';
    else
        % Split into integer and decimal parts
        integer_part = str(1:decimal_pos-1);
        decimal_part = str(decimal_pos:end);
    end
    
    % Add commas to the integer part
    if length(integer_part) > 3
        % Determine the position of the first comma
        remainder = mod(length(integer_part), 3);
        if remainder == 0
            remainder = 3;
        end
        
        % Start with the first segment
        formatted_int = integer_part(1:remainder);
        
        % Add remaining segments with commas
        for i = remainder+1:3:length(integer_part)
            end_pos = min(i+2, length(integer_part));
            formatted_int = [formatted_int, ',', integer_part(i:end_pos)];
        end
    else
        formatted_int = integer_part;
    end
    
    % Combine integer and decimal parts
    if isempty(decimal_part)
        formatted_str = formatted_int;
    else
        formatted_str = [formatted_int, decimal_part];
    end
end

function formatted_str = format_single_string(str)
    % Format a single string with commas
    
    % Find decimal point position if it exists
    decimal_pos = find(str == '.', 1);
    
    if isempty(decimal_pos)
        % No decimal point, format the whole number
        integer_part = str;
        decimal_part = '';
    else
        % Split into integer and decimal parts
        integer_part = str(1:decimal_pos-1);
        decimal_part = str(decimal_pos:end);
    end
    
    % Add commas to the integer part
    if length(integer_part) > 3
        % Determine the position of the first comma
        remainder = mod(length(integer_part), 3);
        if remainder == 0
            remainder = 3;
        end
        
        % Start with the first segment
        formatted_int = integer_part(1:remainder);
        
        % Add remaining segments with commas
        for i = remainder+1:3:length(integer_part)
            end_pos = min(i+2, length(integer_part));
            formatted_int = [formatted_int, ',', integer_part(i:end_pos)];
        end
    else
        formatted_int = integer_part;
    end
    
    % Combine integer and decimal parts
    if isempty(decimal_part)
        formatted_str = formatted_int;
    else
        formatted_str = [formatted_int, decimal_part];
    end
end

