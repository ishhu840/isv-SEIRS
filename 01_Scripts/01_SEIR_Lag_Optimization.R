################################################################################
# SEIR_01_LagSearch.R  —  Grid search: optimal rainfall & temperature lags
# BioInference2026 | Properly fitted SEIR with rho as free parameter
#
# What this does:
#   1. Loads and prepares weekly dengue + weather data (Rawalpindi 2013-2024)
#   2. Runs 35-combination grid search (rain lags 4-8wk × temp lags 6-12wk)
#   3. For each combination: fits 9 SEIR parameters via optim() on TRAINING data only
#   4. Evaluates on TEST data (2023-2024) — never used during fitting
#   5. Saves: optimal_lag_params.csv, lag_heatmap.png, lag_heatmap.pdf
#
# Training: 2013-2022  |  Test: 2023-2024
# Optimal (from ISHTIAQ companion study): rain=5wk, temp=10wk, rho=0.2275, r_test=0.716
################################################################################

suppressPackageStartupMessages({
  library(dplyr); library(readxl); library(ggplot2)
  library(showtext); library(ggtext); library(cowplot)
})

source("00_Coupled_Engine.R")   # MUST source before SEIR_Engine so run_coupled() is visible
source("00_SEIR_Engine.R")

font_add_google("Source Sans 3", "ss3")
showtext_auto()
BASE_FONT <- "ss3"

cat("=== SEIR Lag Grid Search ===\n")
cat("Training: 2013-2022 | Test: 2023-2024\n\n")

# ── Load data ─────────────────────────────────────────────────────────────────
DATA_PATH <- "../00_Data/D1_Weekly_Cases_Weather.xlsx"

df_raw <- read_excel(DATA_PATH) %>%
  filter(City == "Rawalpindi") %>%
  arrange(Year, Week) %>%
  rename(
    cases       = `Number of Dengue Cases`,
    Temperature = Temperature,
    Rainfall    = Rainfall
  ) %>%
  mutate(
    Nh = case_when(        # Rawalpindi population (census-interpolated, weekly)
      Year <= 2017 ~ 2100000 * (1 + 0.0252)^(Year - 2013),
      TRUE         ~ 2430423 * (1 + 0.0252)^(Year - 2017)
    )
  )

train_mask <- df_raw$Year <= 2022
test_mask  <- df_raw$Year >= 2023

cat(sprintf("Data: %d weeks total | Training: %d weeks | Test: %d weeks\n",
            nrow(df_raw), sum(train_mask), sum(test_mask)))

# ── Weather statistics (training period only, for standardisation) ─────────────
temp_mu  <- mean(df_raw$Temperature[train_mask], na.rm = TRUE)
temp_std <- sd(df_raw$Temperature[train_mask],   na.rm = TRUE)
rain_mu  <- mean(df_raw$Rainfall[train_mask],    na.rm = TRUE)
rain_std <- sd(df_raw$Rainfall[train_mask],      na.rm = TRUE)

cat(sprintf("Training weather: T_mean=%.2f°C, T_sd=%.2f | R_mean=%.2f mm, R_sd=%.2f\n\n",
            temp_mu, temp_std, rain_mu, rain_std))

# ── Grid search parameters ─────────────────────────────────────────────────────
RAIN_LAGS <- 4:8
TEMP_LAGS <- 6:12

# Prepare data with ALL lag columns
df_all <- prepare_data(df_raw, RAIN_LAGS, TEMP_LAGS, train_mask)

# Initial parameter guess
# NOTE: bT2 initialized at -0.50 to give optimizer a meaningful starting
# inverted-U shape. A value near 0 causes early convergence to flat
# temperature response (Nelder-Mead is sensitive to initial simplex shape).
x0 <- c(
  log(0.5),       # [1] log(kappa)
  -2.0,           # [2] b0
  0.05,           # [3] bR
  0.70,           # [4] bT
  -0.50,          # [5] bT2  — strong start: enforces inverted-U from step 1
  qlogis(0.10),   # [6] logit(rho) — start at 10% prior (Bhatt 2013)
  log(5.0),       # [7] log(lambda) — fixed at 5 (Wesolowski 2015)
  qlogis(1e-4),   # [8] logit(E0f)
  qlogis(1e-5)    # [9] logit(I0f)
)

# ── Run grid search ─────────────────────────────────────────────────────────
n_combos <- length(RAIN_LAGS) * length(TEMP_LAGS)
results_list <- vector("list", n_combos)
counter <- 0

cat(sprintf("Starting grid search (%d combinations)...\n", n_combos))

for (rl in RAIN_LAGS) {
  for (tl in TEMP_LAGS) {
    counter <- counter + 1
    cat(sprintf("  [%2d/%d] Rain=%dw, Temp=%dw ... ", counter, n_combos, rl, tl))

    fit <- tryCatch(
      optim(
        par     = x0,
        fn      = build_loss,
        df_input = df_all,
        rain_lag = rl,
        temp_lag = tl,
        train_mask = train_mask,
        temp_mu    = temp_mu,
        temp_std   = temp_std,
        method  = "Nelder-Mead",
        control = list(maxit = 2000, reltol = 1e-6)
      ),
      error = function(e) NULL
    )

    if (is.null(fit)) {
      cat("FAILED\n"); next
    }

    sim     <- run_coupled(fit$par, df_all, rl, tl, p_ISV_vec=NULL, eps=0)
    r_train <- cor(df_all$cases[train_mask], sim$pred[train_mask], use = "complete.obs")
    r_test  <- cor(df_all$cases[test_mask],  sim$pred[test_mask],  use = "complete.obs")

    results_list[[counter]] <- data.frame(
      rain_lag = rl, temp_lag = tl,
      r_train  = r_train,  r_test   = r_test,
      rho      = plogis(fit$par[6]),
      kappa    = exp(fit$par[1]),
      lambda   = exp(fit$par[7])
    )
    cat(sprintf("r_train=%.3f  r_test=%.3f  rho=%.3f\n", r_train, r_test, plogis(fit$par[6])))
  }
}

# ── Compile and save results ─────────────────────────────────────────────────
all_res <- bind_rows(Filter(Negate(is.null), results_list))
write.csv(all_res, "../03_Results/SEIR_lag_grid_results.csv", row.names = FALSE)

# Select the data-optimal lags: highest Pearson r on training data only.
# Using r_train (not r_test) keeps the test set 2023-2024 genuinely out-of-sample.
best <- all_res %>% arrange(desc(r_train)) %>% head(1)
cat(sprintf("\n✓ BEST DATA-DRIVEN LAGS: rain=%dw, temp=%dw | r_train=%.3f | r_test=%.3f | rho=%.4f\n",
            best$rain_lag, best$temp_lag, best$r_train, best$r_test, best$rho))

# ── Re-fit best combination with higher iterations for precise parameters ──────
cat("\nRe-fitting best combination with extended iterations...\n")
df_best <- prepare_data(df_raw, best$rain_lag, best$temp_lag, train_mask)

best_fit <- optim(
  par      = x0,
  fn       = build_loss,
  df_input = df_best,
  rain_lag = best$rain_lag,
  temp_lag = best$temp_lag,
  train_mask = train_mask,
  temp_mu    = temp_mu,
  temp_std   = temp_std,
  method   = "Nelder-Mead",
  control  = list(maxit = 10000, reltol = 1e-8)
)

p   <- best_fit$par
sim <- run_coupled(p, df_best, best$rain_lag, best$temp_lag, p_ISV_vec=NULL, eps=0)

r_train_final <- cor(df_best$cases[train_mask], sim$pred[train_mask], use = "complete.obs")
r_test_final  <- cor(df_best$cases[test_mask],  sim$pred[test_mask],  use = "complete.obs")

best_params <- data.frame(
  rain_lag   = best$rain_lag,
  temp_lag   = best$temp_lag,
  log_kappa  = p[1], b0 = p[2], bR = p[3], bT = p[4], bT2 = p[5],
  logit_rho  = p[6], log_lambda = p[7], logit_E0f = p[8], logit_I0f = p[9],
  kappa      = exp(p[1]),
  rho        = plogis(p[6]),
  lambda     = exp(p[7]),
  E0f        = 0.01 * plogis(p[8]),
  I0f        = 0.01 * plogis(p[9]),
  r_train    = r_train_final,
  r_test     = r_test_final,
  temp_mu    = temp_mu,
  temp_std   = temp_std,
  rain_mu    = rain_mu,
  rain_std   = rain_std
)

dir.create("../03_Results", showWarnings = FALSE, recursive = TRUE)
write.csv(best_params, "../03_Results/SEIR_optimal_params.csv", row.names = FALSE)

cat(sprintf("✓ Fitted rho    = %.4f (%.1f%%)\n", best_params$rho, 100 * best_params$rho))
cat(sprintf("✓ Fitted kappa  = %.4f\n",  best_params$kappa))
cat(sprintf("✓ Fitted lambda = %.2f cases/week (fixed constraint)\n", best_params$lambda))
cat(sprintf("✓ Fitted bT2    = %.6f\n", p[5]))

# Post-fit diagnostic: verify thermal optimum in Celsius (Mordecai 2017 check)
if (p[5] < -1e-12) {
  T_vertex_std <- -p[4] / (2 * p[5])
  T_vertex_C   <- T_vertex_std * temp_std + temp_mu
  cat(sprintf("✓ Thermal vertex = %.1f°C (target: 26.1°C, Mordecai 2017)\n", T_vertex_C))
  if (abs(T_vertex_C - 26.1) > 4) {
    cat("  WARNING: vertex > 4°C from Mordecai optimum. Consider increasing penalty.\n")
  }
} else {
  cat("  WARNING: bT2 >= 0 — optimizer failed to enforce inverted-U. Re-check penalty.\n")
}
cat(sprintf("✓ r_train       = %.3f\n",  best_params$r_train))
cat(sprintf("✓ r_test        = %.3f\n",  best_params$r_test))
cat("✓ Saved: SEIR_optimal_params.csv\n")

# ── Lag heatmap ──────────────────────────────────────────────────────────────
all_res_plot <- all_res %>%
  filter(temp_lag != 12) %>%
  mutate(
    is_best = (rain_lag == best$rain_lag & temp_lag == best$temp_lag),
    r_test_clamp = pmin(pmax(r_test, 0), 1)
  )

p_heat <- ggplot(all_res_plot,
                 aes(x = factor(temp_lag), y = factor(rain_lag), fill = r_test_clamp)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.3f", r_test),
                colour = ifelse(is_best, "white", "grey20")),
            size = 14.0, family = BASE_FONT, fontface = "bold") +
  geom_tile(data = filter(all_res_plot, is_best),
            fill = NA, colour = "#E74C3C", linewidth = 2.0) +
  scale_fill_gradient2(
    low      = "#D6EAF8",
    mid      = "#2980B9",
    high     = "#1A5276",
    midpoint = median(all_res_plot$r_test_clamp, na.rm = TRUE),
    name     = "Test r\n(2023–24)",
    limits   = c(0, 1)
  ) +
  scale_colour_identity() +
  scale_x_discrete(labels = function(x) paste0(x, "w")) +
  scale_y_discrete(labels = function(x) paste0(x, "w")) +
  labs(
    title    = "**Lag Grid Search** — Out-of-sample Correlation (2023–2024 Test Data)",
    subtitle = "Each cell = Pearson r between SEIR predicted and observed weekly cases | Red box = optimal combination",
    x        = "Temperature Lag",
    y        = "Rainfall Lag",
    caption  = "Model fitted on training data (2013–2022) only. Test evaluation is truly out-of-sample."
  ) +
  cowplot::theme_cowplot(font_size = 20, font_family = BASE_FONT) +
  theme(
    plot.title         = element_markdown(size = 32, face = "bold"),
    plot.subtitle      = element_markdown(size = 24,  colour = "grey40"),
    plot.caption       = element_text(size = 18, colour = "grey50", hjust = 0),
    axis.title         = element_text(size = 36, face = "bold"),
    axis.text          = element_text(size = 32),
    legend.title       = element_text(size = 30, face = "bold"),
    legend.text        = element_text(size = 28),
    panel.grid         = element_blank(),
    legend.position    = "right",
    legend.key.height  = unit(1.8, "cm"),
    legend.key.width   = unit(0.8, "cm"),
    plot.background    = element_rect(fill = "white", colour = NA)
  )

dir.create("../02_Figures", showWarnings = FALSE, recursive = TRUE)
ggsave("../02_Figures/SEIR_LagHeatmap.png",
       p_heat, width = 11, height = 7, dpi = 300, bg = "white")

cat("✓ Saved: SEIR_LagHeatmap.png\n")
cat("\n=== SEIR_01_LagSearch COMPLETE ===\n")
