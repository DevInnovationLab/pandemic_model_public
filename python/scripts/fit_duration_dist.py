"""fit_mle_duration.py — Fit a lognormal duration distribution via MLE and sample from the limiting distribution.

Fits a shifted lognormal distribution to pandemic duration data, verifies convergence consistency, and
draws samples from the asymptotic MLE distribution in the unconstrained (phi) space.

Inputs:  filtered epidemic CSV (CLI argument).
Outputs: CSV under ``--outdir``; PMF PDFs under ``--fig-outdir`` when ``--create-fig``
         (default ``output/duration_dist_figs``).

Usage:
    python scripts/fit_mle_duration.py <fp> [--outdir PATH] [--fig-outdir PATH] [--trunc-years N] [--n-samples N] [--floc F] [--seed N] [--create-fig]
"""
from pathlib import Path

import click
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from pandemic_statistics.grad import hess
from pandemic_model.pipeline_names import build_duration_csv_stem
from pandemic_model.plot_style import (
    apply_paper_axis_style,
    apply_paper_rc,
    get_paper_style,
    save_paper_figure,
)
from pandemic_statistics.utils import parse_filtered_ds_fp
from pandemic_statistics.transform import DiagonalBijector, PassthroughBijector, SoftplusBijector
from scipy.optimize import minimize
from scipy.stats import lognorm, norm

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
            
        # Calculate Hessian at optimal point
        est_mu, est_sigma = transform.backward(opt.x)

        n = len(data)
        info_theta = n * np.diag([1.0 / est_sigma**2, 2.0 / est_sigma**2])
        cov_theta = np.linalg.inv(info_theta) # = diag(sigma^2/n, sigma^2/(2n))
        cov_phi = np.linalg.inv(hess(lambda x: nll_phi(x, data, floc, transform), opt.x))
        
        results.append({
            "start":   (mu, sigma),
            "mu":      est_mu,
            "sigma":   est_sigma,
            "opt":     opt,
            "success": opt.success,
            "fun":     opt.fun,
            "cov_theta": cov_theta,
            "cov_phi":   cov_phi
        })
        
    df = pd.DataFrame(results)
    best = df.loc[df.fun.idxmin()]
    return df, best


def pmf_rounded_to_years(years, mu, sigma, floc, half_width=0.5):
    """Compute probability mass after rounding durations to nearest year.
 
    For each integer year k in `years`, the returned probability equals
    P(k - half_width <= duration < k + half_width) under a shifted lognormal.
 
    Parameters
    ----------
    years : array-like of int
        Integer year bins (bin centers).
    mu : float
        Lognormal mu parameter (where scale = exp(mu)).
    sigma : float
        Lognormal shape parameter.
    floc : float
        Location parameter of the shifted lognormal.
    half_width : float
        Half-width of each bin in years. Defaults to 0.5 (nearest year).
 
    Returns
    -------
    np.ndarray
        Probability mass for each element in `years`.
    """
    years = np.asarray(years, dtype=float)
    lo = np.maximum(0.0, years - half_width)
    hi = years + half_width
 
    dist_hi = lognorm.cdf(hi, s=sigma, scale=np.exp(mu), loc=floc)
    dist_lo = lognorm.cdf(lo, s=sigma, scale=np.exp(mu), loc=floc)
    pmf = dist_hi - dist_lo
 
    # Sharp truncation: all probability mass above the last bin is assigned to
    # the last year (i.e., treat its upper edge as +infinity).
    if pmf.size > 0:
        pmf[-1] = 1.0 - dist_lo[-1]
 
    return pmf


def survival_exceedance_and_grad(
    t: np.ndarray,
    mu: float,
    sigma: float,
    floc: float,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Survival function and partial derivatives for shifted lognormal.
    """
    t = np.asarray(t, dtype=float)
    x = t - floc
    s = np.ones_like(t, dtype=float)
    d_s_dmu = np.zeros_like(t, dtype=float)
    d_s_dsigma = np.zeros_like(t, dtype=float)
    safe = x > 0
    if np.any(safe):
        z = (np.log(x[safe]) - mu) / sigma
        s[safe] = norm.sf(z)
        phi_z = norm.pdf(z)
        d_s_dmu[safe] = phi_z / sigma
        d_s_dsigma[safe] = phi_z * z / sigma
    return s, d_s_dmu, d_s_dsigma


@click.command()
@click.argument("fp", type=click.Path(exists=True, file_okay=True, dir_okay=False))
@click.option(
    "--outdir",
    type=click.Path(file_okay=False, path_type=Path),
    default=Path("./data/clean/duration_distributions"),
    help="Directory for parameter sample CSVs.",
)
@click.option(
    "--fig-outdir",
    type=click.Path(file_okay=False, path_type=Path),
    default="output/duration_dist_figs",
    help="Directory for PMF PDFs when --create-fig (default: output/duration_dist_figs).",
)
@click.option("--trunc-years", type=int, default=10, help='Max pandemic duration to allow.')
@click.option("--n-samples", type=int, default=50_000, help='Number of samples to draw.')
@click.option("--floc", type=float, default=0.5, help='Location parameter for lognormal distribution.')
@click.option("--seed", type=int, default=42, help="Seed for random sample generation.")
@click.option("--create-fig/--no-fig", default=False)
def fit_mle_duration(
    fp: Path,
    outdir: Path,
    fig_outdir: Path | None,
    trunc_years: int,
    n_samples: int,
    floc: float,
    seed: int,
    create_fig: bool,
):
    """Fit lognormal duration distribution and write parameter samples to disk."""
    fp = Path(fp).resolve()
    outdir = Path(outdir).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    ds = pd.read_csv(fp)
    durations = ds['duration']
    rng = np.random.default_rng(seed)

    # --- Fit model from multiple starting points ---

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
 
    # --- Validate convergence consistency ---

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
 
    # --- Sample from asymptotic MLE distribution ---

    # Draw from the multivariate normal limiting distribution in phi-space
    # (unconstrained parameterisation), then back-transform to (mu, sigma).
    best_phi = best_fit.opt.x
    best_cov_phi = best_fit.cov_phi
 
    phi_draws = rng.multivariate_normal(best_phi, best_cov_phi, size=n_samples)
    theta_draws = np.vstack([transform.backward(phi) for phi in phi_draws])
    mu_sample, sigma_sample = np.hsplit(theta_draws, 2)
 
    meta = parse_filtered_ds_fp(fp)
    outstring = build_duration_csv_stem(
        meta.lineage,
        meta.filter_slug,
        trunc_years,
        n_samples,
        seed,
    )

    sample_df = pd.DataFrame(
        {
            "mu": mu_sample.squeeze(),
            "sigma": sigma_sample.squeeze(),
            "trunc_value": trunc_years,
            "loc": floc,
        }
    )
    outpath = outdir / f"{outstring}.csv"
    sample_df.to_csv(outpath, index=0)

    if create_fig:
        fig_dir = (
            Path(fig_outdir).resolve()
            if fig_outdir is not None
            else Path("./output/duration_dist_figs").resolve()
        )
        fig_dir.mkdir(parents=True, exist_ok=True)
        figstyle = get_paper_style("double_col_standard")
        figstyle_exceedance = get_paper_style("double_col_wide")
        apply_paper_rc(figstyle)

        # --- Build discretized PMF for diagnostic plots ---

        # Integer bins for "rounded to nearest year" PMF.
        # Bin k corresponds to durations in [k - 0.5, k + 0.5).
        years = np.arange(0, trunc_years + 1, dtype=int)
        half_width = 0.5
        lo_edges = np.maximum(0.0, years - half_width)
        hi_edges = years + half_width
 
        # MLE rounded-year PMF.
        mle_pmf = pmf_rounded_to_years(
            years=years,
            mu=best_mu,
            sigma=best_sigma,
            floc=floc,
            half_width=half_width,
        )
 
        # Delta-method CI for the discretized PMF.
        cov_theta = best_fit.cov_theta 
 
        def _z_and_phi(edges, mu, sigma, floc):
            """Standardized lognormal ordinates; zero where the edge is at/below floc (no log on x<=0).

            Note: ``np.where`` evaluates both branches, so ``np.log(x)`` must not be used inside it.
            """
            x = edges - floc
            safe = x > 0
            z = np.zeros_like(x, dtype=float)
            phi = np.zeros_like(x, dtype=float)
            if np.any(safe):
                z_s = (np.log(x[safe]) - mu) / sigma
                z[safe] = z_s
                phi[safe] = norm.pdf(z_s)
            return z, phi
 
        inner_lo, phi_lo = _z_and_phi(lo_edges, best_mu, best_sigma, floc)
        inner_hi, phi_hi = _z_and_phi(hi_edges, best_mu, best_sigma, floc)
 
        # Address upper bin that continue to infinity
        inner_hi[-1] = 0.0
        phi_hi[-1] = 0.0
 
        dp_dmu    = (phi_lo - phi_hi) / best_sigma
        dp_dsigma = (phi_lo * inner_lo - phi_hi * inner_hi) / best_sigma
 
        # Exploit diagonal covariance for a simpler variance formula.
        var_p = cov_theta[0, 0] * dp_dmu**2 + cov_theta[1, 1] * dp_dsigma**2
        se = np.sqrt(var_p)
        z = 1.96
 
        # Plot PMF with 95% CI as error bars.
        fig, ax = plt.subplots(figsize=(figstyle.width_in, figstyle.height_in))
        ax.bar(years, mle_pmf, color="blue", alpha=0.5)
        ax.errorbar(
            years[1:],
            mle_pmf[1:],
            yerr=z*se[1:],
            fmt="none",
            ecolor="blue",
            alpha=0.9,
            capsize=3,
            elinewidth=figstyle.secondary_lw,
        )
 
        ax.set_xlabel("Years", fontsize=figstyle.axis_label_size, fontfamily=figstyle.font_family)
        ax.set_ylabel("Probability mass", fontsize=figstyle.axis_label_size, fontfamily=figstyle.font_family)
        ax.set_xticks(years)
        apply_paper_axis_style(ax, figstyle)
 
        fig_fn = fig_dir / f"{outstring}_pmf_rounded_years_with_ci.pdf"
        save_paper_figure(fig, fig_fn, dpi=600)

        # --- Exceedance curve S(t)=P(T>t) with 95% delta-method CI ---
        t_grid = np.linspace(floc + 1e-6, float(trunc_years), 300)
        mle_sf, g_mu, g_sigma = survival_exceedance_and_grad(
            t_grid, best_mu, best_sigma, floc
        )
        var_sf = cov_theta[0, 0] * g_mu**2 + cov_theta[1, 1] * g_sigma**2
        se_sf = np.sqrt(np.maximum(var_sf, 0.0))
        z95 = 1.96
        lower_sf = np.clip(mle_sf - z95 * se_sf, 0.0, 1.0)
        upper_sf = np.clip(mle_sf + z95 * se_sf, 0.0, 1.0)

        fig, ax = plt.subplots(figsize=(figstyle_exceedance.width_in, figstyle_exceedance.height_in))
        ax.fill_between(
            t_grid,
            lower_sf,
            upper_sf,
            color="blue",
            alpha=figstyle_exceedance.ci_alpha,
            label="95% confidence interval",
        )
        ax.plot(
            t_grid,
            mle_sf,
            color="blue",
            linewidth=figstyle_exceedance.primary_lw,
            alpha=0.9,
            label="MLE",
        )
        ax.set_xlabel(
            "Duration (years)",
            fontsize=figstyle_exceedance.axis_label_size,
            fontfamily=figstyle_exceedance.font_family,
        )
        ax.set_ylabel(
            "Exceedance probability",
            fontsize=figstyle_exceedance.axis_label_size,
            fontfamily=figstyle_exceedance.font_family,
        )
        ax.set_xlim(float(t_grid[0]), float(t_grid[-1]))
        ax.set_ylim(0.0, 1.0)
        apply_paper_axis_style(ax, figstyle_exceedance)
        ax.legend(
            loc="upper right",
            frameon=False,
            prop={"family": figstyle_exceedance.font_family, "size": figstyle_exceedance.legend_size},
        )
        fig_fn = fig_dir / f"{outstring}_exceedance.pdf"
        save_paper_figure(fig, fig_fn, dpi=600)
        plt.close("all")


if __name__ == "__main__":
    fit_mle_duration()
