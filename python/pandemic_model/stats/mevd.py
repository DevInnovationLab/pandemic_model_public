import numpy as np
import pandas as pd
from scipy.stats import genpareto, rv_continuous, truncpareto
from scipy.optimize import brentq


class mevd_gen(rv_continuous):
    """
    Metastatistical Extreme Value Distribution (MEVD) built from a base distribution
    representing individual observations, then averaged over windows
    using observation counts as geometric weights.

    For each window i with n_i observations, the maximum's CDF is:
        F_i(x) = [F_base(x)]^(n_i).

    The overall MEVD is:
        F_MEVD(x) = (1/N) * Σ_i [F_base(x)]^(n_i),
    where N is the number of windows.

    You can specify the base distribution in one of two ways:
      1) Pass in a pre-fitted frozen distribution (e.g., truncpareto or genpareto) via
         `base_dist`. This must support .cdf(x) and .pdf(x).
      2) Specify dist_type='genpareto' or dist_type='truncpareto' along with the
         relevant parameters in `dist_params`. The code will internally create
         a frozen SciPy distribution.

    Note that the API is not entirely equivalent to rv_continuous.
        Use the internal methods defined here rater than the standard public interface.

    Parameters
    ----------
    window_counts : array-like
        Sizes of each window (n_i).
    base_dist : rv_frozen, optional
        A pre-fitted distribution with .cdf() and .pdf() methods (e.g. from
        `scipy.stats.truncpareto(...)` or `scipy.stats.genpareto(...)`).
    dist_type : {'genpareto', 'truncpareto', None}, default None
        If no `base_dist` is provided, choose which built-in SciPy distribution
        to use as the base. If None, you must supply `base_dist`.
    dist_params : dict, optional
        The parameters for the chosen dist_type, for example:
         - genpareto: {'shape': xi, 'loc': mu, 'scale': sigma}
         - truncpareto: {'b': b, 'c': c, 'loc': loc, 'scale': scale}
    share_above_min : float between 0 and 1
        Adjust the 
    """
    def __init__(
        self,
        window_counts,
        base_dist=None,
        dist_type=None,
        dist_params=None,
        name='mevd',
    ):
        super().__init__(name=name)
        self.window_counts = np.asarray(window_counts, dtype=int)
        self.non_zero_window_counts = self.window_counts[self.window_counts > 0]
        self.share_zeros = 1 - len(self.non_zero_window_counts) / len(self.window_counts)

        # Store or create the base distribution
        if base_dist is not None:
            # The user provides a pre-fitted frozen distribution
            self._frozen_dist = base_dist
        else:
            # We create a frozen distribution from dist_type and dist_params
            if dist_type is None:
                raise ValueError("Must provide either base_dist or dist_type.")
            if dist_params is None:
                dist_params = {}

            if dist_type == 'genpareto':
                shape = dist_params['shape']  # sometimes called xi
                loc   = dist_params['loc']
                scale = dist_params['scale']
                self._frozen_dist = genpareto(shape, loc=loc, scale=scale)
                self.lower_bound = dist_params['loc']
            elif dist_type == 'truncpareto':
                b = dist_params['b']
                c = dist_params['c']
                loc   = dist_params['loc']
                scale = dist_params['scale']
                self._frozen_dist = truncpareto(b, c, loc=loc, scale=scale)
                self.lower_bound = dist_params['loc'] + dist_params['scale']
                self.upper_bound = dist_params['loc'] + dist_params['scale'] * dist_params['c']
            else:
                raise ValueError("dist_type must be 'genpareto' or 'truncpareto'")

    # ----------------------------------------------------------------
    # The MEVD logic: F_MEVD(x) = average of [F_base(x)]^(n_i).
    # ----------------------------------------------------------------
    def _base_cdf(self, x):
        return self._frozen_dist.cdf(x)

    def _base_pdf(self, x):
        return self._frozen_dist.pdf(x)

    def _cdf(self, x):
        """
        CDF of the MEVD:
            F_MEVD(x) = (1/N) * sum_{i=1}^N [F_gpd(x)]^(n_i).
        """
        x = np.asarray(x, dtype=float)
        F_base = self._base_cdf(x)  # shape: (M,)
        # [F_base(x)]^(n_i) for each n_i, then average
        cdf_matrix = np.power(F_base, self.window_counts[:, None])  # shape: (N, M)
        return np.mean(cdf_matrix, axis=0)

    def _pdf(self, x):
        """
        PDF of the MEVD:
            f_MEVD(x) = (1/N) * sum_{i=1}^N n_i [F_gpd(x)]^(n_i - 1) * f_gpd(x).
        (derivative of [F_g(x)]^(n_i) w.r.t. x)
        """
        x = np.asarray(x, dtype=float)
        F_base = self._base_cdf(x)
        f_base = self._base_pdf(x)    
        pdf_matrix = (
            self.non_zero_window_counts[:, None]
            * np.power(F_base, (self.non_zero_window_counts - 1)[:, None])
            * f_base[None, :]
        )
        return np.mean(pdf_matrix, axis=0)

    # Can likely remove this method as handled by base class.
    def _sf(self, x):
        return 1.0 - self._cdf(x)

    # This is going to get wonky with share_above_min adjustment.

    def _ppf(self, q, min_x=None, max_x=None, max_iter=20, tol=1e-8):
        """
        Vectorized and optimized version of the PPF (percent point function / quantile function).
        
        Args:
            q: Array of quantile values to solve for (between 0 and 1)
            min_x: Minimum x value to search from
            max_x: Maximum x value to search to
            
        Returns:
            Array of x values where F_MEVD(x) = q
        """
        q = np.asarray(q, dtype=float)
        
        min_x = self.lower_bound if min_x is None else min_x
        max_x = self.upper_bound if max_x is None else max_x
        max_x = max_x if max_x is not None else 2e32 # Some absurdly large number

        # Handle edge cases vectorized
        result = np.zeros_like(q)
        result[q <= 0] = min_x
        result[q >= 1] = max_x
        
        # Find indices that need solving
        mask = (q > 0) & (q < 1)
        if not np.any(mask):
            return result
        
        q_solve = q[mask]
        
        # Initial guess using exponential spacing
        x_guess = np.exp(np.log(min_x) + (np.log(max_x) - np.log(min_x)) * q_solve)
        
        # Newton-Raphson method with safeguards
        max_iter = max_iter
        tolerance = tol
        x = x_guess.copy()
        converged = False
        
        for i in range(max_iter):
            cdf = self._cdf(x)
            pdf = self._pdf(x)
            
            # Avoid division by zero
            valid_pdf = (pdf > 1e-10)
            if not np.any(valid_pdf):
                break
                
            # Newton step
            dx = (cdf - q_solve) / np.where(valid_pdf, pdf, 1.0)
            x_new = x - dx
            
            # Apply bounds
            x_new = np.clip(x_new, min_x, max_x)
            
            # Check convergence
            if np.all(np.abs(x_new - x) < tolerance * np.abs(x)):
                x = x_new
                converged = True
                break
                
            # Update for next iteration
            x = x_new
        
        if not converged:
            print(f"Warning: Newton-Raphson method did not converge after {max_iter} iterations")
        
        # Store results
        result[mask] = x
        return result