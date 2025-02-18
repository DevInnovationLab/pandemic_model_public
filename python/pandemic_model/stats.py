from typing import Tuple

import numpy as np
import pandas as pd
from scipy.optimize import minimize
from scipy.special import gammaln
from scipy.stats import norm
import statsmodels.api as sm
from statsmodels.base.model import GenericLikelihoodModel


class IntervalRegression(GenericLikelihoodModel):
  """Interval regression model used statsmodels-like API."""
  def __init__(self, endog, exog, add_constant=True, **kwargs):
    """
    Parameters:
      endog (pd.DataFrame or np.ndarray): A DataFrame or 2D array with columns ['lower_bound', 'upper_bound'].
      exog (pd.DataFrame or np.ndarray): Design matrix with predictors.
      add_constant (bool): Whether to add a constant term to the design matrix. Defaults to True.
      kwargs: Additional keyword arguments passed to GenericLikelihoodModel.
    """
    if isinstance(endog, pd.DataFrame):
      assert {'lower_bound', 'upper_bound'}.issubset(endog.columns), \
          "endog must contain 'lower_bound' and 'upper_bound' columns."
      self.lower_bound = endog['lower_bound'].values
      self.upper_bound = endog['upper_bound'].values
    else:
      self.lower_bound, self.upper_bound = endog[:, 0], endog[:, 1]

    # Add constant term if requested
    if add_constant:
        exog = sm.add_constant(exog)

    super(IntervalRegression, self).__init__(endog=endog, exog=exog, **kwargs)


  def nloglikeobs(self, params):
    """Compute the negative log-likelihood for each observation.
    
    Parameters:
      params (np.ndarray): Array of parameters [beta coefficients, sigma].
    
    Returns:
      np.ndarray: Negative log-likelihood for each observation.
    """
    beta = params[:-1]  # Coefficients
    sigma = params[-1]  # Standard deviation of the error term
    if sigma <= 0:
      return np.inf * np.ones(len(self.endog))  # Penalize invalid sigma
    
    # Linear predictor
    XB = np.dot(self.exog, beta)

    # Compute probabilities for interval bounds
    lower_cdf = norm.cdf((self.lower_bound - XB) / sigma)
    upper_cdf = norm.cdf((self.upper_bound - XB) / sigma)

    # Avoid log(0) by adding a small epsilon
    likelihoods = upper_cdf - lower_cdf + 1e-10
    return -np.log(likelihoods)


  def fit(self, start_params=None, maxiter=1000, maxfun=500, **kwargs):
    """
    Fit the model using maximum likelihood estimation.
    
    Parameters:
      start_params (np.ndarray, optional): Initial parameter estimates.
      maxiter (int): Maximum number of iterations for optimization.
      maxfun (int): Maximum number of function evaluations.
      kwargs: Additional arguments passed to the optimizer.
    
    Returns:
      statsmodels.base.model.GenericLikelihoodModelResults: Fitted model results.
    """
    # Default start_params: Zero for coefficients, 1 for sigma
    if start_params is None:
      start_params = np.ones(self.exog.shape[1] + 1)
      start_params[-1] = 1  # Initial guess for sigma
    
    return super().fit(start_params=start_params, maxiter=maxiter, maxfun=maxfun, **kwargs)


  def summary(self) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    Generate a summary of the fitted model.
    
    Returns:
      pd.DataFrame: Summary statistics including coefficient estimates, 
                   standard errors, z-scores, and p-values.
    """
    if not hasattr(self, 'result'):
      raise ValueError("Model must be fitted before calling summary()")
    
    # Extract results
    params = self.result.params
    bse = self.result.bse
    
    # Calculate z-scores and p-values
    zvalues = params / bse
    pvalues = 2 * (1 - norm.cdf(np.abs(zvalues)))
    
    # Create summary DataFrame
    summary_df = pd.DataFrame({
      'Coefficient': params,
      'Std. Error': bse,
      'z-value': zvalues,
      'P>|z|': pvalues
    })
    
    # Add variable names if available
    if hasattr(self.exog, 'columns'):
      summary_df.index = list(self.exog.columns) + ['sigma']
    else:
      summary_df.index = [f'x{i}' for i in range(len(params)-1)] + ['sigma']
      
    # Add model fit statistics
    fit_stats = pd.Series({
      'Log-Likelihood': self.result.llf,
      'AIC': self.result.aic,
      'BIC': self.result.bic,
      'Num. Observations': self.exog.shape[0]
    })
    
    return summary_df, fit_stats

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


# McFadden's Pseudo R^2
def mcf_pseudo_r2(y, y_pred):
  # Log-likelihood of the fitted model
  ll_model = np.sum(y * np.log(y_pred) - y_pred - gammaln(y + 1))

  # Log-likelihood of the null model (mean response)
  mean_response = np.mean(y)
  ll_null = np.sum(y * np.log(mean_response) - mean_response - gammaln(y + 1))

  return 1 - (ll_model / ll_null)