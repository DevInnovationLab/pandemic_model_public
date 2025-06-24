function k = capital_costs(q, params, tailoring_fraction, is_mRNA, is_adv)
    % Calculate capital costs for capacity expansion
    % Inputs:
    %   q: capacity expansion amount
    %   params: struct containing model parameters
    %   tailoring_fraction: fraction of capacity that is tailored
    %   is_mRNA: boolean indicating if mRNA platform
    %   is_adv: boolean indicating if advance capacity
    % Output:
    %   k: capital costs
    % Determine which cost function to use based on capacity and type
    const_marginal_cost = q <= params.beta | is_adv == 1;
    
    % Select platform-specific cost parameter
    k_platform = is_mRNA .* params.k_m + ~is_mRNA .* params.k_o;
    
    % Calculate base cost component for non-zero capacities
    base_cost = k_platform .* (1-tailoring_fraction) .* q;
    
    % Initialize output array
    k = zeros(size(q));
    
    % Only calculate scaling for non-zero, non-constant marginal cost cases
    nonzero_idx = q > 0;
    scaling_idx = nonzero_idx & ~const_marginal_cost;
    if any(scaling_idx)
        scaling = (1./(1+params.epsilon)) .* (params.epsilon .* params.beta ./ q(scaling_idx) + ...
                 (q(scaling_idx)./params.beta).^params.epsilon);
        k(scaling_idx) = base_cost(scaling_idx) .* scaling;
    end
    
    % Handle constant marginal cost cases
    const_idx = nonzero_idx & const_marginal_cost;
    k(const_idx) = base_cost(const_idx);
end