function [chunk_dirs, chunk_numbers] = list_chunk_dirs(raw_dir)
% Return chunk_* subdirectories under raw_dir sorted by chunk number.
%
% Args:
%   raw_dir: Path containing chunk_1, chunk_2, ... subdirectories
%
% Returns:
%   chunk_dirs: dir-struct array sorted by chunk number
%   chunk_numbers: numeric array of chunk numbers (same order)
    entries = dir(fullfile(raw_dir, 'chunk_*'));
    entries = entries([entries.isdir]);
    chunk_numbers = cellfun(@(n) sscanf(n, 'chunk_%d'), {entries.name});
    [chunk_numbers, order] = sort(chunk_numbers);
    chunk_dirs = entries(order);
end
