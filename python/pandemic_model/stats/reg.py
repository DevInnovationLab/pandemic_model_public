from typing import Tuple

import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy.stats import norm
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