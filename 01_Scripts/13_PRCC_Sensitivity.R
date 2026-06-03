################################################################################
# 13_PRCC_Sensitivity.R
# Partial Rank Correlation Coefficient (PRCC) sensitivity analysis
#
# PURPOSE:
#   Quantify which input parameters most strongly drive variation in the
#   March release efficacy. Uses Latin Hypercube Sampling across 8 parameters
#   spanning their plausible biological ranges (Baidaliuk 2019 CIs plus
#   field uncertainty for ecology/release parameters).
#
# METHOD:
#   1. Latin Hypercube Sample (LHS) N_LHS parameter sets
#   2. For each set, run full SEIR-ISV simulation across all 12 years
#   3. Record annual case reduction (median across 12 years) per sample
#   4. Compute PRCC: rank-transform inputs and output, fit linear models,
#      report partial correlation of each input rank against output rank
#      after controlling for the other 7 inputs
#   5. Plot tornado chart with significance bars (|PRCC| > 0.2 = strong)
#
# OUTPUT: ../02_Figures/POSTER_Fig6_PRCC_Sensitivity.png
#         ../03_Results/PRCC_Sensitivity_Results.csv
################################################################################

suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(ggplot2); library(lhs); library(tidyr)
})
source("00_Thermal_Functions.R")
source("04_ISV_Mosquito_Dynamics.R")
source("00_Coupled_Engine.R")   # Testing_Study: coupled bidirectional engine

cat("=== PRCC Sensitivity Analysis (Latin Hypercube Sampling, Coupled Engine) ===\n")

# ── SEIR engine (local copy with corrected probabilities) ────────────────────
run_seir_isv <- function(p_seir, df_all, rain_lag, temp_lag, shield_vec) {
  kappa  <- exp(p_seir[1]); b0 <- p_seir[2]; bR <- p_seir[3]
  bT     <- p_seir[4]; bT2 <- p_seir[5]
  rho    <- plogis(p_seir[6]); lambda <- exp(p_seir[7])
  E0f    <- plogis(p_seir[8]); I0f <- plogis(p_seir[9])
  P_SIGMA <- 1 - exp(-7/6); P_GAMMA <- 1 - exp(-7/5)
  P_OMEGA <- 1 - exp(-1/(5*52)); MU <- 1/(68*52); EPS <- 1e-12
  col_R  <- paste0("Rain_z_lag",rain_lag); col_T  <- paste0("Temp_z_lag",temp_lag)
  col_T2 <- paste0("Temp_z_lag",temp_lag,"2")
  R_z    <- df_all[[col_R]]; R_z[is.na(R_z)] <- 0
  Tz     <- df_all[[col_T]]; Tz[is.na(Tz)] <- 0
  T2_z   <- df_all[[col_T2]]; T2_z[is.na(T2_z)] <- 0
  N_arr  <- df_all$Nh; N0 <- N_arr[1]; T_len <- nrow(df_all)
  S <- E <- I <- R <- inc <- numeric(T_len)
  S[1] <- N0*(1-E0f-I0f); E[1] <- N0*E0f; I[1] <- N0*I0f
  for (t in seq_len(T_len)) {
    eta    <- b0 + bR*R_z[t] + bT*Tz[t] + bT2*T2_z[t]
    beta_t <- kappa * exp(pmax(pmin(eta,15),-15)) * (1 - shield_vec[t])
    new_E  <- max(min(beta_t*(S[t]*I[t])/max(N_arr[t],EPS)+lambda, S[t]), 0)
    inc[t] <- new_E
    if (t < T_len) {
      Nt <- N_arr[t]
      new_I <- P_SIGMA * E[t]; new_R <- P_GAMMA * I[t]; wane <- P_OMEGA * R[t]
      S[t+1] <- max(S[t]-new_E+wane+MU*(Nt-S[t]),0)
      E[t+1] <- max(E[t]+new_E-new_I-MU*E[t],0)
      I[t+1] <- max(I[t]+new_I-new_R-MU*I[t],0)
      R[t+1] <- max(R[t]+new_R-wane-MU*R[t],0)
      tot <- S[t+1]+E[t+1]+I[t+1]+R[t+1]; dN <- N_arr[t+1]-tot
      if (!is.na(dN) && dN>=0) S[t+1] <- S[t+1]+dN
    }
  }
  rho * inc
}

# Override simulate_mosquitoes constants per-call by re-sourcing values
sim_mosq_param <- function(T_vec, R_vec, K0, k_R, rel_week, N_rel_M,
                           M0_F, I0W_f, nu_M, nu_P, nu_V) {
  NU_PV_local <- nu_P + (1 - nu_P) * nu_V * nu_M
  NW <- length(T_vec); EPS <- 1e-12
  A <- S_W <- E_W <- I_W <- N_I <- N_M_W <- N_M_I <- numeric(NW)
  R1 <- max(R_vec[1], 0); if (is.na(R1)) R1 <- 0
  K1 <- K0 * exp(k_R * R1)
  A[1] <- K1 * 0.10
  S_W[1] <- M0_F * (1 - I0W_f); I_W[1] <- M0_F * I0W_f
  N_M_W[1] <- M0_F
  for (t in 1:NW) {
    Tv <- T_vec[t]; if (is.na(Tv)) Tv <- 21.9
    Rv <- R_vec[t]; if (is.na(Rv)) Rv <- 0; Rv <- max(Rv, 0)
    sv <- surv_V_T(Tv); efd_v <- EFD_T(Tv)
    mdr_v <- MDR_T(Tv); pea_v <- pEA_T(Tv); pdr_v <- PDR_T(Tv)
    K_t <- K0 * exp(k_R * Rv)
    N_V_F <- S_W[t] + E_W[t] + I_W[t] + N_I[t]
    N_V_M <- N_M_W[t] + N_M_I[t]
    p_F <- N_I[t] / (N_V_F + EPS); p_M <- N_M_I[t] / (N_V_M + EPS)
    nu_v <- nu_M*p_F + NU_PV_local*(1-p_F)*p_M
    eggs_in <- efd_v * 7 * N_V_F
    G_t <- mdr_v * pea_v * 7 * A[t]
    comp <- (A[t]^2) / (K_t + EPS)
    A_next <- max(A[t] + eggs_in - G_t - 0.01*7*A[t] - comp, 0)
    G_F <- G_t * 0.5; G_M <- G_t * 0.5
    ISV_F <- nu_v * G_F; W_F <- G_F - ISV_F
    ISV_M <- nu_v * G_M; W_M <- G_M - ISV_M
    rel_M_now <- if (t == rel_week) N_rel_M else 0
    new_I_W <- pdr_v * 7 * E_W[t]
    if (t < NW) {
      A[t+1] <- A_next
      S_W[t+1] <- max(S_W[t]*sv + W_F, 0)
      E_W[t+1] <- max(E_W[t]*sv - new_I_W, 0)
      I_W[t+1] <- max(I_W[t]*sv + new_I_W, 0)
      N_I[t+1] <- max(N_I[t]*sv + ISV_F, 0)
      N_M_W[t+1] <- max(N_M_W[t]*sv + W_M, 0)
      N_M_I[t+1] <- max(N_M_I[t]*sv + ISV_M + rel_M_now, 0)
    }
  }
  N_I / (S_W + E_W + I_W + N_I + EPS)
}

# ── Load fitted parameters ───────────────────────────────────────────────────
opt_params <- read.csv("../03_Results/SEIR_optimal_params.csv")
p_local <- c(opt_params$log_kappa, opt_params$b0, opt_params$bR,
             opt_params$bT, opt_params$bT2, opt_params$logit_rho,
             opt_params$log_lambda, opt_params$logit_E0f, opt_params$logit_I0f)
RL <- opt_params$rain_lag; TL <- opt_params$temp_lag

df_raw <- read_excel("../00_Data/D1_Weekly_Cases_Weather.xlsx")
df_raw <- df_raw[df_raw$City=="Rawalpindi",]
df_raw <- df_raw[order(df_raw$Year, df_raw$Week),]
df_raw$cases <- df_raw$"Number of Dengue Cases"
df_raw$cases[is.na(df_raw$cases)] <- 0
df_raw <- df_raw %>% mutate(
  Nh = case_when(
    Year <= 2017 ~ 2100000 * (1 + 0.0252)^(Year - 2013),
    TRUE         ~ 2430423 * (1 + 0.0252)^(Year - 2017)))
df_all <- df_raw
train_mask <- df_raw$Year >= 2013 & df_raw$Year <= 2022
rain_lag_full <- c(rep(NA, RL), df_raw$Rainfall[1:(nrow(df_raw)-RL)])
temp_lag_full <- c(rep(NA, TL), df_raw$Temperature[1:(nrow(df_raw)-TL)])
RL_col  <- paste0("Rain_z_lag", RL)
TL_col  <- paste0("Temp_z_lag", TL)
TL_col2 <- paste0("Temp_z_lag", TL, "2")
df_all[[RL_col]]  <- (rain_lag_full - mean(rain_lag_full[train_mask], na.rm=TRUE)) / sd(rain_lag_full[train_mask], na.rm=TRUE)
df_all[[TL_col]]  <- (temp_lag_full - mean(temp_lag_full[train_mask], na.rm=TRUE)) / sd(temp_lag_full[train_mask], na.rm=TRUE)
df_all[[TL_col2]] <- df_all[[TL_col]]^2
df_all[[RL_col]][is.na(df_all[[RL_col]])] <- 0
df_all[[TL_col]][is.na(df_all[[TL_col]])] <- 0
df_all[[TL_col2]][is.na(df_all[[TL_col2]])] <- 0

# Baseline (no ISV) — reused for efficacy calc
sv_base <- rep(0, nrow(df_all))
baseline_co <- run_coupled(p_local, df_all, RL, TL, p_ISV_vec=NULL, eps=0)
df_all$pred_baseline <- baseline_co$pred

# ── Latin Hypercube Sample 8 parameters ─────────────────────────────────────
set.seed(20260529)
N_LHS <- 200   # reduced from 500 for coupled-engine compute cost (Testing_Study)
n_par <- 8
lhs_unit <- randomLHS(N_LHS, n_par)

# Map [0,1] uniforms to parameter ranges
param_ranges <- data.frame(
  param = c("eps", "nu_M", "nu_P", "nu_V", "K0", "k_R", "M0_F", "N_rel_M"),
  lo    = c(0.65, 0.79, 0.59, 0.14, 5e5, 0.01, 10000, 15000),
  hi    = c(0.95, 0.99, 0.89, 0.49, 2e6, 0.04, 30000, 35000),
  source = c("Baidaliuk 2019", "Baidaliuk 2019 CI", "Baidaliuk 2019 CI",
             "Baidaliuk 2019 CI", "Field uncertainty (±50%)",
             "Field uncertainty (±50%)", "Overwintering uncertainty",
             "Release design space")
)

samp <- data.frame(
  eps     = lhs_unit[,1] * (param_ranges$hi[1]-param_ranges$lo[1]) + param_ranges$lo[1],
  nu_M    = lhs_unit[,2] * (param_ranges$hi[2]-param_ranges$lo[2]) + param_ranges$lo[2],
  nu_P    = lhs_unit[,3] * (param_ranges$hi[3]-param_ranges$lo[3]) + param_ranges$lo[3],
  nu_V    = lhs_unit[,4] * (param_ranges$hi[4]-param_ranges$lo[4]) + param_ranges$lo[4],
  K0      = lhs_unit[,5] * (param_ranges$hi[5]-param_ranges$lo[5]) + param_ranges$lo[5],
  k_R     = lhs_unit[,6] * (param_ranges$hi[6]-param_ranges$lo[6]) + param_ranges$lo[6],
  M0_F    = lhs_unit[,7] * (param_ranges$hi[7]-param_ranges$lo[7]) + param_ranges$lo[7],
  N_rel_M = lhs_unit[,8] * (param_ranges$hi[8]-param_ranges$lo[8]) + param_ranges$lo[8]
)

# ── Run model for every LHS sample (March release, mean efficacy across 12yr) ─
YEARS <- 2013:2024
rel_week <- 10L   # March
I0W_f <- 0.001

cat(sprintf("Running %d LHS samples × %d years = %d total simulations...\n",
            N_LHS, length(YEARS), N_LHS*length(YEARS)))

reductions <- numeric(N_LHS)
pb_step <- max(1, N_LHS %/% 20)

for (i in seq_len(N_LHS)) {
  yr_reds <- numeric(length(YEARS))
  for (yi in seq_along(YEARS)) {
    yr <- YEARS[yi]
    mask_yr <- df_all$Year == yr
    idx_yr <- which(mask_yr)
    T_yr <- df_raw$Temperature[mask_yr]
    R_lag <- c(rep(NA, RL), df_raw$Rainfall[mask_yr][1:(52 - RL)])
    pred_base_yr <- sum(df_all$pred_baseline[mask_yr], na.rm=TRUE)

    p_ISV_yr <- sim_mosq_param(
      T_yr, R_lag,
      K0 = samp$K0[i], k_R = samp$k_R[i],
      rel_week = rel_week, N_rel_M = round(samp$N_rel_M[i]),
      M0_F = samp$M0_F[i], I0W_f = I0W_f,
      nu_M = samp$nu_M[i], nu_P = samp$nu_P[i], nu_V = samp$nu_V[i]
    )
    p_ISV_full <- rep(0, nrow(df_all))
    for (w in 1:52) if (!is.na(p_ISV_yr[w])) p_ISV_full[idx_yr[w]] <- p_ISV_yr[w]
    sim_isv <- run_coupled(p_local, df_all, RL, TL,
                           p_ISV_vec = p_ISV_full, eps = samp$eps[i])
    pp <- sim_isv$pred
    yr_reds[yi] <- if (pred_base_yr > 0) 100 * (pred_base_yr - sum(pp[mask_yr], na.rm=TRUE)) / pred_base_yr else 0
  }
  reductions[i] <- median(yr_reds)
  if (i %% pb_step == 0) cat(sprintf("  [%d/%d] done\n", i, N_LHS))
}

samp$Reduction <- reductions
cat(sprintf("\nReduction distribution: median=%.1f%%  [Q1=%.1f, Q3=%.1f]\n",
            median(reductions), quantile(reductions, 0.25), quantile(reductions, 0.75)))

# ── Compute PRCC ────────────────────────────────────────────────────────────
# Rank-transform inputs and output, then partial correlation
ranks <- data.frame(
  eps_r     = rank(samp$eps),
  nu_M_r    = rank(samp$nu_M),
  nu_P_r    = rank(samp$nu_P),
  nu_V_r    = rank(samp$nu_V),
  K0_r      = rank(samp$K0),
  k_R_r     = rank(samp$k_R),
  M0_F_r    = rank(samp$M0_F),
  N_rel_r   = rank(samp$N_rel_M),
  Y_r       = rank(samp$Reduction)
)
input_names <- c("eps_r","nu_M_r","nu_P_r","nu_V_r","K0_r","k_R_r","M0_F_r","N_rel_r")

prcc_vals <- numeric(length(input_names))
prcc_p    <- numeric(length(input_names))
for (j in seq_along(input_names)) {
  this <- input_names[j]
  others <- setdiff(input_names, this)
  # Residuals from regressing the target input on the OTHER inputs
  lm_x <- lm(reformulate(others, response = this), data = ranks)
  res_x <- residuals(lm_x)
  # Residuals from regressing the output on the OTHER inputs
  lm_y <- lm(reformulate(others, response = "Y_r"), data = ranks)
  res_y <- residuals(lm_y)
  ct <- cor.test(res_x, res_y)
  prcc_vals[j] <- ct$estimate
  prcc_p[j]    <- ct$p.value
}

prcc_df <- data.frame(
  Parameter = c("ε (blocking efficacy)", "ν_M (maternal)", "ν_P (paternal)",
                "ν_V (venereal)", "K₀ (carrying cap)", "k_R (rain→K)",
                "M₀_F (init females)", "N_rel (released males)"),
  PRCC      = prcc_vals,
  p_value   = prcc_p,
  Significant = ifelse(prcc_p < 0.01, "***", ifelse(prcc_p < 0.05, "*", "ns"))
) %>% arrange(desc(abs(PRCC)))

cat("\n=== PRCC Results (sorted by |PRCC|) ===\n")
print(prcc_df)

dir.create("../03_Results", showWarnings = FALSE)
write.csv(prcc_df, "../03_Results/PRCC_Sensitivity_Results.csv", row.names = FALSE)

# ── Plot tornado chart ──────────────────────────────────────────────────────
prcc_df$Parameter <- factor(prcc_df$Parameter, levels = rev(prcc_df$Parameter))
prcc_df$Direction <- ifelse(prcc_df$PRCC > 0, "Increases efficacy", "Decreases efficacy")

BF <- "sans"
PT <- theme_minimal(base_family=BF, base_size=15) + theme(
  plot.title    = element_text(size=20, face="bold", margin=margin(b=4)),
  plot.subtitle = element_text(size=12, colour="grey40", margin=margin(b=14)),
  plot.caption  = element_text(size=11, colour="#2255AA", face="bold.italic", hjust=0),
  axis.title    = element_text(size=14, face="bold"),
  axis.text     = element_text(size=12, face="bold", colour="grey20"),
  panel.grid.minor = element_blank(),
  panel.grid.major.y = element_blank(),
  panel.grid.major.x = element_line(colour="grey90"),
  plot.background  = element_rect(fill="white", colour=NA),
  panel.background = element_rect(fill="white", colour=NA),
  plot.margin = margin(20, 28, 18, 22),
  legend.position = "top",
  legend.title = element_blank(),
  legend.text  = element_text(size=12, face="bold")
)

p <- ggplot(prcc_df, aes(x = PRCC, y = Parameter, fill = Direction)) +
  geom_vline(xintercept = 0, colour = "grey20", linewidth = 0.7) +
  geom_vline(xintercept = c(-0.2, 0.2), colour = "grey60", linetype = "dashed", linewidth = 0.5) +
  geom_col(width = 0.65, alpha = 0.88, colour = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%+.3f %s", PRCC, Significant),
                hjust = ifelse(PRCC > 0, -0.10, 1.10)),
            size = 4.6, fontface = "bold", colour = "grey15", family = BF) +
  scale_fill_manual(values = c("Increases efficacy" = "#27AE60",
                               "Decreases efficacy" = "#E74C3C")) +
  scale_x_continuous(limits = c(-0.25, 1.05), breaks = seq(-0.25, 1.00, 0.25),
                     expand = expansion(mult = c(0.02, 0.02))) +
  labs(
    title    = "Sensitivity of March Efficacy to Input Parameters (PRCC)",
    subtitle = sprintf("Latin Hypercube Sampling | N = %d samples × 12 years | Output = annual case reduction (%%)", N_LHS),
    x = "Partial Rank Correlation Coefficient (PRCC)",
    y = NULL,
    caption = "Dashed lines at ±0.2 = strong-influence threshold. *** p<0.01  * p<0.05  ns p≥0.05"
  ) + PT

dir.create("../02_Figures", showWarnings = FALSE)
ggsave("../02_Figures/POSTER_Fig6_PRCC_Sensitivity.png", p,
       width = 12, height = 7, dpi = 300, bg = "white")
cat("\nSaved: POSTER_Fig6_PRCC_Sensitivity.png\n")
cat("Saved: PRCC_Sensitivity_Results.csv\n")
