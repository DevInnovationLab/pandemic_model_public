import numpy as np
from scipy.special import gammaln

# McFadden's Pseudo R^2
def mcf_pseudo_r2(y, y_pred):
  # Log-likelihood of the fitted model
  ll_model = np.sum(y * np.log(y_pred) - y_pred - gammaln(y + 1))

  # Log-likelihood of the null model (mean response)
  mean_response = np.mean(y)
  ll_null = np.sum(y * np.log(mean_response) - mean_response - gammaln(y + 1))

  return 1 - (ll_model / ll_null)