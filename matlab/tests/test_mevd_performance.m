% Test performance of MEVD class, particularly the ppf function
classdef test_mevd_performance < matlab.unittest.TestCase
    
    properties
        mevd
        n_samples
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Create a test MEVD instance with realistic parameters
            dist_name = 'GeneralizedPareto';
            base_params = struct(...
                'k', 3.048, ...
                'sigma', 1.366, ...
                'theta', 0.01);
            
            % Create window counts similar to real data
            window_counts = zeros(50,1);
            window_counts(19) = 1; % Based on provided context files
            window_counts(25) = 1;
            window_counts(36) = 1;
            
            testCase.mevd = MEVD(window_counts, dist_name, base_params, "sharp", 170.82);
            testCase.n_samples = 10000;
        end
    end
    
    methods(Test)
        function test_unit_window_counts(testCase)
            % Test that when all window counts are 1, the MEVD CDF matches the base CDF
            
            % Create new MEVD with all window counts = 1
            dist_name = 'GeneralizedPareto';
            base_params = struct(...
                'k', 3.048, ...
                'sigma', 1.366, ...
                'theta', 0.01);
            
            window_counts = ones(50,1);
            unit_mevd = MEVD(window_counts, dist_name, base_params, "sharp", 170.82);
            
            % Test points across the domain
            x = linspace(unit_mevd.lower_bound, unit_mevd.upper_bound, 1000)';
            
            % Get CDFs
            mevd_cdf = unit_mevd.cdf(x);
            base_cdf = unit_mevd.base_cdf(x);
            
            % Verify they are equal
            testCase.verifyEqual(mevd_cdf, base_cdf, 'AbsTol', 1e-10, ...
                'When all window counts are 1, MEVD CDF should equal base CDF');
        end

        function test_ppf_performance(testCase)
            % Test performance of ppf function with different sample sizes
            sample_sizes = [100, 1000, 10000, 100000, 1000000];
            
            for n = sample_sizes
                q = linspace(0, 1, n)';
                
                % Time the ppf computation
                tic;
                x = testCase.mevd.ppf(q, 'max_iter', 200);
                elapsed = toc;
                
                % Basic validation
                testCase.verifySize(x, [n, 1]);
                testCase.verifyEqual(x(1), testCase.mevd.lower_bound);
                testCase.verifyEqual(x(end), testCase.mevd.upper_bound);
                testCase.verifyGreaterThanOrEqual(x, testCase.mevd.lower_bound);
                testCase.verifyLessThanOrEqual(x, testCase.mevd.upper_bound);
                
                fprintf('PPF computation for %d samples took %.3f seconds\n', ...
                    n, elapsed);
                
                % Test round-trip accuracy
                tic;
                q_back = testCase.mevd.cdf(x);
                elapsed_cdf = toc;
                
                fprintf('CDF computation for %d samples took %.3f seconds\n', ...
                    n, elapsed_cdf);
                
                % Verify round-trip accuracy
                const_q = sum(testCase.mevd.window_counts == 0) / length(testCase.mevd.window_counts);
                q(q <= const_q) = const_q;
                testCase.verifyEqual(q_back, q, 'AbsTol', 1e-3);
            end
        end
        
        function test_pdf_performance(testCase)
            % Test performance of pdf function with different sample sizes
            sample_sizes = [100, 1000, 10000, 100000, 1000000];
            
            for n = sample_sizes
                x = linspace(testCase.mevd.lower_bound, ...
                            testCase.mevd.upper_bound, ...
                            n)';
                
                % Time the pdf computation
                tic;
                f = testCase.mevd.pdf(x);
                elapsed = toc;
                
                % Basic validation
                testCase.verifySize(f, [n, 1]);
                testCase.verifyGreaterThanOrEqual(f, 0);
                
                fprintf('PDF computation for %d samples took %.3f seconds\n', ...
                    n, elapsed);
            end
        end
    end
end
