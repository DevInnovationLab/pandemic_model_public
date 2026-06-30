% Script to compare efficiency of different bootstrap confidence interval methods
% Tests 'norm', 'per', and 'cper' methods (BCa excluded due to computational inefficiency)

% Sample sizes to test
sample_sizes = [100, 1000, 10000, 100000, 1000000, 3500000];
num_bootstrap = 1000;
alpha = 0.05;

% Bootstrap methods to compare
% Note: 'bca' method excluded - it requires jackknife estimation which is O(n^2)
% and becomes prohibitively slow for large samples (>10000)
methods = {'norm', 'per', 'cper'};
method_names = {'Normal', 'Percentile', 'Corrected Percentile'};

% Store timing and memory results
n_methods = length(methods);
results = table('Size', [length(sample_sizes), 2*n_methods + 1], ...
    'VariableTypes', [{'double'}, repmat({'double'}, 1, 2*n_methods)], ...
    'VariableNames', [{'SampleSize'}, ...
        strcat(methods, 'Time'), strcat(methods, 'Memory')]);

fprintf('Bootstrap Efficiency Comparison\n');
fprintf('================================\n');
fprintf('Methods: %s\n', strjoin(method_names, ', '));
fprintf('Note: BCa method excluded (O(n^2) complexity makes it impractical for large n)\n\n');

for i = 1:length(sample_sizes)
    n = sample_sizes(i);
    fprintf('Testing sample size: %d\n', n);
    
    % Generate sample data (using exponential distribution as example)
    rng(42); % For reproducibility
    data = exprnd(1, n, 1);
    
    % Test each bootstrap method
    for j = 1:n_methods
        method = methods{j};
        
        mem_before = memory;
        tic;
        ci = bootci(num_bootstrap, {@mean, data}, 'type', method, 'alpha', alpha);
        time_elapsed = toc;
        mem_after = memory;
        mem_used = mem_after.MemUsedMATLAB - mem_before.MemUsedMATLAB;
        
        % Store results
        results(i, 1 + j) = {time_elapsed};
        results(i, 1 + n_methods + j) = {mem_used};
        
        fprintf('  %s: %.4f sec, %.2f MB\n', method_names{j}, time_elapsed, mem_used/1e6);
        
        % Clear and pause
        clear ci;
        pause(0.05);
    end
    fprintf('\n');
end

% Display summary
fprintf('Summary of Results\n');
fprintf('==================\n');
disp(results);

% Create compact visualization
figure('Position', [100, 100, 1200, 500]);

% Time comparison
subplot(1, 2, 1);
loglog(results.SampleSize, results.normTime, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
hold on;
loglog(results.SampleSize, results.perTime, 's-', 'LineWidth', 2, 'MarkerSize', 8);
loglog(results.SampleSize, results.cperTime, '^-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Sample Size');
ylabel('Time (seconds)');
title('Computation Time vs Sample Size');
legend(method_names, 'Location', 'northwest');
grid on;

% Memory comparison
subplot(1, 2, 2);
loglog(results.SampleSize, results.normMemory/1e6, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
hold on;
loglog(results.SampleSize, results.perMemory/1e6, 's-', 'LineWidth', 2, 'MarkerSize', 8);
loglog(results.SampleSize, results.cperMemory/1e6, '^-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Sample Size');
ylabel('Memory (MB)');
title('Memory Usage vs Sample Size');
legend(method_names, 'Location', 'northwest');
grid on;

sgtitle('Bootstrap Method Efficiency Comparison');
