"""Bayesian modeling classes and functions."""

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.optimize import fsolve, least_squares
from scipy.stats import lognorm, invgamma, norm


class LogNormalBayesianUpdater:
    def __init__(self, prior_type='reference', mu0=0, kappa0=0.01, alpha0=1.1, beta0=1):
        """
        Initialize the Bayesian updater.
        
        prior_type: 'reference' or 'NIG' (Normal-Inverse-Gamma)
        mu0, kappa0, alpha0, beta0: Hyperparameters for NIG prior
        """
        if prior_type not in ['reference', 'NIG']:
            raise ValueError("prior_type must be either 'reference' or 'NIG'")
        self.prior_type = prior_type
        self.mu0 = mu0
        self.kappa0 = kappa0
        self.alpha0 = alpha0
        self.beta0 = beta0

    def update(self, X):
        """
        Update posterior given observed data X (lognormal data).
        """
        self.X = X
        self.Y = np.log(X)  # work on log scale
        self.n = len(X)
        self.y_bar = np.mean(self.Y)
        self.S = np.sum((self.Y - self.y_bar) ** 2)

        if self.prior_type == 'NIG':
            self.kappa_n = self.kappa0 + self.n
            self.mu_n = (self.kappa0 * self.mu0 + self.n * self.y_bar) / self.kappa_n
            self.alpha_n = self.alpha0 + self.n / 2
            self.beta_n = (self.beta0 + 0.5 * self.S + 
                           0.5 * self.kappa0 * self.n * (self.y_bar - self.mu0)**2 / self.kappa_n)
        elif self.prior_type == 'reference':
            self.kappa_n = self.n
            self.mu_n = self.y_bar
            self.alpha_n = (self.n - 1) / 2
            self.beta_n = self.S / 2
    
    def sample_prior(self, n_samples=1000, rng=None):
        """
        Sample (mu, sigma) from the prior distribution.
        
        Parameters
        ----------
        n_samples : int
            Number of samples to draw from the prior distribution
            
        Returns
        -------
        tuple
            (mu_samples, sigma_samples) drawn from the prior distribution.
            Returns None, None if using reference prior since it is improper.
        """
        if self.prior_type == 'reference':
            print("Reference prior is improper (only defined up to proportionality). Skipping prior samples.")
            return None, None
            
        sigma2_samples = invgamma.rvs(a=self.alpha0, scale=self.beta0, size=n_samples, random_state=rng)
        mu_samples = norm.rvs(loc=self.mu0, scale=np.sqrt(sigma2_samples / self.kappa0), random_state=rng)
        sigma_samples = np.sqrt(sigma2_samples)

        return mu_samples, sigma_samples

    def sample_posterior(self, n_samples=1000, rng=None):
        """
        Sample (mu, sigma) from the posterior distribution.
        """
        sigma2_samples = invgamma.rvs(a=self.alpha_n, scale=self.beta_n, size=n_samples, random_state=rng)
        mu_samples = norm.rvs(loc=self.mu_n, scale=np.sqrt(sigma2_samples / self.kappa_n), random_state=rng)
        sigma_samples = np.sqrt(sigma2_samples)

        return mu_samples, sigma_samples
   
    def get_prior_grid(self, mu_range=None, sigma_range=None, n_points=100):
        """
        Calculate the analytical prior probability density function on a grid.
        
        Parameters
        ----------
        mu_range : tuple, optional
            Range of mu values (min, max). If None, determined automatically.
        sigma_range : tuple, optional
            Range of sigma values (min, max). If None, determined automatically.
        n_points : int, optional
            Number of points to use in each dimension, by default 50
            
        Returns
        -------
        dict
            Dictionary containing grid points and density values:
            - 'mu_grid': 2D array of mu values
            - 'sigma_grid': 2D array of sigma values 
            - 'density': 2D array of density values
        """
        if self.prior_type == 'reference':
            print("Reference prior is improper. Cannot calculate analytical PDF.")
            return None
        
        # Generate grid of points
        if mu_range is None: # Three expected stds around mean
            mu_range = (self.mu0 - 3 * np.sqrt(self.beta0 / ((self.alpha0 - 1) * self.kappa0)), # 
                        self.mu0 + 3 * np.sqrt(self.beta0 / ((self.alpha0 - 1) * self.kappa0)))
        
        if sigma_range is None:
            mode_sigma = np.sqrt(self.beta0 / (self.alpha0 + 1))  # Mode of inverse gamma
            sigma_range = (mode_sigma / 3, mode_sigma * 3)
        
        mu_grid = np.linspace(*mu_range, n_points)
        sigma_grid = np.linspace(*sigma_range, n_points)
        MU, SIGMA = np.meshgrid(mu_grid, sigma_grid)
        
        # Calculate prior density
        SIGMA2 = SIGMA ** 2
        
        # p(mu, sigma²) = p(mu|sigma²) * p(sigma²)
        # p(mu|sigma²) = Normal(mu0, sigma²/kappa0)
        # p(sigma²) = InvGamma(alpha0, beta0)
        mu_density     = norm.pdf(MU, loc=self.mu0, scale=np.sqrt(SIGMA2 / self.kappa0))
        sigma2_density = invgamma.pdf(SIGMA2, a=self.alpha0, scale=self.beta0)
        density = 2 * SIGMA * mu_density * sigma2_density # Jacobian correction for σ² → σ
                
        return pd.DataFrame({
            'mu': MU.flatten(),
            'sigma': SIGMA.flatten(),
            'density': density.flatten()
        })

    def get_posterior_grid(self, mu_range=None, sigma_range=None, n_points=100):
        """
        Calculate the analytical posterior probability density function on a grid.
        
        Parameters
        ----------
        mu_range : tuple, optional
            Range of mu values (min, max). If None, determined automatically.
        sigma_range : tuple, optional
            Range of sigma values (min, max). If None, determined automatically.
        n_points : int, optional
            Number of points to use in each dimension, by default 50
            
        Returns
        -------
        dict
            Dictionary containing grid points and density values:
            - 'mu_grid': 2D array of mu values
            - 'sigma_grid': 2D array of sigma values
            - 'density': 2D array of density values
        """
        # Generate grid of points
        if mu_range is None:
            mu_range = (self.mu_n - 3 * np.sqrt(self.beta_n / ((self.alpha_n - 1) * self.kappa_n)), 
                        self.mu_n + 3 * np.sqrt(self.beta_n / ((self.alpha_n - 1) * self.kappa_n)))
        
        if sigma_range is None:
            mode_sigma = np.sqrt(self.beta_n / (self.alpha_n + 1))  # Mode of inverse gamma
            sigma_range = (mode_sigma / 3, mode_sigma * 3)
        
        mu_grid = np.linspace(mu_range[0], mu_range[1], n_points)
        sigma_grid = np.linspace(sigma_range[0], sigma_range[1], n_points)
        MU, SIGMA = np.meshgrid(mu_grid, sigma_grid)
        
        # Calculate posterior density
        SIGMA2 = SIGMA**2
        
        # p(mu, sigma²|data) = p(mu|sigma², data) * p(sigma²|data)
        # p(mu|sigma², data) = Normal(mu_n, sigma²/kappa_n)
        # p(sigma²|data) = InvGamma(alpha_n, beta_n)
        mu_density     = norm.pdf(MU, loc=self.mu_n, scale=np.sqrt(SIGMA2 / self.kappa_n))
        sigma2_density = invgamma.pdf(SIGMA2, a=self.alpha_n, scale=self.beta_n)
        density = 2 * SIGMA * mu_density * sigma2_density # Jacobian correction for σ² → σ
                
        return pd.DataFrame({
            'mu': MU.flatten(),
            'sigma': SIGMA.flatten(),
            'density': density.flatten()
        })
    

def calibrate_lognormal_interval(mean_target, lower, upper, interval_prob):
    """Calibrate (mu, sigma) so that E[X]=mean_target and P(lower<=X<=upper)=interval_prob."""
    def eq(vars):
        mu, sigma = vars
        m = np.exp(mu + sigma**2/2) - mean_target
        cdf = norm.cdf
        p = cdf((np.log(upper)-mu)/sigma) - cdf((np.log(lower)-mu)/sigma) - interval_prob
        return [m, p]
    
    mu_init, sigma_init = np.log(mean_target), 0.3
    return fsolve(eq, [mu_init, sigma_init])


def calibrate_lognormal_three_bins(mean_target, t1, t2, p_lt_t1, p_between, max_iter=1000):
    """Calibrate lognormal parameters (mu, sigma) to match target mean and probability mass in three bins.
    
    Args:
        mean_target (float): Target mean value for the lognormal distribution
        t1 (float): First time threshold separating bins
        t2 (float): Second time threshold separating bins  
        p_lt_t1 (float): Target probability mass below t1
        p_between (float): Target probability mass between t1 and t2
        max_iter (int, optional): Maximum number of iterations for optimization. Defaults to 1000.
        
    Returns:
        tuple: Contains:
            - mu (float): Calibrated location parameter
            - sigma (float): Calibrated scale parameter 
            - residuals (array): Vector of residuals for mean and probability constraints
            - residual_norm (float): L2 norm of residuals
    """
    
    def residuals(vars):
        mu, sigma = vars
        mean_res = np.exp(mu + sigma**2/2) - mean_target
        cdf1 = norm.cdf((np.log(t1)-mu)/sigma)
        cdf2 = norm.cdf((np.log(t2)-mu)/sigma)
        p1_res = cdf1 - p_lt_t1
        p2_res = (cdf2 - cdf1) - p_between
        return np.array([mean_res, p1_res, p2_res])
    
    mu0, sigma0 = np.log(mean_target), 0.4
    sol = least_squares(residuals, (mu0, sigma0), bounds=([-10,1e-3],[10,5]), max_nfev=max_iter)
    
    if not sol.success:
        raise RuntimeError("Calibration failed: "+sol.message)
    
    resid_vec = residuals(sol.x)
    resid_norm = float(np.linalg.norm(resid_vec))
    return float(sol.x[0]), float(sol.x[1]), resid_vec, resid_norm


def calibrate_nig_prior(mu_target, sigma_target, kappa0=1, alpha0=2):
    """Return (mu0, kappa0, alpha0, beta0) so that E[μ]=mu_target and E[σ²]=sigma_target²."""
    mu0 = mu_target
    beta0 = (alpha0 - 1) * sigma_target ** 2  # sets E[σ²]=sigma_target²
    return mu0, kappa0, alpha0, beta0

# -----------------------------------------------------------------------------
# Plot survival envelope induced by an NIG prior
# -----------------------------------------------------------------------------
def plot_survival_from_nig(mu0, kappa0, alpha0, beta0, *,
                           t_max, n_points=1000, n_draws=50000, cred=0.90,
                           ax=None, label="NIG prior", color="C0"):
    """Visualise the distribution of survival curves implied by an NIG prior.

    Draws `n_draws` samples of (mu, sigma²) ~ NIG and plots the median survival
    function plus a central credible band of width `cred` (default 90%).
    """
    if ax is None:
        fig, ax = plt.subplots(figsize=(6,4))

    # sample sigma² then mu
    sigma2 = invgamma.rvs(alpha0, scale=beta0, size=n_draws)
    sigma = np.sqrt(sigma2)
    mu = norm.rvs(loc=mu0, scale=np.sqrt(sigma2/kappa0))

    t = np.linspace(1e-6, t_max, n_points)
    surv_samples = lognorm.sf(t[:, None], sigma, scale=np.exp(mu))  # shape [T, draws]
    print(surv_samples.shape)

    median = np.median(surv_samples, axis=1)
    lower = np.quantile(surv_samples, (1-cred)/2, axis=1)
    upper = np.quantile(surv_samples, 1-(1-cred)/2, axis=1)

    ax.plot(t, lower, color=color, linestyle='--')
    ax.plot(t, median, color=color, lw=2, label=f"Median")
    ax.plot(t, upper, color=color, linestyle='--', label=f"{int(cred*100)}% credible interval")
    
    ax.set_title("NIG duration distribution prior")
    ax.set_xlabel("Years")
    ax.set_ylabel("Exceedance probability")
    ax.set_xlim(0, t_max)
    ax.grid(True, which="both", ls=":", lw=0.6)
    ax.legend()
    return ax