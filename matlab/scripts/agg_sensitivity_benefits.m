function agg_sensitivity_results(sensitivity_dir)
    % Aggregate the sensitivity results from the sensitivity directory
    % Args:
    %   sensitivity_dir (string): Path to sensitivity directory
    % Returns:
    %   None
    
    % Get the list of sensitivity directories
    param_dirs = dir(fullfile(sensitivity_dir));
    param_dirs = param_dirs([param_dirs.isdir]);
    param_dirs = param_dirs(~ismember({param_dirs.name}, {'.', '..'}));
    
    % Loop through each sensitivity directory
    for i = 1:length(param_dirs)
        param_name = param_dirs(i).name;
        param_dir = fullfile(sensitivity_dir, param_name);
        value_dirs = dir(fullfile(param_dir, 'value_*'));
        value_dirs = value_dirs([value_dirs.isdir]);
        
        % Loop through each value directory
        for j = 1:length(value_dirs)
            value_name = value_dirs(j).name;
            value_dir = fullfile(param_dir, value_name);
            raw_dir = fullfile(value_dir, 'raw');
            
            % Create processed directory for this scenario
            processed_dir = fullfile(value_dir, 'processed');
            create_folders_recursively(processed_dir);
            
            % Get all chunk directories
            chunk_dirs = dir(fullfile(raw_dir, 'chunk_*'));
            chunk_dirs = chunk_dirs([chunk_dirs.isdir]);
            
            if isempty(chunk_dirs)
                warning('No chunk directories found in %s', raw_dir);
                continue;
            end
            
            % Extract chunk numbers and sort
            chunk_numbers = zeros(length(chunk_dirs), 1);
            for k = 1:length(chunk_dirs)
                tokens = regexp(chunk_dirs(k).name, 'chunk_(\d+)', 'tokens');
                chunk_numbers(k) = str2double(tokens{1}{1});
            end
            [chunk_numbers, sort_idx] = sort(chunk_numbers);
            chunk_dirs = chunk_dirs(sort_idx);
            
            % Check that chunk numbers are contiguous
            expected_chunks = 1:length(chunk_dirs);
            if ~isequal(chunk_numbers', expected_chunks)
                error('Chunk numbers are not contiguous in %s. Found: %s, Expected: %s', ...
                      raw_dir, mat2str(chunk_numbers'), mat2str(expected_chunks));
            end
            
            % Load first chunk to get dimensions
            first_chunk_path = fullfile(raw_dir, chunk_dirs(1).name, 'baseline_annual.mat');
            disp(first_chunk_path)
            S_first = load(first_chunk_path, 'annual_results_baseline');
            [n_sims_per_chunk, n_periods] = size(S_first.annual_results_baseline.benefits_vaccine);
            n_chunks = length(chunk_dirs);
            
            % Preallocate array for sum of benefits per simulation
            sum_benefits = zeros(n_sims_per_chunk * n_chunks, 1);
            
            % Load benefits_vaccine from all chunks and calculate sums
            for k = 1:n_chunks
                chunk_path = fullfile(raw_dir, chunk_dirs(k).name, 'baseline_annual.mat');
                S = load(chunk_path, 'annual_results_baseline');
                start_idx = (k-1) * n_sims_per_chunk + 1;
                end_idx = k * n_sims_per_chunk;
                sum_benefits(start_idx:end_idx) = sum(S.annual_results_baseline.benefits_vaccine, 2);
            end
            
            % Calculate mean of sums
            mean_benefits = mean(sum_benefits);
            
            % Save to this scenario's processed directory
            output_path = fullfile(processed_dir, 'benefits_summary.mat');
            save(output_path, 'mean_benefits', 'sum_benefits', 'param_name', 'value_name');
            
            fprintf('Processed %s/%s: mean benefits = %.2f\n', param_name, value_name, mean_benefits);
        end
    end
    
    fprintf('All sensitivity results aggregated and saved to respective processed directories\n');
end