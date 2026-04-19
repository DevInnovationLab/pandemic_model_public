function export_figure(fig, path, varargin)
% Export a figure using standard publication settings.
%
% Defaults: ContentType=vector, Resolution=600, BackgroundColor=none.
% Override any option via name-value pairs, e.g.:
%   export_figure(fig, path, 'Resolution', 400)
%
% Args:
%   fig:      Figure handle (or gcf)
%   path:     Output file path (extension determines format)
%   varargin: Additional name-value pairs passed to exportgraphics
    defaults = {'ContentType', 'vector', 'Resolution', 600, 'BackgroundColor', 'none'};
    exportgraphics(fig, path, defaults{:}, varargin{:});
end
