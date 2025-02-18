function out = escape_chars(s)
    % Escapes special characters in strings for Matlab plots
    %
    % Args:
    %   s (string): Input string to escape
    %
    % Returns:
    %   string: String with special characters escaped
    %
    % Example:
    %   escaped = escape_chars('Hello_world')
    %   % Returns: 'Hello\_world'
    out = strrep(s, '_', '\_');
    out = strrep(out, '^', '\^');
    out = strrep(out, '{', '\{');
    out = strrep(out, '}', '\}');
    out = strrep(out, '%', '\%');
    out = strrep(out, '$', '\$');
    out = strrep(out, '#', '\#');
    out = strrep(out, '&', '\&');
end