import numpy as np
from scipy.optimize import minimize


# Truncated generalized pareto distribution ---------------------
class TruncatedGPD:
    """Truncated Generalized Pareto Distribution
    
    Parameters:
        xi (float): Shape parameter.
        upper (float): Upper truncation point (must be > loc).
        loc (float): Lower bound (μ).
        scale (float): Scale parameter (σ > 0).
    
    The support is [loc, upper]. For xi != 0, the pdf is:
    
    f(x) = (1/sigma)(1+xi(x-mu)/sigma)^(-1/xi-1) / [1-(1+xi(u-mu)/sigma)^(-1/xi)]
    
    For xi -> 0 the distribution converges to the truncated exponential.
    """
    
    def __init__(self, xi=0.1, upper=None, loc=0.0, scale=1.0):
        """Initialize the truncated generalized Pareto distribution.
        
        Args:
            xi (float): Shape parameter.
            upper (float): Upper truncation point. Must be greater than loc.
            loc (float): Location parameter (lower bound).
            scale (float): Scale parameter. Must be positive.
        """
        self.xi = xi
        self.upper = upper
        self.loc = loc
        self.scale = scale
        
        # Validate parameters
        if scale <= 0:
            raise ValueError("Scale parameter must be positive")
        if upper is not None and upper <= loc:
            raise ValueError("Upper bound must be greater than location parameter")
    
    def pdf(self, x):
        """Probability density function.
        
        Args:
            x (array_like): Points at which to evaluate the PDF.
            
        Returns:
            array_like: PDF values at x.
        """
        x = np.asarray(x)
        mu = self.loc
        sigma = self.scale
        xi = self.xi
        upper = self.upper
        
        # Return 0 for values outside the support
        result = np.zeros_like(x, dtype=float)
        valid = (x >= mu) & (x <= upper)
        
        if np.abs(xi) > 1e-6:
            norm = 1 - (1 + xi*(upper - mu)/sigma)**(-1/xi)
            valid_x = x[valid]
            t = 1 + xi*(valid_x - mu)/sigma
            # Check if any t values are non-positive
            if np.any(t <= 0):
                raise ValueError("Invalid parameter combination leads to non-positive values in PDF calculation")
            result[valid] = (1/sigma) * t**(-1/xi - 1) / norm
        else:
            # limit case: xi ~ 0 => exponential distribution
            norm = 1 - np.exp(-(upper-mu)/sigma)
            result[valid] = (1/sigma) * np.exp(-(x[valid]-mu)/sigma) / norm
            
        return result
    
    def cdf(self, x):
        """Cumulative distribution function.
        
        Args:
            x (array_like): Points at which to evaluate the CDF.
            
        Returns:
            array_like: CDF values at x.
        """
        x = np.asarray(x)
        mu = self.loc
        sigma = self.scale
        xi = self.xi
        upper = self.upper
        
        # Handle values outside the support
        result = np.zeros_like(x, dtype=float)
        result[x > upper] = 1.0
        
        valid = (x >= mu) & (x <= upper)
        
        if np.abs(xi) > 1e-6:
            norm = 1 - (1 + xi*(upper-mu)/sigma)**(-1/xi)
            result[valid] = (1 - (1 + xi*(x[valid]-mu)/sigma)**(-1/xi)) / norm
        else:
            norm = 1 - np.exp(-(upper-mu)/sigma)
            result[valid] = (1 - np.exp(-(x[valid]-mu)/sigma)) / norm
            
        return result
    
    def ppf(self, p):
        """Percent point function (inverse of CDF).
        
        Args:
            p (array_like): Probabilities at which to evaluate the PPF.
            
        Returns:
            array_like: PPF values at p.
        """
        p = np.asarray(p)
        mu = self.loc
        sigma = self.scale
        xi = self.xi
        upper = self.upper
        
        # Validate probabilities
        if np.any((p < 0) | (p > 1)):
            raise ValueError("Probabilities must be between 0 and 1")
        
        result = np.zeros_like(p, dtype=float)
        
        if np.abs(xi) > 1e-6:
            norm = 1 - (1 + xi*(upper-mu)/sigma)**(-1/xi)
            # Solve for x:
            # 1 - (1 + xi*(x-mu)/sigma)^(-1/xi) = p * norm
            # => (1 + xi*(x-mu)/sigma)^(-1/xi) = 1 - p*norm
            # => x = mu + sigma/xi * [(1 - p*norm)^(-xi) - 1]
            result = mu + sigma/xi * ((1 - p*norm)**(-xi) - 1)
        else:
            norm = 1 - np.exp(-(upper-mu)/sigma)
            # ppf for the exponential case:
            # p = (1 - exp(-(x-mu)/sigma)) / norm
            # => x = mu - sigma*log(1 - p*norm)
            result = mu - sigma * np.log(1 - p*norm)
            
        # Ensure results don't exceed upper bound due to numerical issues
        result = np.minimum(result, upper)
        
        return result
    
    def sf(self, x):
        """Survival function (1 - CDF).
        
        Args:
            x (array_like): Points at which to evaluate the survival function.
            
        Returns:
            array_like: Survival function values at x.
        """
        return 1 - self.cdf(x)
    
    @classmethod
    def fit(self, data, initial_params=None, bounds=None, fixed=None, opt_kwargs=None):
        """
        Fit the truncated GPD to data using maximum likelihood estimation.
        
        Parameters:
            data (array_like): Observations assumed to lie in [loc, upper].
            initial_params (dict, optional): Dictionary of initial guesses for parameters.
                Keys can be 'xi', 'upper', 'loc', 'scale'.
            bounds (dict, optional): Dictionary mapping parameter names to (min, max) bounds.
            fixed (dict, optional): Dictionary of fixed parameter values.
                Keys can be 'xi', 'upper', 'loc', 'scale'.
        
        Returns:
            TruncatedGPD: A new instance with the fitted parameters.
        """
        # The full parameter list in order
        par_names = ['xi', 'upper', 'loc', 'scale']
        
        # Check for fixed parameters
        if fixed is None:
            fixed = {}
        
        if opt_kwargs is None:
            opt_kwargs = {}
        
        free_names = [par for par in par_names if par not in fixed]
        
        # Set up default initial guesses for free parameters if not provided
        init = {} if initial_params is None else dict(initial_params)
        if 'xi' in free_names and 'xi' not in init:
            init['xi'] = 0.1
        if 'upper' in free_names and 'upper' not in init:
            # Guess a value slightly above the maximum of the data
            init['upper'] = np.max(data) * 1.1
        if 'loc' in free_names and 'loc' not in init:
            init['loc'] = np.min(data) * 0.9
        if 'scale' in free_names and 'scale' not in init:
            init['scale'] = np.std(data) if np.std(data) > 0 else (np.max(data)-np.min(data))/2
        
        # Order the free parameter initial guesses
        x0 = np.array([init[par] for par in free_names])
        
        # Set up default bounds for free parameters
        default_bounds = {}
        
        if 'xi' in free_names:
            xi_bounds = (-12000, 5000)
            default_bounds['xi'] = xi_bounds
            
        if 'upper' in free_names:
            default_bounds['upper'] = (np.max(data) * 1.01, np.max(data) * 10)
            
        if 'loc' in free_names:
            default_bounds['loc'] = (np.min(data) * 0.5, np.min(data) * 0.99)
            
        if 'scale' in free_names:
            default_bounds['scale'] = (1e-6, np.std(data) * 10)
        
        # Update with any user-provided bounds
        if bounds == 'default':
            bnds = list(default_bounds.values())
        elif bounds is not None:
            default_bounds.update(bounds)
            bnds = [default_bounds[par] for par in free_names]
        else:
            bnds = None
        
        # Helper to combine free and fixed parameters into a complete dictionary
        def full_params(free):
            params = {}
            j = 0
            for par in par_names:
                if par in fixed:
                    params[par] = fixed[par]
                else:
                    params[par] = free[j]
                    j += 1
            return params
        
        # Negative log-likelihood function
        def nll(free):
            params = full_params(free)
            xi = params['xi']
            upper = params['upper']
            loc = params['loc']
            sigma = params['scale']
            
            # Validate parameters
            if sigma <= 0 or loc >= upper:
                return np.inf
            if np.any(data < loc) or np.any(data > upper):
                return np.inf
                
            # Compute the log likelihood
            if np.abs(xi) > 1e-6:
                t = 1 + xi*(data - loc)/sigma
                if np.any(t <= 0):
                    return np.inf
                norm = 1 - (1 + xi*(upper - loc)/sigma)**(-1/xi)
                if norm <= 0:
                    return np.inf
                log_pdf = -np.log(sigma) - (1/xi + 1)*np.log(t) - np.log(norm)
            else:
                norm = 1 - np.exp(-(upper - loc)/sigma)
                if norm <= 0:
                    return np.inf
                log_pdf = -np.log(sigma) - (data - loc)/sigma - np.log(norm)
                
            return -np.sum(log_pdf)
        
        # Optimize the negative log-likelihood over free parameters
        nelder_mead_opts = {
            'maxiter': 10000,
            'maxfev': 50000,
            'xatol': 1e-4,
            'fatol': 1e-4,
            'adaptive': True
        }

        res = minimize(nll, x0, bounds=bnds, method='Nelder-Mead', options=nelder_mead_opts)
        if not res.success:
            error_msg = f"Optimization failed: {res.message}\n"
            error_msg += f"Status: {res.status}\n"
            error_msg += f"Number of iterations: {res.nit}\n"
            error_msg += f"Final function value: {res.fun}\n"
            error_msg += f"Final parameters: {full_params(res.x)}"
            raise RuntimeError(error_msg)
        
        fitted = full_params(res.x)
        
        # Return a new instance with the fitted parameters
        return TruncatedGPD(
            xi=fitted['xi'],
            upper=fitted['upper'],
            loc=fitted['loc'],
            scale=fitted['scale']
        )
