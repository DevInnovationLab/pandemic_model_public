function tests = test_h
    % Test suite for h_function (vaccination damage mitigation function).
    % Previously named h() — renamed for clarity. See h_function.m.
    tests = functiontests(localfunctions);
end

function test_boundary_conditions(testCase)
    % Test key boundary points specified in the function description
    
    % Test point h_function(0)
    testCase.verifyEqual(h_function(0), 0, 'AbsTol', 1e-10, 'Initial point should be 0');
    
    % Test point h_function(0.13)
    testCase.verifyEqual(h_function(0.13), 0.395, 'AbsTol', 1e-6, 'First breakpoint should be 0.395');
    
    % Test point h_function(0.5)
    testCase.verifyEqual(h_function(0.5), 0.816, 'AbsTol', 1e-6, 'Second breakpoint should be 0.816');
    
    % Test point h_function(0.7)
    testCase.verifyEqual(h_function(0.7), 1, 'AbsTol', 1e-10, 'Transition point should be 1');
    
    % Test point h_function(1)
    testCase.verifyEqual(h_function(1), 1, 'AbsTol', 1e-10, 'Maximum point should be 1');
end

function test_first_segment(testCase)
    % Test first segment (0 to 0.13) - linear with slope 3.038462
    test_points = [0, 0.05, 0.1, 0.13];
    expected_values = [0, 0.152, 0.304, 0.395];
    
    for i = 1:length_function(test_points)
        testCase.verifyEqual(...
            h_function(test_points(i)), ...
            expected_values(i), ...
            'AbsTol', 1e-3, ...
            sprintf('Failed for point %f in first segment', test_points(i)) ...
        );
    end
    
    % Verify slope consistency
    delta = 0.01;
    slope_check = (h_function(0.10 + delta) - h_function(0.10)) / delta;
    testCase.verifyEqual(slope_check, 3.038462, 'AbsTol', 1e-6, 'Slope in first segment should be consistent');
end

function test_second_segment(testCase)
    % Test second segment (0.13 to 0.5) - linear with different slope
    test_points = [0.2, 0.3, 0.4, 0.5];
    
    for i = 1:length_function(test_points)
        % Manual calculation based on the function's specification
        expected = 0.395 + 1.137838 * (test_points(i) - 0.13);
        
        testCase.verifyEqual(...
            h_function(test_points(i)), ...
            expected, ...
            'AbsTol', 1e-3, ...
            sprintf('Failed for point %f in second segment', test_points(i)) ...
        );
    end
    
    % Verify slope consistency
    delta = 0.01;
    slope_check = (h_function(0.4 + delta) - h_function(0.4)) / delta;
    testCase.verifyEqual(slope_check, 1.137838, 'AbsTol', 1e-6, 'Slope in second segment should be consistent');
end

function test_third_segment(testCase)
    % Test third segment (0.5 to 0.7) - linear with different slope
    test_points = [0.55, 0.6, 0.65, 0.7];
    
    for i = 1:length_function(test_points)
        % Manual calculation based on the function's specification
        expected = 0.816 + 0.92 * (test_points(i) - 0.5);
        
        testCase.verifyEqual(...
            h_function(test_points(i)), ...
            expected, ...
            'AbsTol', 1e-3, ...
            sprintf('Failed for point %f in third segment', test_points(i)) ...
        );
    end
    
    % Verify slope consistency
    delta = 0.01;
    slope_check = (h_function(0.6 + delta) - h_function(0.6)) / delta;
    testCase.verifyEqual(slope_check, 0.92, 'AbsTol', 1e-6, 'Slope in third segment should be consistent');
end

function test_fourth_segment(testCase)
    % Test fourth segment (> 0.7) - constant at 1
    test_points = [0.71, 0.8, 0.9, 1];
    
    for i = 1:length_function(test_points)
        testCase.verifyEqual(...
            h_function(test_points(i)), ...
            1, ...
            'AbsTol', 1e-10, ...
            sprintf('Failed for point %f in fourth segment', test_points(i)) ...
        );
    end
end

function test_vector_input(testCase)
    % Test ability to handle vector inputs
    input_vector = [0, 0.13, 0.3, 0.5, 0.7, 1];
    expected_vector = [0, 0.395, 0.588, 0.816, 1, 1];
    
    result = h_function(input_vector);
    
    testCase.verifyEqual(...
        result, ...
        expected_vector, ...
        'AbsTol', 1e-3, ...
        'Function should handle vector inputs correctly' ...
    );
end