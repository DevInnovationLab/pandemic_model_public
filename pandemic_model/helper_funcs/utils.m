function tf = isNaturalNumber(x)
    % Check if x is a scalar, positive, and an integer
    tf = isscalar(x) && (x > 0) && (x == floor(x));
end