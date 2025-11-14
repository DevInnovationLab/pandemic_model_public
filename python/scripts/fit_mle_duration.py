from pathlib import Path

import click
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from pandemic_statistics.transform import DiagonalBijector, PassthroughBijector, SoftplusBijector
from pandemic_statistics.utils import parse_filtered_ds_fp
from scipy.optimize import minimize
from scipy.stats import lognorm

# Parameter transformations to fit in unconstrained space.

def nll_phi(phi, data, loc=0.5, transform=None):
    """Negative log-likelihood of exceedances y (>0) given φ=(ψ,φ1,φ2)."""
    theta = transform.backward(phi)
    ll = lognorm.logpdf(data, s=theta[1], scale=np.exp(theta[0]), loc=loc).sum()
    
    return -ll

def fit_duration(data, start_grid, floc=0.5, transform=None):
    """Fit lognormal distribution to data using MLE."""
    if transform is None:
        transform = DiagonalBijector([PassthroughBijector(), SoftplusBijector()])
        
    results = []
    for mu, sigma in start_grid:
        phi0 = transform.forward((mu, sigma))
        
        # Nelder-Mead optimization
        nelder_mead_opts = {
            'maxiter': 10000,
            'maxfev': 50000,
            'xatol': 1e-4,
            'fatol': 1e-4,
            'adaptive': True
        }
        
        opt = minimize(nll_phi, phi0, args=(data, floc, transform),
                       method='Nelder-Mead', options=nelder_mead_opts)
        
        if not opt.success:
            error_msg = f"Optimization failed: {opt.message}\n"
            error_msg += f"Status: {opt.status}\n"
            error_msg += f"Number of iterations: {opt.nit}\n"
            error_msg += f"Final function value: {opt.fun}\n"
            error_msg += f"Final parameters: {transform.backward(opt.x)}"
            raise RuntimeError(error_msg)
            
        # Calculate full Hessian at optimal point
        (est_mu, est_eta1) = opt.x
        est_mu, est_sigma = transform.backward(opt.x)
        info = len(data) * np.array([[1, 0], [0, 2]]) * (1 / est_eta1 ** 2)
        cov = np.linalg.inv(info)  # asymptotic covariance
        
        results.append({
            "start":   (mu, sigma),
            "mu":      est_mu,
            "sigma":   est_sigma,
            "opt":     opt,
            "success": opt.success,
            "fun":     opt.fun,
            "hess_inv": cov
        })
        
    df = pd.DataFrame(results)
    best = df.loc[df.fun.idxmin()]
    return df, best


@click.command()
@click.argument("fp", type=click.Path(exists=True, file_okay=True, dir_okay=False))
@click.option("--trunc-years", type=int, default=10, help='Max pandemic duration to allow.')
@click.option("--n-samples", type=int, default=50_000, help='Number of samples to draw.')
@click.option("--floc", type=float, default=0.5, help='Location parameter for lognormal distribution.')
@click.option("--outloc", type=float, default=None, help='To help debug how floc affects vaccine benefits.')
@click.option("--seed", type=int, default=42, help="Seed for random sample generation.")
@click.option("--create-fig/--no-fig", default=False)
def fit_mle_duration(fp: Path, trunc_years: int, n_samples: int, floc: float, outloc: float, seed: int, create_fig: bool):

    ds = pd.read_csv(fp)
    durations = ds['duration']
    rng = np.random.default_rng(seed)

    # If not floc override in output
    if outloc is None:
        outloc = floc

    # Create grid of starting points for mu and sigma
    duration_mean = durations.mean()
    duration_median = durations.median()

    start_grid = [
        (np.log(duration_mean), 0.5),  # Mean-based mu, moderate sigma
        (np.log(duration_mean), 1.0),  # Mean-based mu, larger sigma
        (np.log(duration_median), 0.5),  # Median-based mu, moderate sigma 
        (np.log(duration_median), 1.0),  # Median-based mu, larger sigma
        (np.log(duration_mean) - 0.5, 0.3),  # Lower mu, small sigma
        (np.log(duration_mean) + 0.5, 0.3)   # Higher mu, small sigma
    ]
    transform = DiagonalBijector([PassthroughBijector(), SoftplusBijector()]) # Convert sigma to unbounded space

    # Fit models with different starting points
    results_df, best_fit = fit_duration(durations, start_grid, floc=floc, transform=transform)

    # Check that all successful fits converge to similar parameter values
    successful_fits = results_df[results_df.success]
    
    if len(successful_fits) == 0:
        raise RuntimeError("No successful fits found")
        
    best_mu = best_fit.mu
    best_sigma = best_fit.sigma
    # Check all successful fits are within 1% of best fit
    mu_diffs = abs(successful_fits.mu - best_mu) / best_mu
    sigma_diffs = abs(successful_fits.sigma - best_sigma) / best_sigma
    
    divergent = (mu_diffs > 0.01) | (sigma_diffs > 0.01)
    if divergent.any():
        divergent_fit = successful_fits[divergent].iloc[0]
        raise RuntimeError(
            f"Found divergent fits:\n"
            f"Best fit: mu={best_mu:.3f}, sigma={best_sigma:.3f}\n"
            f"Alt fit: mu={divergent_fit.mu:.3f}, sigma={divergent_fit.sigma:.3f}\n"
            f"Percent diff: mu={mu_diffs[divergent].iloc[0]*100:.1f}%, sigma={sigma_diffs[divergent].iloc[0]*100:.1f}%"
        )

    # Draw sample based on MLE limiting distribution
    best_phi = best_fit.opt.x
    best_cov = best_fit.hess_inv

    phi_draws = rng.multivariate_normal(best_phi, best_cov, size=n_samples)
    theta_draws = np.vstack([transform.backward(phi) for phi in phi_draws])
    mu_sample, sigma_sample = np.hsplit(theta_draws, 2)

    id_string = "_".join(Path(fp).stem.split("_")[2:])
    outstring = id_string + f"_trunc_{trunc_years}_n_{n_samples}_seed_{seed}"
    outdir = Path("./output/duration_distributions")

    sample_df = pd.DataFrame({'mu': mu_sample.squeeze(), 'sigma': sigma_sample.squeeze(), 'trunc_value': trunc_years, 'loc': outloc})
    outpath = outdir / f"{outstring}.csv"
    sample_df.to_csv(outpath, index=0)

    if create_fig:
        # Time points for survival function evaluation
        t = np.linspace(0, trunc_years, 1000)

        # Calculate survival functions for each sampled mu, sigma pair
        t_mat = np.tile(t, (n_samples, 1))  # Shape: (1000, n_samples)
        survivals = lognorm.sf(t_mat, s=sigma_sample, scale=np.exp(mu_sample), loc=floc)

        # Calculate percentiles across samples at each time point
        percentiles = np.percentile(survivals, [5, 50, 95], axis=0)

        # Plot the survival functions
        plt.figure(figsize=(10, 6))
        plt.plot(t, percentiles[1], label='Median', color='blue')
        plt.plot(t, percentiles[0], label='5th percentile', color='blue', linestyle=':')
        plt.plot(t, percentiles[2], label='95th percentile', color='blue', linestyle=':')

        plt.xlabel('Years')
        plt.ylabel('Exceedance function')
        plt.title('Pandemic duration exceedance function')
        plt.legend()
        plt.grid(True, alpha=0.2)
        plt.gca().spines[['top', 'right']].set_visible(False)

        fig_fn = outdir / f"{outstring}.png"
        plt.savefig(fig_fn, dpi=500)


if __name__ == "__main__":
    fit_mle_duration()