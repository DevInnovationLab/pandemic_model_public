function z = taleb_transform(x, lower, upper)
    % Map x in [lower, upper) → z in [lower, ∞)
    % From Cirillo and Taleb (2020), Eq. (3)
        z = lower - upper .* log((upper - x) ./ (upper - lower));
    end