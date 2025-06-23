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

# Transforms to right unbounded domain from Cirillo and Taleb (2020)
def taleb_transform(x, lower, upper):
		return lower - upper * np.log((upper - x) / (upper - lower))

def taleb_inverse(x, lower, upper):
		return upper - (upper - lower) * np.exp((lower - x) / upper)

# Transforms to address constraints in MLE fitting
def logit(p):            # (0,1) -> ℝ
    return np.log(p) - np.log1p(-p)

def sigmoid(psi):        # ℝ -> (0,1)
    return 1.0 / (1.0 + np.exp(-psi))

def softplus_inv(z):     # (0,∞) -> ℝ   – inverse of log1p(exp(·))
    return np.log(np.expm1(z))

def softplus(phi):       # ℝ -> (0,∞)
    return np.log1p(np.exp(phi))

def softplus1_inv(xi):   # (-1,∞) -> ℝ   – inverse of log1p(exp(·))-1
    return np.log(np.expm1(xi + 1.0))

def softplus1(phi):      # ℝ -> (-1,∞)
    return np.log1p(np.exp(phi)) - 1.0