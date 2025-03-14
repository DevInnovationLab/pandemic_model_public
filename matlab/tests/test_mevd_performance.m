% Test performance of MEVD class, particularly the ppf function
classdef test_mevd_performance < matlab.unittest.TestCase
    
    properties
        mevd
        n_samples
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Create a test MEVD instance with realistic parameters
            dist_config_path = '../../output/severity_distributions/allrisk_base.yaml'; % For now just test with one we have at hand.
            [~, testCase.mevd] = load_arrival_dist(dist_config_path);
            testCase.n_samples = 10000;
        end
    end
    
    methods(Test)
        function test_unit_window_counts(testCase)
            % Test that when all window counts are 1, the MEVD CDF matches the base CDF
            window_counts = ones(50,1);
            mevd_copy = testCase.mevd;
            mevd_copy.window_counts = window_counts;

            % Test points across the domain
            x = linspace(mevd_copy.lower_bound, mevd_copy.upper_bound, 1000)';
            
            % Get CDFs
            mevd_cdf = mevd_copy.cdf(x);
            base_cdf = mevd_copy.base_cdf(x);
            
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
                reltol = 1e-6;
                x = testCase.mevd.ppf(q, 'max_iter', 1000, 'reltol', reltol, 'abstol', 1e-32);
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
                testCase.verifyEqual(q_back, q, 'RelTol', reltol);
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
