################################################################################
# 00_Coupled_Engine.R  —  Bidirectional Vector-Host Coupled Simulation Engine
#
# Source this file from all downstream scripts that need the full coupled model.
# Do NOT run directly.
#
# WHAT THIS ENGINE DOES:
#   Runs the human SEIRS model and the mosquito vector model TOGETHER week by
#   week, exchanging information in both directions:
#
#     Mosquito side (I_W) → Human side (beta_V → new human exposures)
#     Human side (I_H)    → Mosquito side (lambda_V → new vector exposures)
#
# This is the closed vector-host loop. The previous engine (00_SEIR_Engine.R)
# was one-way: climate drove human beta(t) statistically, mosquitoes had no
# dengue feedback. The coupled engine here makes both directions explicit.
#
# REFERENCE:
#   Ross-Macdonald (1957). The Mathematics of Malaria.
#   Diekmann, Heesterbeek, Metz (1990). J. Math. Biology 28:365-382.
################################################################################

source("00_Thermal_Functions.R")
source("04_ISV_Mosquito_Dynamics.R")

# ── Discrete-time biological probabilities (Aedes / dengue) ────────────────────
P_SIGMA_H <- 1 - exp(-7/6)         # weekly E_H → I_H probability (6-day incubation)
P_GAMMA_H <- 1 - exp(-7/5)         # weekly I_H → R_H probability (5-day infectious)
P_OMEGA_H <- 1 - exp(-1/(5*52))    # weekly R_H → S_H probability (5-year waning)
MU_H_WK   <- 1/(68*52)             # human weekly mortality

#' Run the coupled vector-host simulation
#'
#' @param p_seir 9-vector: log_kappa, b0, bR, bT, bT2, logit_rho, log_lambda,
#'   logit_E0f, logit_I0f. Same parameter ordering as the original engine.
#'   In the coupled model, kappa is now a *modifier* on the mechanistic beta
#'   rather than the sole driver — it accounts for unmodelled human factors
#'   such as serotype dynamics and mobility.
#' @param df_all  weekly data with Year, Week, Temperature, Nh, lag columns
#' @param rain_lag,temp_lag  optimal lags from grid search
#' @param p_ISV_vec  optional length-N numeric vector: ISV-positive fraction
#'   of adult females each week. If provided, ISV blocking is applied.
#' @param eps  ISV blocking efficacy (only used if p_ISV_vec provided).
#' @param M0_F  starting wild female population (overwintering survivors)
#' @return list(pred, S, E, I, R, S_W, E_W, I_W) — human and mosquito states
run_coupled <- function(p_seir, df_all, rain_lag, temp_lag,
                        p_ISV_vec = NULL, eps = 0,
                        K0 = 1e6, k_R_mosq = 0.02, M0_F = 20000) {

  kappa  <- exp(p_seir[1]); b0 <- p_seir[2]; bR <- p_seir[3]
  bT     <- p_seir[4]; bT2 <- p_seir[5]
  rho    <- plogis(p_seir[6]); lambda_import <- exp(p_seir[7])
  E0f    <- 0.01 * plogis(p_seir[8])
  I0f    <- 0.01 * plogis(p_seir[9])
  EPS    <- 1e-12

  col_R  <- paste0("Rain_z_lag",  rain_lag)
  col_T  <- paste0("Temp_z_lag",  temp_lag)
  col_T2 <- paste0("Temp_z_lag",  temp_lag, "2")
  R_z    <- df_all[[col_R]]; R_z[is.na(R_z)] <- 0
  T_z    <- df_all[[col_T]]; T_z[is.na(T_z)] <- 0
  T2_z   <- df_all[[col_T2]]; T2_z[is.na(T2_z)] <- 0

  N_arr  <- df_all$Nh; N_arr[is.na(N_arr)] <- N_arr[1]
  T_C    <- df_all$Temperature
  T_C[is.na(T_C)] <- 21.9
  T_len  <- nrow(df_all)
  if (is.null(p_ISV_vec)) p_ISV_vec <- rep(0, T_len)

  # Human compartments
  S <- E <- I <- R <- inc <- numeric(T_len)
  S[1] <- N_arr[1]*(1-E0f-I0f); E[1] <- N_arr[1]*E0f; I[1] <- N_arr[1]*I0f

  # Mosquito compartments (per year, reset each year)
  S_W_save <- E_W_save <- I_W_save <- numeric(T_len)

  # Carrying-capacity rainfall lag for mosquito side (5w following Mukhtar 2011)
  rain_raw <- df_all$Rainfall
  if (is.null(rain_raw)) rain_raw <- rep(0, T_len)
  R_for_mosq <- c(rep(NA, 5), rain_raw[1:(T_len - 5)])
  R_for_mosq[is.na(R_for_mosq)] <- 0

  # Initialise wild mosquito state (overwintering)
  S_W <- M0_F; E_W <- 0; I_W <- 0
  K_t <- K0 * exp(k_R_mosq * R_for_mosq[1])
  A_aq <- K_t * 0.10   # aquatic seed

  for (t in seq_len(T_len)) {
    Tv <- T_C[t]; if (is.na(Tv)) Tv <- 21.9
    Rv <- R_for_mosq[t]; if (is.na(Rv)) Rv <- 0; Rv <- max(Rv, 0)

    # Statistical beta retained as a multiplicative modifier (kappa absorbs
    # any unmodelled factors). The shield (1 - eps*p_ISV) blocks transmission
    # from CFAV-positive mosquitoes.
    eta    <- b0 + bR*R_z[t] + bT*T_z[t] + bT2*T2_z[t]
    shield <- 1 - eps * p_ISV_vec[t]
    beta_t <- kappa * exp(pmax(pmin(eta,15),-15)) * shield

    # NEW HUMAN EXPOSURES this week
    new_inf <- max(min(beta_t*(S[t]*I[t])/max(N_arr[t],EPS) + lambda_import, S[t]), 0)
    inc[t]  <- new_inf

    # ── Mosquito update for this week (with human→mosquito feedback) ─────────
    sv     <- surv_V_T(Tv)
    efd_v  <- EFD_T(Tv); mdr_v <- MDR_T(Tv); pea_v <- pEA_T(Tv)
    pdr_v  <- PDR_T(Tv); a_v   <- a_T(Tv);   c_v   <- c_T(Tv)
    K_t    <- K0 * exp(k_R_mosq * Rv)

    # Human-to-mosquito force of infection (Ross-Macdonald form)
    I_frac <- I[t] / max(N_arr[t], EPS)
    lambda_V <- a_v * c_v * I_frac          # per day
    p_inf_V  <- 1 - exp(-lambda_V * 7)      # weekly probability

    # Aquatic dynamics (eggs → adults). Wild-only here (CFAV side handled in
    # standalone simulate_mosquitoes when computing p_ISV externally).
    N_V_F  <- S_W + E_W + I_W
    eggs_in <- efd_v * 7 * N_V_F
    G_t     <- mdr_v * pea_v * 7 * A_aq
    comp    <- (A_aq^2) / (K_t + EPS)
    A_aq    <- max(A_aq + eggs_in - G_t - MU_A*7*A_aq - comp, 0)

    # Dengue compartments in wild females
    new_E_W <- p_inf_V * S_W
    new_I_W <- (1 - exp(-pdr_v * 7)) * E_W
    S_W     <- max(S_W*sv - new_E_W + G_t*SEX_RATIO, 0)
    E_W     <- max(E_W*sv + new_E_W - new_I_W, 0)
    I_W     <- max(I_W*sv + new_I_W, 0)

    S_W_save[t] <- S_W; E_W_save[t] <- E_W; I_W_save[t] <- I_W

    # Update human compartments
    if (t < T_len) {
      Nt <- N_arr[t]
      new_I_H <- P_SIGMA_H * E[t]
      new_R_H <- P_GAMMA_H * I[t]
      wane    <- P_OMEGA_H * R[t]
      S[t+1] <- max(S[t] - new_inf + wane + MU_H_WK*(Nt - S[t]), 0)
      E[t+1] <- max(E[t] + new_inf - new_I_H - MU_H_WK*E[t], 0)
      I[t+1] <- max(I[t] + new_I_H - new_R_H - MU_H_WK*I[t], 0)
      R[t+1] <- max(R[t] + new_R_H - wane - MU_H_WK*R[t], 0)
      tot <- S[t+1]+E[t+1]+I[t+1]+R[t+1]
      dN  <- N_arr[t+1] - tot
      if (!is.na(dN) && dN >= 0) S[t+1] <- S[t+1] + dN
    }
  }

  list(pred = rho * inc, inc = inc, rho = rho,
       S = S, E = E, I = I, R = R,
       S_W = S_W_save, E_W = E_W_save, I_W = I_W_save)
}

cat("00_Coupled_Engine.R sourced OK (bidirectional vector-host loop active)\n")
