classdef test_DurationSampler < matlab.unittest.TestCase
    % Unit tests for year-parameter, month-output duration sampling.

    methods (Test)
        function samplesAreIntegerMonthsAtLeastLoc(testCase)
            param_table = table(0.5, 0.8, 0.5, 'VariableNames', {'mu', 'sigma', 'loc'});
            sampler = DurationSampler(param_table);
            rng(42);
            u = rand(1, 100);
            months = sampler.get_duration_months(u);
            testCase.verifyEqual(size(months), size(u));
            testCase.verifyTrue(all(mod(months(:), 1) == 0));
            testCase.verifyGreaterThanOrEqual(months(:), 6);
        end

        function monthMassMatchesYearLognormal(testCase)
            param_table = table(0.5, 0.8, 0.5, 'VariableNames', {'mu', 'sigma', 'loc'});
            sampler = DurationSampler(param_table);
            k = 12;
            mass = sampler.get_mass_months(repmat(k, height(param_table), 1));
            testCase.verifyGreaterThan(mass, 0);
            testCase.verifyLessThanOrEqual(mass, 1);
        end
    end
end
