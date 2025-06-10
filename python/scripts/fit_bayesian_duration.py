"""Fit Bayesian pandemic duration model.
    See note in notebook 28 on chosen calibration of the prior.
"""

import click
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import scipy
from matplotlib.lines import Line2D
from scipy.optimize import least_squares

# Constants
DEFAULT_TRUNC_YEARS = 10
plt.rc("axes.spines", top=False, right=False)

class NIGBayesianUpdater:
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
            
        sigma2_samples = scipy.stats.invgamma.rvs(a=self.alpha0, scale=self.beta0, size=n_samples, random_state=rng)
        mu_samples = scipy.stats.norm.rvs(loc=self.mu0, scale=np.sqrt(sigma2_samples / self.kappa0), random_state=rng)
        sigma_samples = np.sqrt(sigma2_samples)

        return mu_samples, sigma_samples

    def sample_posterior(self, n_samples=1000, rng=None):
        """
        Sample (mu, sigma) from the posterior distribution.
        """
        sigma2_samples = scipy.stats.invgamma.rvs(a=self.alpha_n, scale=self.beta_n, size=n_samples, random_state=rng)
        mu_samples = scipy.stats.norm.rvs(loc=self.mu_n, scale=np.sqrt(sigma2_samples / self.kappa_n), random_state=rng)
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
        mu_density     = scipy.stats.norm.pdf(MU, loc=self.mu0, scale=np.sqrt(SIGMA2 / self.kappa0))
        sigma2_density = scipy.stats.invgamma.pdf(SIGMA2, a=self.alpha0, scale=self.beta0)
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
        mu_density     = scipy.stats.norm.pdf(MU, loc=self.mu_n, scale=np.sqrt(SIGMA2 / self.kappa_n))
        sigma2_density = scipy.stats.invgamma.pdf(SIGMA2, a=self.alpha_n, scale=self.beta_n)
        density = 2 * SIGMA * mu_density * sigma2_density # Jacobian correction for σ² → σ
                
        return pd.DataFrame({
            'mu': MU.flatten(),
            'sigma': SIGMA.flatten(),
            'density': density.flatten()
        })
    
    
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
        cdf1 = scipy.stats.norm.cdf((np.log(t1)-mu)/sigma)
        cdf2 = scipy.stats.norm.cdf((np.log(t2)-mu)/sigma)
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


def plot_survival_from_nig(mu0, kappa0, alpha0, beta0, *,
                           t_max=DEFAULT_TRUNC_YEARS, n_points=1000, n_draws=50000, cred=0.90,
                           ax=None, label="NIG prior", color="C0"):
    """Visualise the distribution of survival curves implied by an NIG prior.

    Draws `n_draws` samples of (mu, sigma²) ~ NIG and plots the median survival
    function plus a central credible band of width `cred` (default 90%).
    """
    if ax is None:
        fig, ax = plt.subplots(figsize=(6,4))

    # sample sigma² then mu
    sigma2 = scipy.stats.invgamma.rvs(alpha0, scale=beta0, size=n_draws)
    sigma = np.sqrt(sigma2)
    mu = scipy.stats.norm.rvs(loc=mu0, scale=np.sqrt(sigma2/kappa0))

    t = np.linspace(1e-6, t_max, n_points)
    surv_samples = scipy.stats.lognorm.sf(t[:, None], sigma, scale=np.exp(mu))  # shape [T, draws]
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

@click.command()
@click.option('--n-samples', default=100_000, help='Number of samples to draw from the distribution')
@click.option('--trunc_duration', default=DEFAULT_TRUNC_YEARS, help='Upper truncation.')
def main(n_samples, trunc_duration):
    """Draw samples from the calibrated duration distribution."""
    click.echo(f"Drawing {n_samples} samples from the duration distribution...")

    # Load duration data
    final_allrisk_ds = pd.read_csv("./data/clean/final_allrisk_ds.csv")
    duration_data = final_allrisk_ds['duration']

    # Calibrate lognormal prior based on asnwers from the expert survey
    print("Calibrating central moments of Normal-inverse gamma prior distribution...")
    mu_target, sigma_target, resid_vec, resid_norm = calibrate_lognormal_three_bins(mean_target=3.43,
                                                                                    t1=2, t2=3,
                                                                                    p_lt_t1=1/6, p_between=1/3)
    print("Prior central moment calibration results:")
    print(f"LogNormal (mean≈3.43, P[2≤X≤3]=1/3): mu={mu_target:.4f}, sigma={sigma_target:.4f}")
    print(f"Residuals: {resid_vec}")
    
    kappa0 = 1
    alpha0 = 2
    print(f"Setting prior with minimal information assumptions alpha_0 = {alpha0} and kappa_0 = {kappa0}.")
    mu0, kappa0, alpha0, beta0 = calibrate_nig_prior(mu_target, sigma_target,
                                                     kappa0=kappa0, # Minimal information assumption
                                                     alpha0=alpha0 # Minimal information assumption
                                                     )
    print(f"NIG prior: (sigma^2 ~ IG({alpha0:.2f}, {beta0:.2f}, ~ N({mu0:.2f}, sigma^2 / {kappa0:.2f})))")

    # Fit posterior distribution
    fig, ax = plt.subplots(figsize=(10, 6))

    # Get true parameters from data
    sample_mu = np.log(duration_data).mean()
    sample_sigma = np.log(duration_data).std()

    # 2. Calibrated NIG prior using parameters from above
    cal_nig_updater = NIGBayesianUpdater(prior_type='NIG', mu0=mu0, kappa0=kappa0, alpha0=alpha0, beta0=beta0)
    cal_nig_updater.update(duration_data)
    cal_prior = cal_nig_updater.get_prior_grid()
    cal_post = cal_nig_updater.get_posterior_grid()
    cal_prior['type'] = 'Prior'
    cal_post['type'] = 'Posterior'
    nig_df = pd.concat([cal_prior, cal_post])

    # Fit MLE lognormal
    mle_params = scipy.stats.lognorm.fit(duration_data, floc=0)
    mle_sigma, _, mle_mu = mle_params  # fit returns (s, loc, scale)
    mle_mu = np.log(mle_mu)  # Convert scale to mu
    
    # Define colors for prior and posterior
    prior_color = sns.color_palette()[0]  # First color in default palette
    post_color = sns.color_palette()[1]   # Second color in default palette

    sns.kdeplot(
        data=nig_df,
        x='mu',
        y='sigma', 
        weights='density',
        hue='type',
        fill=False,
        levels=10,
        common_norm=False,
        ax=ax,
        bw_adjust=1.0,
        cut=0,
        palette=[prior_color, post_color],  # Set consistent colors
        label='Prior/Posterior'
    )
        
    # Add true value point
    ax.scatter(sample_mu, sample_sigma, color='red', s=200, label='Sample estimate')
    ax.scatter(mle_mu, mle_sigma, color='green', s=200, label='MLE')
    
    ax.set_title('Calibrated NIG prior/posterior')
    
    # Add legend with all elements
    handles = [
        plt.Line2D([], [], color=prior_color, label='Prior'),
        plt.Line2D([], [], color=post_color, label='Posterior'),
        plt.Line2D([], [], color='red', marker='o', linestyle='None', markersize=10, label='Sample estimate'),
        plt.Line2D([], [], color='green', marker='o', linestyle='None', markersize=10, label='MLE')
    ]
    ax.legend(handles=handles)

    plt.tight_layout()
    plt.savefig("./output/duration_distributions/allrisk_base_mu_sigma_density.jpg", dpi=400)

    # Plot survival function
    plt.figure(figsize=(10, 6))

    # Time points for survival function
    t = np.linspace(0, trunc_duration, 1000)

    # NIG posterior samples from calibrated NIG updater
    cal_mu_samples, cal_sigma_samples = cal_nig_updater.sample_posterior(n_samples)
    nig_samples = pd.DataFrame({
        'mu': cal_mu_samples,
        'sigma': cal_sigma_samples
    })

    # Calculate survival functions for each sample
    t_mat = np.tile(t, (n_samples, 1)).T
    nig_survivals = scipy.stats.lognorm.sf(t_mat, s=cal_sigma_samples, scale=np.exp(cal_mu_samples)) 

    # Calculate percentiles for credible intervals
    nig_percentiles = np.percentile(nig_survivals, [5, 50, 95], axis=1)

    # MLE survival function
    mle_survival = 1 - scipy.stats.lognorm.cdf(t, s=mle_sigma, scale=np.exp(mle_mu))

    # Plot using consistent colors from previous plots
    plt.plot(t, mle_survival, color='green', label='MLE estimate')

    # NIG posterior in blue
    plt.plot(t, nig_percentiles[1], color='blue', label='NIG posterior')
    plt.plot(t, nig_percentiles[0], color='blue', linestyle=':', alpha=0.5)
    plt.plot(t, nig_percentiles[2], color='blue', linestyle=':', alpha=0.5)

    # Add a single dotted line to legend representing 90% credible intervals
    plt.plot([], [], color='gray', linestyle=':', alpha=0.5, label='90% credible interval')

    plt.xlabel('Years')
    plt.ylabel('Exceedance probability')
    plt.title('Duration distribution comparison')
    plt.legend()
    plt.grid(True)
    plt.savefig("./output/duration_distributions/allrisk_base_survival_fn.jpg", dpi=400)

    nig_samples['trunc_value'] = trunc_duration
    nig_samples.to_csv("./output/duration_distributions/allrisk_base_mu_sigma_samples.csv", index=False)

if __name__ == "__main__":
    main()