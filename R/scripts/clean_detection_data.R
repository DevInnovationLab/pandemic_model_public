library(ggplot2)
library(here)
library(janitor)
library(readr)
library(snakecase)
library(tidyverse)

detection_raw <- read_csv(here("data", "raw", "hashimoto_2000_epidemics_detection.csv"))

detection_cross_section <- detection_raw |>
  clean_names() |>
  rename(recall = se_percent, precision = ppv_percent) |>
  select(-sp_percent) |>
  mutate(across(c(precision, recall), ~ .x / 100),
         disease = to_snake_case(disease)) |>
  select(c(disease, critical_value, precision, recall))

# Just looking at the cross-section for now

# Pivot detection_cross_section to long format for precision and recall
detection_cross_section_long <- detection_cross_section |>
  pivot_longer(
    cols = c(precision, recall),
    names_to = "metric",
    values_to = "value"
  ) %>%
  mutate(disease = as.factor(disease))

# Facet plot: critical_value vs value (precision/recall), one facet per metric, with regression lines
# Use separate linear models for each metric, and include disease as a fixed effect

# Fit separate regressions for each metric with disease as fixed effect,
# predict values for plotting, and then plot with ggplot2.

library(broom)
library(lme4)
library(broom.mixed)
library(glmmTMB)

# Fit models (linear, beta, and logistic regression) by metric with disease as random effect
fits_long <- detection_cross_section_long |>
  group_by(metric) |>
  group_modify(~ {
    # Linear mixed model
    lmm <- lmer(value ~ critical_value + (1 | disease), data = .x)
    .x$lmm_fitted <- predict(lmm, newdata = .x, re.form = NA)
    
    # Beta regression mixed model
    beta <- glmmTMB(value ~ critical_value + (1 | disease), data = .x, family = beta_family())
    .x$beta_fitted <- predict(beta, newdata = .x, re.form = NA, type = "response")

    # Logistic mixed model (proportion as response)
    logit <- suppressWarnings(
      glmer(value ~ critical_value + (1 | disease), data = .x, family = binomial(link = "logit"))
    )
    .x$logit_fitted <- predict(logit, newdata = .x, re.form = NA, type = "response")

    .x
  }) |>
  ungroup()

# Plot all fits together on the same facets, including logistic
plot_fits <- ggplot(fits_long, aes(x = critical_value, y = value)) +
  geom_point(aes(color = disease), alpha = 0.6) +
  geom_line(aes(y = lmm_fitted), color = "blue", size = 1.1, linetype = "solid", show.legend = FALSE) +
  geom_line(aes(y = beta_fitted), color = "darkgreen", size = 1.1, linetype = "dashed", show.legend = FALSE) +
  geom_line(aes(y = logit_fitted), color = "red", size = 1.1, linetype = "dotdash", show.legend = FALSE) +
  facet_wrap(
    ~ metric,
    nrow = 2,
    scales = "free_y",
    labeller = as_labeller(
      c(
        precision = "Precision",
        recall = "Recall"
      )
    )
  ) +
  labs(
    title = "Precision/recall vs case detection threshold",
    subtitle = paste(
      "Solid blue = Linear mixed model\n",
      "Dashed green = Beta regression mixed model\n",
      "Dotdash red = Logistic mixed model"
    ),
    x = "Case detection threshold (cases per week)",
    y = "Metric value",
    color = "Disease"
  ) +
  ylim(0, 1) +
  theme_minimal(base_size = 16) +
  theme(
    strip.text = element_text(size = 18, face = "bold"),
    plot.title = element_text(size = 22, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 14),  # make subtitle clear and readable
    axis.title.x = element_text(size = 18, face = "bold"),
    axis.title.y = element_text(size = 18, face = "bold"),
    axis.text = element_text(size = 14)
  )

print(plot_fits)





detection_time_series <- detection_raw |>
  clean_names() |>
  select(-c(se_percent, sp_percent, ppv_percent)) |>
  rename_with(~ str_replace(.x, "before", "precision"), contains("before")) |>
  mutate(across(contains("precision"), ~ .x / 100)) |>
  pivot_longer(starts_with("precision"),
               names_to = "weeks_before",
               values_to = "precision",
               names_pattern = "precision_(\\d)w*")

# Facet plot: critical vs precision over different weeks
# Ensure weeks_before is treated as a factor for plotting
detection_time_series <- detection_time_series |>
  mutate(weeks_before = factor(weeks_before, levels=sort(unique(weeks_before))))

# Facet plot: critical vs precision over weeks (1 plot per week)
p_facet <- ggplot(detection_time_series, aes(x = critical_value, y = precision)) +
  geom_point() +
  geom_smooth(method = "glm", method.args = list(family = "binomial"), se = FALSE, color = "blue") +
  facet_wrap(~ weeks_before) +
  labs(
    title = "Critical value vs precision across weeks before outbreak (Logistic fit)",
    x = "Critical value (average cases per week)",
    y = "Precision"
  ) +
  theme_minimal()

print(p_facet)

# Combined plot: all weeks on one, colored by week with fit lines
p_combined <- ggplot(detection_time_series, aes(x = critical_value, y = precision, color = weeks_before)) +
  geom_point() +
  geom_smooth(method = "glm", method.args = list(family = "binomial"), se = FALSE) +
  labs(
    title = "Critical value vs precision across weeks before outbreak (Logistic fit)",
    x = "Critical value (average cases per week)",
    y = "Precision",
    color = "Weeks Before"
  ) +
  theme_minimal()

print(p_combined)

# Ensure disease and weeks_before are factors
detection_time_series <- detection_time_series |>
  mutate(
    disease = factor(disease),
    weeks_before = factor(weeks_before, levels = sort(unique(weeks_before)))
  )

# Fit a logistic regression: use glm with binomial family
# Precision values are in (0,1); we model mean precision with logit link
logistic_model <- glm(precision ~ weeks_before * critical_value + weeks_before * disease,
                      data = detection_time_series,
                      family = binomial(link = "logit"),
                      weights = rep(100, nrow(detection_time_series))) # optional: upweight if precision comes from %s

# Make prediction grid over all weeks_before, diseases, and critical_value range
crit_range <- seq(
  min(detection_time_series$critical_value, na.rm = TRUE),
  max(detection_time_series$critical_value, na.rm = TRUE),
  length.out = 100
)

all_diseases <- levels(detection_time_series$disease)
if (is.null(all_diseases)) all_diseases <- unique(detection_time_series$disease)

predict_grid <- expand.grid(
  critical_value = crit_range,
  weeks_before = levels(detection_time_series$weeks_before),
  disease = all_diseases,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)

# Get predictions for all (critical_value, weeks_before, disease) on probability scale
predict_grid$precision_pred <- predict(logistic_model, newdata = predict_grid, type = "response")

# Average over diseases to get expected prediction for each (critical_value, weeks_before)
predict_grid_avg <- predict_grid |>
  group_by(critical_value, weeks_before) |>
  summarize(precision_pred = mean(precision_pred, na.rm = TRUE), .groups = "drop")

# Plot predictions across critical values for four weeks (averaged over diseases)
p_regression <- ggplot(predict_grid_avg, aes(x = critical_value, y = precision_pred, color = weeks_before)) +
  geom_line(size = 1.2) +
  labs(
    title = "Logistic regression-predicted (avg across diseases) precision vs critical value\n(Four weeks)",
    x = "Critical value",
    y = "Predicted Precision (Averaged)",
    color = "Weeks Before"
  ) +
  theme_minimal()

print(p_regression)

