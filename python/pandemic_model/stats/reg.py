# pip install jax jaxlib optax
from typing import Literal, Optional, Tuple, Dict, List

import numpy as np
import jax
import jax.numpy as jnp
import optax
from dataclasses import dataclass
from jax.scipy.special import log_ndtr
from tqdm import tqdm

# --------- small utilities for design matrices ---------
def one_hot_int(ids: np.ndarray) -> Tuple[jnp.ndarray, Dict[int, int]]:
    """
    Simple one-hot encoder for integer-coded categories.
    Returns (n x K) matrix and a mapping {original_id: column_index}.
    """
    uniq = np.unique(ids)
    col_map = {int(v): i for i, v in enumerate(uniq)}
    n, k = len(ids), len(uniq)
    X = np.zeros((n, k), dtype=float)
    for r, v in enumerate(ids):
        X[r, col_map[int(v)]] = 1.0
    return jnp.asarray(X), col_map


def design_matrix_auto(
    df, columns: List[str], drop_first: bool = True
) -> Tuple[jnp.ndarray, Dict[str, List[str]]]:
    """
    Tiny helper to build a numeric design matrix from a pandas DataFrame:
    - numeric columns: used as-is (float).
    - object/category columns: one-hot encoded.
    Returns (X, feature_names_by_source).
    """
    import pandas as pd  # lazy import
    feats = []
    name_map: Dict[str, List[str]] = {}
    for col in columns:
        s = df[col]
        if pd.api.types.is_numeric_dtype(s):
            feats.append(jnp.asarray(s.values, dtype=jnp.float32)[:, None])
            name_map[col] = [col]
        else:
            cats = s.astype("category")
            dummies = pd.get_dummies(cats, drop_first=drop_first)
            feats.append(jnp.asarray(dummies.values, dtype=jnp.float32))
            name_map[col] = list(dummies.columns.astype(str))
    X = jnp.concatenate(feats, axis=1) if feats else jnp.zeros((len(df), 0), dtype=jnp.float32)
    return X, name_map


# --------- model ---------
@dataclass
class FitResult:
    params: dict
    se: dict
    converged: bool
    nit: int
    fun: float


class IntervalMixedRE:
    """
    General interval regression with a single random-intercept factor (group_idx).

    family:
      - 'gaussian' : intervals on original latent scale (Normal errors)
      - 'logistic' : intervals are probabilities -> transform by logit; predictions map back via sigmoid

    integrator:
      - 'laplace' : Laplace approx (profile over b, add curvature term)
      - 'aghq'    : Adaptive Gauss–Hermite quadrature, 1-D integral per group (most accurate for 1D RE)
      - 'mc'      : Monte-Carlo (reparameterization b = tau*z), robust & scalable

    Notes:
      * One random-intercept factor (group_idx) for now. You can extend to random slopes later.
      * Common sigma across observations (can be extended to per-group sigma_i).
    """
    def __init__(
        self,
        family: Literal["gaussian", "logistic"] = "gaussian",
        integrator: Literal["laplace", "mc"] = "mc",
        n_quad: int = 11,
        n_mc: int = 128,
        eps: float = 1e-6,
        maxiter: int = 1500,
        lr: float = 0.05,
        key: int = 0,
    ):
        self.family = family
        self.integrator = integrator
        self.n_quad = n_quad
        self.n_mc = n_mc
        self.eps = eps
        self.maxiter = maxiter
        self.lr = lr
        self.rng = jax.random.PRNGKey(key)

        self.fitted_: Optional[FitResult] = None
        self._cache_ = None  # will store transformed bounds & training matrices
        self.history_ = [] # Will store history from fit routine

    # ---------- family transforms ----------
    def _transform_bounds(self, L, U):
        if self.family == "logistic":
            finL = jnp.isfinite(L)
            finU = jnp.isfinite(U)

            # clip finite probs away from 0/1, leave ±inf as-is
            Lc = jnp.where(finL, jnp.clip(L, self.eps, 1.0 - self.eps), L)
            Uc = jnp.where(finU, jnp.clip(U, self.eps, 1.0 - self.eps), U)

            # logit-transform only finite entries
            logit = lambda p: jnp.log(p / (1.0 - p))
            l = jnp.where(finL, logit(Lc), L)  # keep ±inf unchanged
            u = jnp.where(finU, logit(Uc), U)
            
            return l, u
        elif self.family == "gaussian":
            return L, U
        else:
            raise ValueError("family must be 'gaussian' or 'logistic'")

    def _inv_link(self, eta):
        return jax.nn.sigmoid(eta) if self.family == "logistic" else eta

    # ---------- linear predictor ----------
    @staticmethod
    def _linpred(alpha, beta, X_fixed):
        # eta = alpha + X β
        return alpha + (X_fixed @ beta)

    # ---------- grouped indices ----------
    @staticmethod
    def _group_indices(group_idx: jnp.ndarray):
        G = int(group_idx.max()) + 1
        ids = [(group_idx == g).nonzero()[0] for g in range(G)]
        return ids, G

    # ---------- per-observation loglik ----------
    @staticmethod
    def _log_cdf_diff_normal(z_u, z_l):
      # Numerically stable computation of log(Φ(z_u) - Φ(z_l))
      logFu = log_ndtr(z_u)
      logFl = log_ndtr(z_l)
      delta = logFl - logFu
      # Use log1p(-exp(delta)) for delta << 0, log(-expm1(delta)) for delta ~ 0
      log1mexp = jnp.where(
          delta < -1e-6,
          jnp.log1p(-jnp.exp(delta)),
          jnp.log(-jnp.expm1(delta))
      )
      return logFu + log1mexp

    @staticmethod
    def _tree_l2_norm(tree):
        leaves, _ = jax.tree_util.tree_flatten(tree)
        if not leaves:
            return 0.0
        return float(jnp.sqrt(sum([jnp.vdot(x, x) for x in leaves])))

    def _obs_loglik(self, eta_obs, b_obs, l, u, sigma):
        z = lambda y: (y - eta_obs - b_obs) / sigma

        is_point = jnp.isfinite(l) & jnp.isfinite(u) & (jnp.abs(u - l) <= 1e-12)
        is_left  = jnp.isfinite(l) & jnp.isinf(u)
        is_right = jnp.isinf(l) & jnp.isfinite(u)
        is_int   = ~(is_point | is_left | is_right)

        ll = jnp.zeros_like(l)

        # point: log φ((y-η-b)/σ) - log σ
        ll_point = jax.scipy.stats.norm.logpdf(l, loc=eta_obs + b_obs, scale=sigma)
        # Print ll_point values and input using jax debug
        ll = jnp.where(is_point, ll_point, ll)

        # left: log Φ((L-η-b)/σ)
        ll_left = log_ndtr(z(l))
        ll = jnp.where(is_left, ll_left, ll)

        # right: log(1 - Φ((U-η-b)/σ)) = log Φ(-(U-η-b)/σ)
        ll_right = log_ndtr(-z(u))
        ll = jnp.where(is_right, ll_right, ll)

        # interval: log(Φ(z_u) - Φ(z_l)) (stable)
        # ensure ordering on latent scale
        ll_int = self._log_cdf_diff_normal(z(u), z(l))
        ll = jnp.where(is_int, ll_int, ll)


        return ll

    # ---------- joint loglik (for Laplace path) ----------
    def _joint_loglik(self, params, l, u, X_fixed, group_idx):
        alpha, beta, b, log_sigma, log_tau = (
            params["alpha"], params["beta"], params["b"], params["log_sigma"], params["log_tau"]
        )
        sigma = jnp.exp(log_sigma)
        tau = jnp.exp(log_tau)

        eta_obs = self._linpred(alpha, beta, X_fixed)      # [n]
        b_obs = b[group_idx]                                # [n]
        ll = self._obs_loglik(eta_obs, b_obs, l, u, sigma).sum()

        # log density of b ~ N(0, tau^2) (drop constants)
        pen_b = -0.5 * jnp.sum((b / tau) ** 2) - b.size * jnp.log(tau)
        return ll + pen_b

    # ---------- Laplace objective ----------
    def _laplace_objective(self, params, l, u, X_fixed, group_idx):
        def loss_b(b_vec):
            p2 = params.copy(); p2["b"] = b_vec
            return -(self._joint_loglik(p2, l, u, X_fixed, group_idx))

        # inner: optimize b
        b = params["b"]
        opt_b = optax.adam(self.lr / 2)
        state_b = opt_b.init(b)
        for _ in range(60):
            g = jax.grad(loss_b)(b)
            updates, state_b = opt_b.update(g, state_b)
            b = optax.apply_updates(b, updates)
        params2 = params.copy(); params2["b"] = b

        # Laplace correction: -0.5 log|H_b|
        def joint_b_only(bv):
            p2 = params2.copy(); p2["b"] = bv
            return self._joint_loglik(p2, l, u, X_fixed, group_idx)

        H = jax.hessian(lambda bv: -joint_b_only(bv))(b)
        H = H + 1e-6 * jnp.eye(H.shape[0])
        _, logdet = jnp.linalg.slogdet(H)
        return -(joint_b_only(b) - 0.5 * logdet), params2

    # ---------- Monte Carlo (per group) ----------
    def _mc_objective(self, params, l, u, X_fixed, group_idx, rng):
        alpha, beta, log_sigma, log_tau = (
            params["alpha"], params["beta"], params["log_sigma"], params["log_tau"]
        )
        print([param for param in params.values()])
        sigma = jnp.exp(log_sigma)
        tau = jnp.exp(log_tau)
        eta_obs = self._linpred(alpha, beta, X_fixed)
        groups, G = self._group_indices(group_idx)

        jax.debug.print("Eta_obs: {x}", x=eta_obs)
        jax.debug.print("Sigma: {x}", x=sigma)
        jax.debug.print("Tau: {x}", x=tau)
        jax.debug.print("Groups: {x}", x=groups)

        total = 0.0
        for idx_i in groups:
            rng, sub = jax.random.split(rng)
            z = jax.random.normal(sub, shape=(self.n_mc,))  # z ~ N(0,1)
            b_s = tau * z                                   # b = τ z

            e = eta_obs[idx_i]      # (m,)
            l_i, u_i = l[idx_i], u[idx_i]

            log_terms = self._obs_loglik(e[None, :], b_s[:, None], l_i[None, :], u_i[None, :], sigma)

            loglik_s = jnp.sum(log_terms, axis=1)              # (S,)
            # log E_z[exp(ℓ_i(τ z))]
            log_int = jax.scipy.special.logsumexp(loglik_s) - jnp.log(self.n_mc)
            total = total + log_int

        return -total, rng

    # ---------- dispatcher ----------
    def _neg_marginal(self, params, l, u, X_fixed, group_idx):
        if self.integrator == "laplace":
            val, params_out = self._laplace_objective(params, l, u, X_fixed, group_idx)
            return val, params_out, self.rng
        # elif self.integrator == "aghq":
        #     val = self._aghq_objective(params, l, u, X_fixed, group_idx)
        #     return val, params, self.rng
        elif self.integrator == "mc":
            val, rng2 = self._mc_objective(params, l, u, X_fixed, group_idx, self.rng)
            return val, params, rng2
        else:
            raise ValueError("integrator must be 'laplace', 'aghq', or 'mc'")

    # ---------- fit ----------
    def fit(self, L, U, X_fixed, group_idx, verbose=False, log_every=1, abstol=1e-6):
        """
        Inputs
        ------
        L, U        : length-n interval bounds (for logistic family, in [0,1])
        X_fixed     : (n x p) fixed-effects design matrix (floats)
        group_idx   : length-n integer array, random-intercept group id per row
        verbose     : whether to print convergence statistics

        Returns
        -------
        FitResult with parameter estimates and (approximate) SEs.
        """
        if self.family == "logistic" and (jnp.any(jnp.abs(L) > 1) or jnp.any(jnp.abs(U) > 1)):
            raise ValueError("Observed values must be between 0 and 1 for logistic regression.")

        l, u = self._transform_bounds(L, U)
        X_fixed = jnp.asarray(X_fixed, dtype=jnp.float32)
        g = jnp.asarray(group_idx, dtype=jnp.int32)

        G = int(g.max()) + 1
        p = X_fixed.shape[1]

        params = {
            "alpha": jnp.array(0.0),
            "beta": jnp.zeros((p,)),
            "b": jnp.zeros((G,)),           # used by Laplace only
            "log_sigma": jnp.log(0.3),
            "log_tau": jnp.log(0.5),
        }

       
        opt = optax.adam(self.lr)
        state = opt.init(params)
        last = None

        # loss returns (value, aux) so we can carry Laplace mode & RNG
        def loss_fn(params, rng):
            val, params2, rng2 = self._neg_marginal(params, l, u, X_fixed, g)
            return val, (params2, rng2)

        # --- optimize ---
        for it in tqdm(range(self.maxiter)):
            (val, (params2, rng2)), grads = jax.value_and_grad(
                loss_fn, has_aux=True
            )(params, self.rng)

            jax.debug.print("Iteration {it}: params={params}", it=it, params=params)
            updates, state = opt.update(grads, state, params)
            jax.debug.print("Iteration {it}: updates={params}", it=it, params=updates)
            params = optax.apply_updates(params, updates)
            # Print updated params using jax.debug
            jax.debug.print("Iteration {it}: params={params}", it=it, params=params)

            # keep Laplace b-mode (no effect for AGHQ/MC)
            params["b"] = params2["b"]
            self.rng = rng2  # advance RNG once per iter (MC); OK

            # --- VERBOSE: collect and optionally print diagnostics ---
            sigma = float(jnp.exp(params["log_sigma"]))
            tau   = float(jnp.exp(params["log_tau"]))
            grad_norm = self._tree_l2_norm(grads)
            upd_norm  = self._tree_l2_norm(updates)

            record = {
                "iter": it,
                "loss": float(val),
                "sigma": sigma,
                "tau": tau,
                "grad_norm": grad_norm,
                "update_norm": upd_norm,
            }
            self.history_.append(record)

            if verbose and (it == 0 or (it + 1) % log_every == 0):
              print(
                f"[{it+1:5d}] loss={val: .6f}  |grad|={grad_norm: .3e}  "
                f"|upd|={upd_norm: .3e}  sigma={sigma: .4f}  tau={tau: .4f}  "
              )

            if last is not None and abs(val - last) < abstol:
                converged = True
                break
            last = val
        else:
            converged = False
            it = self.maxiter

        # --- Hessian → SEs (flatten once) ---
        # Use a fixed RNG snapshot so repeated calls are deterministic (esp. MC)
        rng_fixed = self.rng

        def neg_marginal_flat(flat_vec):
            # flatten/unflatten helpers
            flat0, unravel = jax.flatten_util.ravel_pytree(params)
            p2 = unravel(flat_vec)
            # don't change self.rng here; use a fixed local copy for stability
            val, _, _ = self._neg_marginal(p2, l, u, X_fixed, g)
            return val

        flat_opt, unravel = jax.flatten_util.ravel_pytree(params)
        H = jax.hessian(neg_marginal_flat)(flat_opt)
        H = H + 1e-6 * jnp.eye(H.shape[0])        # ridge for invertibility
        cov_flat = jnp.linalg.inv(H)
        se_flat = jnp.sqrt(jnp.diag(cov_flat))
        se_tree = unravel(se_flat)                 # map back to dict structure

        self.fitted_ = FitResult(
            params=params, se=se_tree, converged=converged, nit=it + 1, fun=float(val)
        )
        self._cache_ = (l, u, X_fixed, g)
        return self.fitted_

    # ---------- prediction ----------
    def predict(self, X_fixed_new):
        """
        Population-level predictions:
        - family='gaussian' -> predicted latent mean
        - family='logistic' -> predicted probability in [0,1]
        """
        assert self.fitted_ is not None
        alpha = self.fitted_.params["alpha"]
        beta = self.fitted_.params["beta"]
        Xn = jnp.asarray(X_fixed_new, dtype=jnp.float32)
        eta = self._linpred(alpha, beta, Xn)
        return self._inv_link(eta)
