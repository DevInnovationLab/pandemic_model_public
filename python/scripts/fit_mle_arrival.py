from pathlib import Path
from typing import Tuple

import click
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import yaml
from scipy.optimize import approx_fprime, minimize
from scipy.stats import genpareto

from pandemic_model.stats.utils import logit, sigmoid, softplus, softplus_inv, softplus1, softplus1_inv
from pandemic_model.utils import get_measure_units, parse_epidemics_fp

def to_phi(theta):
    """θ = (p, ξ, σ)  →  φ = (ψ, φ₁, φ₂)  all in ℝ"""
    p, xi, sigma = theta
    return np.array([logit(p), softplus1_inv(xi), softplus_inv(sigma)])

def from_phi(phi):
    """φ = (ψ, φ₁, φ₂) → θ = (p, ξ, σ)  all valid"""
    psi, phi1, phi2 = phi
    return np.array([sigmoid(psi), softplus1(phi1), softplus(phi2)])

# ------------------------------------------------------------------
# 2.  NEGATIVE LOG-LIKELIHOOD  (optionally truncated)
# ------------------------------------------------------------------
def nll_phi(phi, data, y_min=0, y_max=None):
    """Negative log-likelihood of exceedances y (>0) given φ=(ψ,φ1,φ2)."""
    p, xi, sigma = from_phi(phi)
    
    n = len(data)
    excess_idx = data > y_min
    excesses = data[excess_idx]
    n_exceed = excess_idx.sum()

    # Binomial term for p
    ll = n_exceed * np.log(p) + (n - n_exceed) * np.log1p(-p)
    
    # GPD term for (xi,sigma)
    ll += genpareto.logpdf(excesses, c=xi, scale=sigma).sum()

    # add truncation term if an upper limit exists
    if y_max is not None and np.isfinite(y_max):
        ll -= n_exceed * genpareto.logcdf(y_max, c=xi, scale=sigma)

    return -ll

def hess(f, x, eps=1e-4):
    """Numerical Hessian approximation."""
    n = len(x)
    H = np.empty((n, n), float)
    ei = np.zeros(n)

    # central differences for second partials
    for i in range(n):
        ei[i] = eps
        for j in range(i, n):
            ej = np.zeros_like(ei)
            ej[j] = eps
            
            H[i, j] = (
                f(x + ei + ej) - f(x + ei - ej)
              - f(x - ei + ej) + f(x - ei - ej)
            ) / (4 * eps * eps)
            H[j, i] = H[i, j]
        ei[i] = 0.0

    # tiny asymmetry/round-off
    return H

# ------------------------------------------------------------------
# 3.  MULTI-START MLE FOR (p,ξ,σ)
# ------------------------------------------------------------------
def fit_tail(data, start_grid, y_min=0, y_max=None):
    results = []
    for p0, xi0, sig0 in start_grid:
        phi0 = to_phi((p0, xi0, sig0))
        
        # Nelder-Mead optimization
        nelder_mead_opts = {
            'maxiter': 10000,
            'maxfev': 50000,
            'xatol': 1e-4,
            'fatol': 1e-4,
            'adaptive': True
        }
        
        opt = minimize(nll_phi, phi0, args=(data, y_min, y_max),
                       method='Nelder-Mead', options=nelder_mead_opts)
        
        if not opt.success:
            error_msg = f"Optimization failed: {opt.message}\n"
            error_msg += f"Status: {opt.status}\n"
            error_msg += f"Number of iterations: {opt.nit}\n"
            error_msg += f"Final function value: {opt.fun}\n"
            error_msg += f"Final parameters: {from_phi(opt.x)}"
            raise RuntimeError(error_msg)
            
        # Calculate full Hessian at optimal point
        info = hess(lambda x: nll_phi(x, data, y_min, y_max), opt.x)
        cov = np.linalg.inv(info)  # asymptotic covariance
        
        est_p, est_xi, est_sigma = from_phi(opt.x)
        results.append({
            "start":   (p0, xi0, sig0),
            "p":       est_p,
            "xi":      est_xi,
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
@click.option("--trunc-method", type=click.Choice(['sharp', 'smooth']), default='sharp')
@click.option("--upper-bound", type=float, default=60)
@click.option("--n-samples", type=int, default=50_000)
@click.option("--seed", type=int, default=42)
@click.option("--create-fig/--no-fig", default=False)
def fit_mle_arrival(fp, trunc_method, upper_bound, n_samples, seed, create_fig):

    ds = pd.read_csv(fp)
    scope, measure, lower_threshold, year_min = parse_epidemics_fp(fp)
    rng = np.random.default_rng(seed)

    measure_data = ds.set_index('year_start')[measure].copy()
    all_years = pd.Series(range(year_min, 2023 + 1))
    measure_annual = measure_data.reindex(all_years, fill_value=0)

    excess_idx = measure_annual > lower_threshold
    p0 = excess_idx.sum() / len(measure_annual)
    excesses = measure_annual[excess_idx]

    start_grid = [
        (p0,  0.1,  excesses.mean()),
        (p0,  0.5,  excesses.mean()),
        (p0, -0.1,  excesses.std()),
        (p0,  0.2,  excesses.median()),
    ]

    fit_upper = None if trunc_method == 'sharp' else upper_bound
    results_df, best_fit = fit_tail(measure_annual, start_grid, lower_threshold, fit_upper)

    # Check that all successful fits converge to similar parameter values
    successful_fits = results_df[results_df.success]
    
    if len(successful_fits) == 0:
        raise RuntimeError("No successful fits found")
        
    best_p, best_xi, best_sigma = best_fit.p, best_fit.xi, best_fit.sigma
    
    # Check all successful fits are within 1% of best fit
    p_diffs = abs(successful_fits.p - best_p) / best_p
    xi_diffs = abs(successful_fits.xi - best_xi) / best_xi  
    sigma_diffs = abs(successful_fits.sigma - best_sigma) / best_sigma

    divergent = (p_diffs > 0.01) | (xi_diffs > 0.01) | (sigma_diffs > 0.01)
    if divergent.any():
        divergent_fit = successful_fits[divergent].iloc[0]
        raise RuntimeError(
            f"Found divergent fits:\n"
            f"Best fit: p={best_p:.3f}, xi={best_xi:.3f}, sigma={best_sigma:.3f}\n"
            f"Alt fit: p={divergent_fit.p:.3f}, xi={divergent_fit.xi:.3f}, sigma={divergent_fit.sigma:.3f}\n"
            f"Percent diff: p={p_diffs[divergent].iloc[0]*100:.1f}%, "
            f"xi={xi_diffs[divergent].iloc[0]*100:.1f}%, "
            f"sigma={sigma_diffs[divergent].iloc[0]*100:.1f}%"
        )

    # Get phi_hat and V_phi from both methods
    phi_hat = best_fit.opt.x
    V_phi = best_fit.hess_inv

    # Draw samples for truncation method
    phi_sample = rng.multivariate_normal(phi_hat, V_phi, size=n_samples)
    theta_sample = np.vstack([from_phi(phi_row) for phi_row in phi_sample])
    p_sample, xi_sample, sigma_sample = np.hsplit(theta_sample, 3)

    hyperparams =  {
        'trunc_method': trunc_method,
        'measure': measure
    }
    
    param_samples = {
        'xi': xi_sample.squeeze().tolist(),
        'sigma': sigma_sample.squeeze().tolist(), 
        'p': p_sample.squeeze().tolist(),
        'mu': [lower_threshold] * n_samples,
        'max_value': [upper_bound] * n_samples
    }

    config = {
        'hyperparams': hyperparams,
        'param_samples': param_samples
    }

    outdir = Path("./output/arrival_distributions")
    id_string = f"{scope}_{measure}_{str(lower_threshold).replace('.', 'd')}_{year_min}_{trunc_method}_{int(upper_bound)}_n_{n_samples}_seed_{seed}"
    outpath = outdir / f"{id_string}.yaml"

    with open(outpath, 'w') as f:
        yaml.dump(config, f)

    if create_fig:
        # Create figure with n x 2 subplots where n is number of upper bounds
        fig, ax = plt.subplots(figsize=(10, 6))

        x = np.logspace(np.log10(lower_threshold), np.log10(upper_bound), 1000)
        x_mat = np.tile(x, (n_samples, 1))

        # Calculate survival functions for each sample
        if trunc_method == 'sharp':
            norm = 1
        elif trunc_method == 'smooth':
            norm = genpareto.cdf(
                upper_bound,
                xi_sample,
                loc=lower_threshold,
                scale=sigma_sample
            )

        survivals = (
            p_sample * ( 
                1 - genpareto.cdf(
                    x_mat,
                    xi_sample,
                    loc=lower_threshold,
                    scale=sigma_sample
                ) / norm
            )
        )

        # Calculate percentiles for credible intervals
        percentiles = np.percentile(survivals, [5, 50, 95], axis=0)

        # Plot on left subplot (truncated)
        ax.plot(x, percentiles[1], '-', linewidth=2, label=f'Median', color='blue')
        ax.plot(x, percentiles[0], ':', alpha=0.5, color='blue')
        ax.plot(x, percentiles[2], ':', alpha=0.5, color='blue')

        # For Taleb transform, create thresholds over positive domain
        measure_lab = get_measure_units(measure).capitalize()
            
        ax.set_xscale('log')
        ax.grid(True, alpha=0.3)
        ax.set_xlabel(measure_lab)
        ax.set_ylabel('Exceedance probability')
        # Only add legend to first subplot
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)

        # Add legend with median and quantiles
        ax.plot([], [], ':', color='blue', alpha=0.5, label='5th/95th percentiles')
        ax.legend()

        # Set titles
        ax.set_title(f'Novel zoonotic pandemic exceedance function', fontsize=15)

        plt.tight_layout()

        outpath = outdir / f"{id_string}.png"
        plt.savefig(outpath, dpi=400)


if __name__ == "__main__":
    fit_mle_arrival()