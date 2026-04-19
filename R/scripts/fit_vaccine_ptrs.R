# fit_vaccine_ptrs_and_timeline.R — Fit GAMLSS model for vaccine PTRS.
#
# Fits an interval-censored Beta GAMLSS model of vaccine probability of technical
# success (PTRS) on pathogen + platform (fixed effects) + respondent (random effect).
# Marginal means are obtained via Gauss-Hermite quadrature over the respondent random
# effect, and uncertainty is propagated via cluster bootstrap (B = 1000).
# Also computes the prototype contrast (ΔPTRS per platform) as a post-estimation step.
#
# Inputs:  data/derived/vaccine_ptrs_responses.csv
# Outputs: data/derived/marginal_ptrs_preds.csv
#          data/clean/prototype_effect_preds.csv
#
# Run from the repository root.

library(forcats)
library(gamlss)
library(gamlss.dist)
library(gamlss.cens)
library(snakecase)
library(survival)
library(tidyverse)
library(statmod)

## --- Load and prep data -------------------------------------------------------
ptrs_raw <- read.csv("./data/derived/vaccine_ptrs_responses.csv")

ptrs_raw <- ptrs_raw %>%
  filter(!(is.na(value_min) | is.na(value_max))) %>%
  filter(platform %in% c("mrna_only", "traditional_only")) %>%
  mutate(
    across(c(value_min, value_max), ~ pmax(pmin(.x, 0.99), 0.01))
  ) %>%
  mutate(
    disease        = as.factor(disease),
    platform       = as.factor(platform),
    respondent     = as.factor(respondent),
    pathogen       = as.factor(pathogen),
    has_prototype  = as.factor(has_prototype),
    y = Surv(value_min, value_max, type = "interval2")
  )

## --- Register interval-censored GAMLSS families ------------------------------
# gen.cens() registers BEic — must be called before fitting.
gen.cens(BE, type = "interval")

## --- Helper functions ---------------------------------------------------------

build_predict_grid_and_X <- function(data, fixed_vars, random_var) {
  #' Build a prediction grid and fixed-effects design matrix for marginal inference.
  predict_grid <- do.call(
    expand.grid,
    c(lapply(fixed_vars, function(v) levels(data[[v]])), stringsAsFactors = FALSE)
  )
  names(predict_grid) <- fixed_vars
  predict_grid[[random_var]] <- levels(data[[random_var]])[1]
  X <- model.matrix(as.formula(paste("~", paste(fixed_vars, collapse = " + "))), data = predict_grid)
  list(predict_grid = predict_grid, X = X, n_cells = nrow(predict_grid))
}

relevel_like <- function(dat_b, dat_train, vars) {
  #' Relevel factor columns in a bootstrap sample to match the training data levels.
  for (v in vars) if (is.factor(dat_train[[v]]))
    dat_b[[v]] <- factor(dat_b[[v]], levels = levels(dat_train[[v]]))
  dat_b
}

boot_by_cluster <- function(data, cluster) {
  #' Cluster bootstrap: resample whole respondents and relabel duplicates as independent.
  sp <- split(data, data[[cluster]])
  ids <- names(sp)
  repeat {
    samp_ids <- sample(ids, length(ids), replace = TRUE)
    if (length(unique(samp_ids)) > 1L) break
  }
  out <- dplyr::bind_rows(sp[samp_ids])
  # give duplicates independent REs
  out$boot_copy <- rep(seq_along(samp_ids), vapply(sp[samp_ids], nrow, integer(1)))
  out[[cluster]] <- as.factor(
    interaction(out[[cluster]], out$boot_copy, drop = TRUE))
  out$boot_copy <- NULL
  out
}

## --- Gauss-Hermite quadrature setup ------------------------------------------
# Pre-compute nodes/weights once; reused inside each bootstrap iteration.
Q <- 32
gh <- gauss.quad.prob(Q, dist = "normal")
z  <- gh$nodes
w  <- gh$weights

## --- Model A: PTRS (Beta, interval-censored) ----------------------------------
## fixed = pathogen + platform; random = respondent
fixed_A   <- c("pathogen", "platform")
random_id <- "respondent"

fit_A <- gamlss(y ~ pathogen + platform + random(respondent),
                family = BEic, data = ptrs_raw, trace = FALSE)

prep_A <- build_predict_grid_and_X(ptrs_raw, fixed_A, random_id)
predict_grid_A <- prep_A$predict_grid
X_A            <- prep_A$X
nA             <- prep_A$n_cells

## Bootstrap settings
set.seed(123)
B_boot <- 1000
K_pred <- 500

## Cluster bootstrap containers
mu_boot_A <- matrix(NA_real_, nA, B_boot)                 # marginal means
Y_arr_A   <- array(NA_real_, dim = c(nA, K_pred, B_boot)) # predictive draws

for (b in 1:B_boot) {
  dat_b <- boot_by_cluster(ptrs_raw, random_id)
  dat_b <- relevel_like(dat_b, ptrs_raw, fixed_A)

  fit_b <- gamlss(y ~ pathogen + platform + random(respondent),
                  family = BEic, data = dat_b, trace = FALSE)

  beta_mu <- coef(fit_b, what = "mu")
  beta_mu <- beta_mu[colnames(X_A)]
  eta_fix <- as.numeric(X_A %*% beta_mu)

  sm_b <- getSmo(fit_b, what = "mu")
  sigma_b <- sm_b$sigb

  ## Marginal mean via GH over b ~ N(0, sigma_b^2)
  mu_nodes <- plogis(matrix(eta_fix, nA, Q) + rep(sigma_b * z, each = nA))
  mu_boot_A[, b] <- as.numeric(mu_nodes %*% w)

  ## Predictive draws (optional)
  sigma_x <- as.numeric(predict(fit_b, newdata = predict_grid_A, what = "sigma", type = "response"))
  node_id <- sample.int(Q, size = K_pred, replace = TRUE, prob = w)
  mu_cond <- plogis(matrix(eta_fix, nA, K_pred) + rep(sigma_b * z[node_id], each = nA))

  Y_arr_A[, , b] <- matrix(
    rBE(nA * K_pred, mu = as.vector(mu_cond), sigma = rep(sigma_x, K_pred)),
    nrow = nA, ncol = K_pred
  )
}

## Marginal summaries for pathogen × platform
ptrs_vf_marginal <- tibble(
  pathogen = predict_grid_A$pathogen,
  platform = predict_grid_A$platform,
  mu_hat   = rowMeans(mu_boot_A),
  se_mu    = apply(mu_boot_A, 1, sd),
  lo95     = apply(mu_boot_A, 1, quantile, 0.025),
  hi95     = apply(mu_boot_A, 1, quantile, 0.975)
)

ptrs_vf_predictive <- tibble(
  pathogen = predict_grid_A$pathogen,
  platform = predict_grid_A$platform,
  pred_mean = apply(Y_arr_A, 1, mean),
  pred_lo95 = apply(Y_arr_A, 1, function(v) quantile(v, 0.025)),
  pred_hi95 = apply(Y_arr_A, 1, function(v) quantile(v, 0.975))
)

## --- Prototype contrast (post-estimation from Model A) -----------------------
## Δ_k = mean_{v: proto=1} m_{v,k} − mean_{v: proto=0} m_{v,k}  for each platform k
# pathogen -> has_prototype map (assumes constant within pathogen)
proto_map <- ptrs_raw %>% distinct(pathogen, has_prototype)

grid_with_proto <- predict_grid_A %>%
  left_join(proto_map, by = "pathogen")

plat_lvls <- levels(ptrs_raw$platform)
hp_lvls   <- levels(ptrs_raw$has_prototype)
stopifnot(length(hp_lvls) >= 2)

rows_by_pk <- lapply(plat_lvls, function(k) {
  rows_k <- which(grid_with_proto$platform == k)
  i0 <- rows_k[grid_with_proto$has_prototype[rows_k] == hp_lvls[1]]
  i1 <- rows_k[grid_with_proto$has_prototype[rows_k] == hp_lvls[2]]
  list(platform = k, i0 = i0, i1 = i1)
})

delta_list <- lapply(rows_by_pk, function(s) {
  if (length(s$i0) == 0 || length(s$i1) == 0) return(rep(NA_real_, B_boot))
  m0 <- colMeans(mu_boot_A[s$i0, , drop = FALSE])  # avg over proto=0 families
  m1 <- colMeans(mu_boot_A[s$i1, , drop = FALSE])  # avg over proto=1 families
  m1 - m0
})

proto_effect_from_A <- tibble(
  platform    = sapply(rows_by_pk, `[[`, "platform"),
  effect_mean = sapply(delta_list, function(d) mean(d, na.rm = TRUE)),
  effect_lo95 = sapply(delta_list, function(d) quantile(d, 0.025, na.rm = TRUE)),
  effect_hi95 = sapply(delta_list, function(d) quantile(d, 0.975, na.rm = TRUE)),
  baseline    = sapply(rows_by_pk, function(s) if (length(s$i0)) mean(rowMeans(mu_boot_A[s$i0, , drop = FALSE])) else NA_real_),
  treated     = sapply(rows_by_pk, function(s) if (length(s$i1)) mean(rowMeans(mu_boot_A[s$i1, , drop = FALSE])) else NA_real_),
  rel_change  = (treated - baseline) / baseline
)


## --- Save outputs -------------------------------------------------------------
readr::write_csv(ptrs_vf_marginal, "data/derived/marginal_ptrs_preds.csv")
readr::write_csv(proto_effect_from_A, "data/clean/prototype_effect_preds.csv")
