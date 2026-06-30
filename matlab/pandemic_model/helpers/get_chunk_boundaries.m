function [chunks_to_process, chunk_starts, chunk_ends] = get_chunk_boundaries(num_simulations, num_chunks, array_task_id)
% Compute chunk boundaries for parallelised simulation runs.
%
% Args:
%   num_simulations: Total number of simulations
%   num_chunks:      Number of chunks to split into
%   array_task_id:   SLURM array task ID (0 = local, process all chunks)
%
% Returns:
%   chunks_to_process: Vector of chunk indices to run (scalar if SLURM, 1:n if local)
%   chunk_starts:      Start simulation index for each chunk
%   chunk_ends:        End simulation index for each chunk
    chunk_size  = ceil(num_simulations / num_chunks);
    chunk_starts = 1:chunk_size:num_simulations;
    chunk_ends   = [chunk_starts(2:end) - 1, num_simulations];

    is_array_task = ~isnan(array_task_id);
    if is_array_task
        chunks_to_process = array_task_id;
        fprintf('Running as SLURM array task %d/%d\n', array_task_id, num_chunks);
    else
        chunks_to_process = 1:num_chunks;
    end
end
