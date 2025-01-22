# Fit interval regression and visualize.
import numpy as np
import pandas as pd
from scipy.stats import norm

from pandemic_model.stats import IntervalRegression

if __name__ == "__main__":

  ptrs = pd.read_csv("../../data/clean/vaccine_ptrs.csv")
  ptrs = ptrs.rename(columns={'value_min': 'lower_bound', 'value_max': 'upper_bound'})

  # Define model
  df = pd.get_dummies(ptrs,
                      columns=['disease', 'platform'],
                      prefix=['disease', 'platform'],
                      dtype=float)

  # Don't use respondent FEs for now.
  df = df \
    .drop(columns='respondent') \
    .dropna(axis=0, how='any') # Drop if NA responses.
  endog = df[['lower_bound', 'upper_bound']]
  exog = df.drop(columns=endog.columns)

  model = IntervalRegression(endog, exog)
  result = model.fit(disp=True)

  # Linear predictor
  beta = np.ones(exog.shape[1])
  sigma = 0.5
  XB = np.dot(exog, beta)

  # Compute probabilities for interval bounds
  lower_cdf = norm.cdf((endog['lower_bound'] - XB) / sigma)
  upper_cdf = norm.cdf((endog['upper_bound'] - XB) / sigma)

  likelihoods = upper_cdf - lower_cdf + 1e-10

  temp = np.log(likelihoods)


