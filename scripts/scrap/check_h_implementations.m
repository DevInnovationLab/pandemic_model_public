% Define the range of vaccination fractions
vax_fractions = linspace(0, 1, 1000);

% Evaluate the first h function
y1 = zeros(size(vax_fractions));
for i = 1:length(vax_fractions)
    y1(i) = h_piecewise(vax_fractions(i));
end

% Evaluate the second h function
y2 = arrayfun(@h_conditional, vax_fractions);

% Plot the results
figure;
plot(vax_fractions, y1, 'b-', 'LineWidth', 2); hold on;
plot(vax_fractions, y2, 'r--', 'LineWidth', 2);
grid on;
legend({'h (Piecewise)', 'h (Conditional)'}, 'Location', 'Southeast');
xlabel('Vaccination Fraction');
ylabel('h Value');
title('Comparison of Two h Functions');

% Piecewise linear function implementation
function y = h_piecewise(vax_fraction)
    slope_1 = 3.038462;
    slope_2 = 1.137838;
    slope_3 = 0.92;
    intercept_2 = 0.395;
    intercept_3 = 0.816;

    if vax_fraction <= 0.13
        y = slope_1 * vax_fraction;
    elseif vax_fraction <= 0.5
        y = intercept_2 + slope_2 * (vax_fraction - 0.13);
    elseif vax_fraction <= 0.7
        y = intercept_3 + slope_3 * (vax_fraction - 0.5);
    else
        y = 1;
    end
end

% Conditional linear function implementation
function y = h_conditional(vax_fraction)
    slope_1 = 3.038462;
    slope_2 = 1.137838;
    intercept_2 = 0.247081;
    slope_3 = 0.92;
    intercept_3 = 0.356000;

    if vax_fraction <= 0.13
        y = slope_1 * vax_fraction;
    elseif vax_fraction <= 0.5
        y = intercept_2 + slope_2 * vax_fraction;
    elseif vax_fraction <= 0.7
        y = intercept_3 + slope_3 * vax_fraction;
    else
        y = 1;
    end
end
