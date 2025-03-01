import numpy as np
from scipy.optimize import minimize


# Truncated pareto distribution ---------------------

def trunc_pareto_neg_log_likelihood(params, data, lower_bound, upper_bound, verbose=False):
    """Negative log-likelihood function for truncated Pareto while keeping scale + loc = lower_bound fixed."""
    b, loc = params  # Extract parameters
    scale = lower_bound - loc  # Enforce the sum constraint

    # Ensure parameters remain valid
    if b <= 0 or scale <= 0 or loc >= min(data):
        return np.inf  # Invalid parameters
    
    y = (data - loc) / scale  # Standardized values
    c = (upper_bound - loc) / scale  # Upper truncation

    # Compute log-likelihood terms
    term1 = len(data) * np.log(b)
    term2 = (b + 1) * np.sum(np.log(y))
    term3 = len(data) * np.log(scale)
    term4 = len(data) * np.log(1 - c ** -b)

    neg_ll = -(term1 - term2 - term3 - term4)  # Negative log-likelihood
    
    if verbose:
        print(f"Current parameters - b: {b:.4f}, loc: {loc:.4f}, scale: {scale:.4f}")
        print(f"Current negative log-likelihood: {neg_ll:.4f}")
        
    return neg_ll


def fit_trunc_pareto(data, lower_bound, upper_bound, b_init=2.0, loc_init=0.01, verbose=False):
    """
    Fit truncated Pareto using MLE while keeping scale + loc = S fixed.
    
    Args:
        data: Array of observations
        lower_bound: Lower bound for truncation
        upper_bound: Upper bound for truncation
        b_init: Initial guess for shape parameter b
        loc_init: Initial guess for location parameter
        verbose: If True, prints optimization progress
    
    Returns:
        Tuple of (b_hat, loc_hat, scale_hat) containing fitted parameters
        
    Raises:
        RuntimeError: If optimization fails, with details about the failure
    """
    # Define constraints
    constraints = [
        {'type': 'ineq', 'fun': lambda x: x[0]},  # b > 0
        {'type': 'ineq', 'fun': lambda x: lower_bound - x[1]},  # scale > 0 
        {'type': 'ineq', 'fun': lambda x: min(data) - x[1]},  # loc < min(data)
    ]
    
    try:
        result = minimize(
            trunc_pareto_neg_log_likelihood, 
            x0=[b_init, loc_init],
            args=(data, lower_bound, upper_bound, verbose),
            constraints=constraints,
            method='SLSQP',  # Specify method
            bounds=[(0, None), (0, min(data))],
            callback=lambda x: print(f"Iteration parameters: {x}") if verbose else None
        )
        
        if result.success:
            b_hat, loc_hat = result.x
            scale_hat = lower_bound - loc_hat
            if verbose:
                print("\nOptimization successful!")
                print(f"Final parameters - b: {b_hat:.4f}, loc: {loc_hat:.4f}, scale: {scale_hat:.4f}")
            return b_hat, loc_hat, scale_hat
        else:
            error_msg = f"MLE optimization failed:\nStatus: {result.status}\nMessage: {result.message}"
            raise RuntimeError(error_msg)
            
    except Exception as e:
        error_msg = f"Optimization error: {str(e)}\nTry different initial values or bounds."
        raise RuntimeError(error_msg)


