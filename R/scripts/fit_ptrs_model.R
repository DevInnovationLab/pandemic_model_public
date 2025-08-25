library(gamlss)
library(gamlss.dist)
library(gamlss.cens)
library(here)
library(tidyverse)
library(survival)
library(tibble)

ptrs_raw <- read.csv("../data/clean/vaccine_ptrs.csv")

ptrs_raw <- ptrs_raw %>%
  filter(!(is.na(value_min) | is.na(value_max))) %>%
  filter(platform %in% c("mrna_only", "traditional_only")) %>%
  mutate(
    across(c(value_min, value_max), ~ pmax(pmin(.x, 0.99), 0.01))
  ) %>%
  mutate(
    disease = as.factor(disease),
    platform = as.factor(platform),
    respondent = as.factor(respondent),
    pathogen = as.factor(pathogen),
    has_prototype = as.factor(has_prototype),
    y = Surv(value_min, value_max, type = "interval2")
  )

rd_timelines <- read.csv("../data/clean/vaccine_rd_timelines.csv")

rd_timelines <- rd_timelines |>
  rename(value_min = years_min, value_max = years_max) |>
  mutate(across(c(value_min, value_max), ~ pmax(.x, 0.01))) %>%
  mutate(
    disease = as.factor(disease),
    has_prototype = as.factor(has_prototype),
    respondent = as.factor(respondent),
    pathogen = as.factor(pathogen),
    y = Surv(value_min, value_max, type = "interval2")
  )

# We will use a lognormal for RD timelines, and Beta for PTRS



##
## prepare_grid_and_mm
##
## Build the prediction grid over fixed effects, attach a placeholder level for
## the random effect, and construct the fixed-effects model matrix for the μ submodel.
##
## Parameters
## - data: A data.frame with factors already set for fixed and random variables.
## - fixed_vars: Character vector of fixed-effect variable names to cross.
## - random_var: Character scalar name of the random-effect factor (for placeholder).
##
## Returns
## - A list with elements: grid (data.frame), X_mu (matrix), n_cells (integer).
prepare_grid_and_mm <- function(data, fixed_vars, random_var) {
  stopifnot(is.data.frame(data))
  stopifnot(length(fixed_vars) >= 1)
  stopifnot(length(random_var) == 1)

  # Build grid of fixed effects using training levels
  grid <- do.call(
    expand.grid,
    c(lapply(fixed_vars, function(v) levels(data[[v]])), stringsAsFactors = FALSE)
  )
  names(grid) <- fixed_vars

  # Add placeholder respondent level so predict() can evaluate sigma later
  grid[[random_var]] <- levels(data[[random_var]])[1]

  # Fixed-effects model matrix for μ using formula from fixed_vars
  form_fix <- as.formula(paste("~", paste(fixed_vars, collapse = " + ")))
  X_mu <- model.matrix(form_fix, data = grid)
  n_cells <- nrow(grid)

  list(grid = grid, X_mu = X_mu, n_cells = n_cells)
}

##
## fit_gamlss_mixed
##
## Fit a GAMLSS with specified fixed effects and a random intercept.
##
## Parameters
## - data: A data.frame containing the response and covariates.
## - response: Name of the response column (can be Surv for censored families).
## - fixed_vars: Character vector of fixed-effect variable names.
## - random_var: Character scalar for the random intercept factor.
## - family: A GAMLSS family object (e.g., BEic).
## - trace: Logical; show fit trace.
##
## Returns
## - A fitted gamlss object.
fit_gamlss_mixed <- function(data, response, fixed_vars, random_var, family, trace = FALSE) {
  stopifnot(all(c(response, fixed_vars, random_var) %in% names(data)))

  form <- as.formula(
    paste(response, "~", paste(fixed_vars, collapse = " + "), "+", paste0("random(", random_var, ")"))
  )

  gamlss(formula = form, family = family, data = data, trace = trace)
}

##
## bootstrap_predictive
##
## Run a cluster bootstrap over the random-effect units, refit the model, and
## produce both marginal mean summaries (integrating out the random effect) and
## predictive draws that combine parameter and aleatoric uncertainty.
##
## Parameters
## - data: Training data.frame with factors set and a response column.
## - response: Name of the response column.
## - fixed_vars: Character vector of fixed-effect variable names.
## - random_var: Character scalar for the random intercept factor.
## - family: A GAMLSS family object (e.g., BEic).
## - B_boot: Number of bootstrap replicates.
## - K_pred: Number of predictive draws per bootstrap per cell.
## - seed: RNG seed for reproducibility.
##
## Returns
## - A list with elements: boot_summ (tibble), pred_summ (tibble), mu_boot (matrix), Y_arr (array).
bootstrap_predictive <- function(data, response, fixed_vars, random_var, family,
                                 B_boot = 200, K_pred = 200, seed = 123) {
  stopifnot(is.data.frame(data))
  stopifnot(all(c(response, fixed_vars, random_var) %in% names(data)))
  stopifnot(is.factor(data[[random_var]]))

  set.seed(seed)

  # Prepare grid and model matrix
  prep <- prepare_grid_and_mm(data, fixed_vars, random_var)
  grid <- prep$grid
  X_mu <- prep$X_mu
  n_cells <- prep$n_cells

  # Cluster bootstrap setup
  re_levels <- levels(data[[random_var]])
  by_re <- split(data, data[[random_var]])

  # Storage
  mu_boot <- matrix(NA_real_, n_cells, B_boot)
  Y_arr   <- array(NA_real_, dim = c(n_cells, K_pred, B_boot))

  for (b in 1:B_boot) {
    # Resample clusters
    samp_ids <- sample(re_levels, length(re_levels), replace = TRUE)
    dat_b <- dplyr::bind_rows(by_re[samp_ids])

    # Refit model
    fit_b <- fit_gamlss_mixed(dat_b, response, fixed_vars, random_var, family, trace = FALSE)

    # Fixed part on link scale via model matrix
    beta_mu <- coef(fit_b, what = "mu")
    beta_mu <- beta_mu[colnames(X_mu)]
    eta_fix_b <- as.numeric(X_mu %*% beta_mu)

    # Random-intercept SD from μ submodel
    sm_mu_b <- getSmo(fit_b, what = "mu")
    sigma_b <- sm_mu_b$sigb

    # Marginal mean integrating out random intercept
    b_int <- rnorm(2000, 0, sigma_b)
    mu_boot[, b] <- rowMeans(plogis(outer(eta_fix_b, b_int, `+`)))

    # Predictive draws: need sigma(x) on response scale per cell
    sigma_x <- as.numeric(predict(fit_b, newdata = grid, what = "sigma", type = "response"))

    # New-respondent intercept draws
    b_new <- rnorm(K_pred, 0, sigma_b)
    mu_cond <- plogis(matrix(eta_fix_b, n_cells, K_pred) + rep(b_new, each = n_cells))

    # Vectorized Beta draws and reshape
    Y_arr[ , , b] <- matrix(
      rBE(n_cells * K_pred, mu = as.vector(mu_cond), sigma = rep(sigma_x, K_pred)),
      nrow = n_cells, ncol = K_pred
    )
  }

  # Summaries (90% intervals by default)
  boot_summ <- tibble(
    !!!setNames(lapply(fixed_vars, function(v) grid[[v]]), fixed_vars),
    mu_hat = rowMeans(mu_boot),
    se_mu  = apply(mu_boot, 1, sd),
    lo90   = apply(mu_boot, 1, quantile, 0.05),
    hi90   = apply(mu_boot, 1, quantile, 0.95)
  )

  pred_mean <- apply(Y_arr, 1, mean)
  pred_lo90 <- apply(Y_arr, 1, function(v) quantile(v, 0.05))
  pred_hi90 <- apply(Y_arr, 1, function(v) quantile(v, 0.95))
  pred_summ <- tibble(
    !!!setNames(lapply(fixed_vars, function(v) grid[[v]]), fixed_vars),
    pred_mean = pred_mean,
    pred_lo90 = pred_lo90,
    pred_hi90 = pred_hi90
  )

  list(boot_summ = boot_summ, pred_summ = pred_summ, mu_boot = mu_boot, Y_arr = Y_arr)
}

gen.cens(BEINF, type = "interval")
gen.cens(BE, type = "interval")

## Example usage on ptrs_raw
fixed_vars <- c("pathogen", "platform")
random_var <- "respondent"

# Fit once if needed elsewhere
fit <- fit_gamlss_mixed(ptrs_raw, response = "y", fixed_vars = fixed_vars,
                        random_var = random_var, family = BEic, trace = FALSE)

# Run bootstrap predictive simulation
boot_out <- bootstrap_predictive(ptrs_raw, response = "y", fixed_vars = fixed_vars,
                                 random_var = random_var, family = BEic,
                                 B_boot = 200, K_pred = 1000, seed = 123)

boot_summ <- boot_out$boot_summ
pred_summ <- boot_out$pred_summ
