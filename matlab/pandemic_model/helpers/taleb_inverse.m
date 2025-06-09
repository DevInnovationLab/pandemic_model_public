function x = taleb_inverse(z, lower, upper)
    % Inverse of the Cirillo–Taleb transform: z → x
    % Maps z in [lower, ∞) back to x in [lower, upper)
        x = upper - (upper - lower) .* exp((lower - z) ./ upper);
    end