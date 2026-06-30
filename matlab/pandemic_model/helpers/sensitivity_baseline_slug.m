function slug = sensitivity_baseline_slug(baseline_key)
    % Return a short, filesystem-safe directory name for a sensitivity baseline_key.
    %
    % Uses MD5 over the UTF-8 baseline key string and keeps the first 8 bytes as hex.
    %
    % Args:
    %   baseline_key  Char vector from compute_baseline_key / canonicalize_value.

    baseline_key = char(baseline_key);
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(uint8(baseline_key));
    h = typecast(md.digest, 'uint8');
    slug = lower(sprintf('%02x', h(1:8)));
end
