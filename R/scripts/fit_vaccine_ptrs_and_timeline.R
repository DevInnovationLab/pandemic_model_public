library(forcats)
library(ggplot2)
library(gamlss)
library(gamlss.dist)
library(gamlss.cens)
library(snakecase)
library(survival)
library(tidyverse)
library(statmod)

## --- Load and prep relevant data
ptrs_raw <- read.csv("./data/clean/vaccine_ptrs.csv")

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

rd_timelines <- read.csv("./data/clean/vaccine_rd_timelines.csv")

rd_timelines <- rd_timelines |>
  rename(value_min = years_min, value_max = years_max) |>
  mutate(across(c(value_min, value_max), ~ pmax(.x, 0.5))) %>%
  mutate(
    disease        = as.factor(disease),
    has_prototype  = as.factor(has_prototype),
    respondent     = as.factor(respondent),
    pathogen       = as.factor(pathogen),
    y = Surv(value_min, value_max, type = "interval2")
  )

## -- Families with interval censoring (creates BEic, LOGNOic, etc.)
gen.cens(BE,    type = "interval")
gen.cens(LOGNO, type = "interval")
gen.cens(GA, type = "interval")

## -- Helper: build prediction grid and fixed-effects model matrix
build_predict_grid_and_X <- function(data, fixed_vars, random_var) {
  predict_grid <- do.call(
    expand.grid,
    c(lapply(fixed_vars, function(v) levels(data[[v]])), stringsAsFactors = FALSE)
  )
  names(predict_grid) <- fixed_vars
  predict_grid[[random_var]] <- levels(data[[random_var]])[1]
  X <- model.matrix(as.formula(paste("~", paste(fixed_vars, collapse = " + "))), data = predict_grid)
  list(predict_grid = predict_grid, X = X, n_cells = nrow(predict_grid))
}

## -- Helper: relevel bootstrap sample to training levels
relevel_like <- function(dat_b, dat_train, vars) {
  for (v in vars) if (is.factor(dat_train[[v]]))
    dat_b[[v]] <- factor(dat_b[[v]], levels = levels(dat_train[[v]]))
  dat_b
}

## -- helper to avoid treating resampled observations under bootstrap as same respodent
boot_by_cluster <- function(data, cluster) {
  sp <- split(data, data[[cluster]])
  ids <- names(sp)
  samp_ids <- sample(ids, length(ids), replace = TRUE)
  out <- dplyr::bind_rows(sp[samp_ids])
  # give duplicates independent REs
  out$boot_copy <- rep(seq_along(samp_ids), vapply(sp[samp_ids], nrow, integer(1)))
  out[[cluster]] <- as.factor(
    interaction(out[[cluster]], out$boot_copy, drop = TRUE))
  out$boot_copy <- NULL
  out
}

## -- Gauss–Hermite nodes/weights once
Q <- 32
gh <- gauss.quad.prob(Q, dist = "normal")
z  <- gh$nodes
w  <- gh$weights

## -------------------------
## Model A (Option 3): PTRS (Beta), fixed = pathogen + platform
## -------------------------
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
B_boot <- 400
K_pred <- 500

## Cluster bootstrap containers
mu_boot_A <- matrix(NA_real_, nA, B_boot)                 # marginal means
Y_arr_A   <- array(NA_real_, dim = c(nA, K_pred, B_boot)) # predictive draws

by_resp_A <- split(ptrs_raw, ptrs_raw[[random_id]])
resp_lvls <- levels(ptrs_raw[[random_id]])

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

## -------------------------
## Prototype contrast (post-estimation, from Model A)
## Δ_k = average_v∈proto1 m_{v,k} − average_v∈proto0 m_{v,k}
## -------------------------
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

## -------------------------
## Model C: R&D timelines (Lognormal), fixed = available among {pathogen, platform, has_prototype}
## -------------------------
fixed_C <- "pathogen"  # keep as in your current script; extend if you like

fit_C <- gamlss(y ~ pathogen + random(respondent),
                family = GAic,        # <- Gamma, interval-censored
                data = rd_timelines,
                trace = FALSE)

prep_C <- build_predict_grid_and_X(rd_timelines, fixed_C, random_id)
predict_grid_C <- prep_C$predict_grid
X_C            <- prep_C$X
nC             <- prep_C$n_cells

mu_boot_C <- matrix(NA_real_, nC, B_boot)
Y_arr_C   <- array(NA_real_, dim = c(nC, K_pred, B_boot))

warning_iterations <- integer(0)  # to store iterations with warnings

for (b in 1:B_boot) {
  warn_flag <- FALSE
  warn_handler <- function(w) {
    warn_flag <<- TRUE
    invokeRestart("muffleWarning")
  }
  
  # cluster bootstrap with relabeled duplicates (your helper does this)
  dat_b <- boot_by_cluster(rd_timelines, random_id)
  dat_b <- relevel_like(dat_b, rd_timelines, fixed_C)
  
  fit_b <- withCallingHandlers(
    gamlss(y ~ pathogen + random(respondent),
           family = GAic,
           data = dat_b,
           trace = FALSE),
    warning = warn_handler
  )

  # Save only the bootstrap datasets with warnings, adding an identifier for easy loading/inspection
  if (warn_flag) {
    dat_b$bootstrap_id <- b
    if (!exists("warning_bootstrap_datasets_C")) {
      warning_bootstrap_datasets_C <- dat_b
    } else {
      warning_bootstrap_datasets_C <- dplyr::bind_rows(warning_bootstrap_datasets_C, dat_b)
    }
  }
  
  # fixed log-mean for each prediction cell
  beta_mu <- coef(fit_b, what = "mu")
  beta_mu <- beta_mu[colnames(X_C)]
  eta_fix <- as.numeric(X_C %*% beta_mu)   # log(mu) without random effect

  # respondent RE SD on the mu submodel (log scale)
  sm_b    <- getSmo(fit_b, what = "mu")
  sigma_b <- sm_b$sigb

  # Gamma dispersion (CV) on response scale per cell (can vary with covars if modeled)
  sigma_x <- as.numeric(predict(fit_b, newdata = predict_grid_C, what = "sigma", type = "response"))

  ## ---- Marginal mean (closed form for Gamma with log-RE):
  ## E[T | v] = exp(eta_fix + 0.5 * sigma_b^2)
  mu_boot_C[, b] <- exp(eta_fix + 0.5 * sigma_b^2)

  ## ---- Predictive draws: mixture of Gammas over b ~ N(0, sigma_b^2)
  node_id <- sample.int(Q, size = K_pred, replace = TRUE, prob = w)  # (or just rnorm K_pred if you prefer MC)
  b_new   <- z[node_id] * sigma_b
  mu_cond <- exp(matrix(eta_fix, nC, K_pred) + rep(b_new, each = nC))

  Y_arr_C[, , b] <- matrix(
    rGA(nC * K_pred, mu = as.vector(mu_cond), sigma = rep(sigma_x, K_pred)),
    nrow = nC, ncol = K_pred
  )
}

if (length(warning_iterations) > 0) {
  message("Warnings occurred in the following bootstrap iterations: ", paste(warning_iterations, collapse = ", "))
} else {
  message("No warnings occurred during bootstrap iterations.")
}

rd_marginal <- tibble(
  pathogen = predict_grid_C$pathogen,
  mean_hat = rowMeans(mu_boot_C),
  se_mean  = apply(mu_boot_C, 1, sd),
  lo95     = apply(mu_boot_C, 1, quantile, 0.025),
  hi95     = apply(mu_boot_C, 1, quantile, 0.975)
)

rd_predictive <- tibble(
  pathogen = predict_grid_C$pathogen,
  pred_mean = apply(Y_arr_C, 1, mean),
  pred_lo95 = apply(Y_arr_C, 1, function(v) quantile(v, 0.025)),
  pred_hi95 = apply(Y_arr_C, 1, function(v) quantile(v, 0.975))
)

# Save the marginal PTRS dataset as CSV
readr::write_csv(ptrs_vf_marginal, "output/ptrs/marginal_ptrs_preds.csv")
readr::write_csv(rd_marginal, "output/rd_timelines/marginal_timeline_preds.csv")
readr::write_csv(proto_effect_from_A, "output/ptrs/prototype_effect_preds.csv")
