# fit_vaccine_rd_costs.R — Fit GAMLSS model for vaccine R&D costs.
#
# Fits an interval-censored Gamma GAMLSS model of vaccine R&D costs on
# pathogen × prototype status (fixed) + respondent (random). Marginal means
# are obtained via the closed-form Gamma log-RE identity, and uncertainty is
# propagated via cluster bootstrap (B = 1000).
#
# Inputs:  data/derived/vaccine_rd_cost_responses.csv
# Outputs: data/derived/marginal_rd_costs_preds.csv
#
# Run from the repository root.

library(forcats)
library(gamlss)
library(gamlss.dist)
library(gamlss.cens)
library(readr)
library(snakecase)
library(survival)
library(tidyverse)
library(statmod)

## --- Load and prep data -------------------------------------------------------

rd_costs <- read_csv("./data/derived/vaccine_rd_cost_responses.csv")

rd_costs <- rd_costs %>%
  mutate(
    value_min = pmax(value_min, 0.01),
    respondent     = as.factor(respondent),
    pathogen       = as.factor(pathogen),
    has_prototype  = as.factor(has_prototype),
    y = Surv(value_min, value_max, type = "interval2")
  )

gen.cens(GA, type = "interval")

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

fixed_C   <- c("pathogen", "has_prototype")
random_id <- "respondent"

fit_C <- gamlss(y ~ pathogen + has_prototype + random(respondent),
                family = GAic, data = rd_costs, trace = FALSE)

prep_C <- build_predict_grid_and_X(rd_costs, fixed_C, random_id)
predict_grid_C <- prep_C$predict_grid
X_C            <- prep_C$X
nC             <- prep_C$n_cells

## --- Fit model and cluster bootstrap ------------------------------------------

## Bootstrap settings
set.seed(123)
B_boot <- 1000
K_pred <- 500


## Cluster bootstrap containers
mu_boot_C <- matrix(NA_real_, nC, B_boot)                 # marginal means
Y_arr_C   <- array(NA_real_, dim = c(nC, K_pred, B_boot)) # predictive draws

by_resp_C <- split(rd_costs, rd_costs[[random_id]])
resp_lvls <- levels(rd_costs[[random_id]])

warning_iterations <- integer(0)  # to store iterations with warnings
warning_bootstrap_datasets_C <- NULL

for (b in 1:B_boot) {
  warn_flag <- FALSE
  warn_handler <- function(w) {
    warn_flag <<- TRUE
    invokeRestart("muffleWarning")
  }

  dat_b <- boot_by_cluster(rd_costs, random_id)
  dat_b <- relevel_like(dat_b, rd_costs, fixed_C)

  fit_b <- withCallingHandlers(
    gamlss(y ~ pathogen + has_prototype + random(respondent),
           family = GAic,
           data = dat_b,
           trace = FALSE),
    warning = warn_handler
  )

  # Save only the bootstrap datasets with warnings, adding an identifier for easy loading/inspection
  if (warn_flag) {
    dat_b$bootstrap_id <- b
    if (is.null(warning_bootstrap_datasets_C)) {
      warning_bootstrap_datasets_C <- dat_b
    } else {
      warning_bootstrap_datasets_C <- dplyr::bind_rows(warning_bootstrap_datasets_C, dat_b)
    }
  }

  beta_mu <- coef(fit_b, what = "mu")
  beta_mu <- beta_mu[colnames(X_C)]
  eta_fix <- as.numeric(X_C %*% beta_mu)

  sm_b <- getSmo(fit_b, what = "mu")
  sigma_b <- sm_b$sigb

  ## Marginal mean via GH over b ~ N(0, sigma_b^2)
  mu_boot_C[, b] <- exp(eta_fix + 0.5 * sigma_b^2)

  ## Predictive draws (optional)
  sigma_x <- as.numeric(predict(fit_b, newdata = predict_grid_C, what = "sigma", type = "response"))
  node_id <- sample.int(Q, size = K_pred, replace = TRUE, prob = w)
  mu_cond <- exp(matrix(eta_fix, nC, K_pred) + rep(sigma_b * z[node_id], each = nC))

  Y_arr_C[, , b] <- matrix(
    rGA(nC * K_pred, mu = as.vector(mu_cond), sigma = rep(sigma_x, K_pred)),
    nrow = nC, ncol = K_pred
  )
}

rd_costs_marginal <- tibble(
  pathogen = predict_grid_C$pathogen,
  has_prototype = predict_grid_C$has_prototype,
  mu_hat = rowMeans(mu_boot_C),
  se_mu = apply(mu_boot_C, 1, sd),
  lo95 = apply(mu_boot_C, 1, quantile, 0.025),
  hi95 = apply(mu_boot_C, 1, quantile, 0.975)
)

write_csv(rd_costs_marginal, "data/derived/marginal_rd_costs_preds.csv")
