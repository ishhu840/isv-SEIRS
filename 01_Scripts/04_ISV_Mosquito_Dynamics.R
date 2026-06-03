################################################################################
# 02_ISV_MosquitoModel.R
# ISV_VectorHost_Model — Script 02
#
# PURPOSE:
#   Simulate Aedes aegypti mosquito population dynamics (aquatic + adult stages)
#   with ISV (CFAV) spread via 3-route transmission.
#   Uses ALL Mordecai 2017 thermal functions (no simplifications).
#
# THIS IS THE MOSQUITO BLOCK of the vector-host model.
# Output: p_ISV(t) — the ISV fraction of adult females each week.
# This fraction is then used in Script 03 to modify dengue transmission.
#
# MODEL STRUCTURE:
#   Aquatic (A):    egg + larva + pupa (density-dependent logistic competition)
#   Adult females:  S_W  wild susceptible
#                   E_W  wild exposed to dengue (EIP)
#                   I_W  wild infectious (transmitting dengue)
#                   N_I  ISV-carrying (CFAV blocks dengue)
#   Adult males:    N_M_W  wild, N_M_I  ISV-carrying (for paternal/venereal routes)
#
# ALL THERMAL RATES from Mordecai 2017:
#   Survival:   surv_V(T) = max(exp(-7/lf(T)), SURV_MIN)
#   Fecundity:  EFD(T)  — eggs/female/day
#   Maturation: MDR(T)  — larval maturation rate (/day)
#   Larval surv:pEA(T)  — probability egg survives to adult
#   EIP:        PDR(T)  — parasite development rate (/day)
#   Biting:     a(T)    — biting rate (/day) [used in Script 03]
#
# CARRYING CAPACITY:
#   K(t) = K0 * exp(k_R * Rain_lag5[t])
#   K0 and k_R are calibrated from data (see Script 03)
#
# REFERENCES:
#   Mordecai EA et al. (2017). PLOS NTDs.
#   Baidaliuk A et al. (2019). MBio.
################################################################################

source("00_Thermal_Functions.R")

# ── ISV biological parameters [Baidaliuk 2019] ────────────────────────────────
NU_M  <- 0.93   # maternal vertical transmission
NU_P  <- 0.76   # paternal transmission
NU_V  <- 0.31   # venereal transmission
NU_PV <- NU_P + (1 - NU_P) * NU_V * NU_M  # combined paternal+venereal

# ── Fixed mosquito parameters ─────────────────────────────────────────────────
MU_A      <- 0.01    # aquatic stage daily mortality (baseline)
SEX_RATIO <- 0.50    # fraction of new adults that are female

#' Effective ISV vertical transmission rate from current population fractions
#' @param p_F  ISV fraction of adult females
#' @param p_M  ISV fraction of adult males
isv_nu_eff <- function(p_F, p_M) {
  NU_M * p_F +
  NU_PV * (1 - p_F) * p_M
}

# ── Main mosquito simulation ───────────────────────────────────────────────────
#' Simulate mosquito population and ISV dynamics for one year
#'
#' @param T_vec    numeric(52): weekly mean temperature (°C)
#' @param R_vec    numeric(52): weekly lagged rainfall (mm, lag already applied)
#' @param K0       numeric: baseline carrying capacity (females at peak)
#' @param k_R      numeric: rainfall coefficient (K = K0 * exp(k_R * Rain))
#' @param rel_week integer: week of ISV release (10=March, 23=June, 31=August)
#' @param N_rel    integer: number of ISV females released
#' @param M0_F     numeric: initial adult female population (overwintering)
#' @param I0W_f    numeric: fraction of initial adults with dengue (0–0.05)
#' @param lambda_V_vec  numeric(NW): weekly human→mosquito force of infection
#'   (rate at which susceptible wild females become dengue-exposed). Default = 0
#'   when running standalone; supplied by coupled simulation otherwise.
#'   lambda_V(t) = a(T) * c(T) * I_H(t) / N_H(t)
#' @return list with p_ISV (weekly ISV fraction), all compartments, N_pop
simulate_mosquitoes <- function(T_vec, R_vec, K0, k_R,
                                rel_week = 10L, N_rel_F = 0L, N_rel_M = 50000L,
                                M0_F = 20000, I0W_f = 0,
                                lambda_V_vec = NULL) {
  NW  <- length(T_vec)
  EPS <- 1e-12
  if (is.null(lambda_V_vec)) lambda_V_vec <- rep(0, NW)
  lambda_V_vec[is.na(lambda_V_vec)] <- 0

  # Compartments
  A     <- numeric(NW)   # aquatic
  S_W   <- numeric(NW)   # wild susceptible females
  E_W   <- numeric(NW)   # wild exposed (dengue EIP)
  I_W   <- numeric(NW)   # wild infectious females
  N_I   <- numeric(NW)   # ISV-carrying females
  N_M_W <- numeric(NW)   # wild males
  N_M_I <- numeric(NW)   # ISV-carrying males

  # Initial conditions — overwintering population (all wild, some infectious)
  R1      <- max(R_vec[1], 0); if (is.na(R1)) R1 <- 0
  K1      <- K0 * exp(k_R * R1)
  A[1]    <- K1 * 0.10          # aquatic at 10% of K
  S_W[1]  <- M0_F * (1 - I0W_f)
  I_W[1]  <- M0_F * I0W_f
  E_W[1]  <- 0
  N_I[1]  <- 0
  N_M_W[1]<- M0_F
  N_M_I[1]<- 0

  for (t in 1:NW) {
    Tv <- T_vec[t]; if (is.na(Tv)) Tv <- 21.9
    Rv <- R_vec[t]; if (is.na(Rv)) Rv <- 0; Rv <- max(Rv, 0)

    # ── Thermal rates (all from Mordecai 2017) ────────────────────────────────
    sv    <- surv_V_T(Tv)      # weekly adult survival (min 0.20)
    efd_v <- EFD_T(Tv)         # eggs per female per day
    mdr_v <- MDR_T(Tv)         # larval maturation rate per day
    pea_v <- pEA_T(Tv)         # larval-to-adult survival probability
    pdr_v <- PDR_T(Tv)         # parasite development rate per day (=1/EIP)

    # Carrying capacity this week (rainfall-driven)
    K_t   <- K0 * exp(k_R * Rv)

    # ── ISV fractions ─────────────────────────────────────────────────────────
    N_V_F <- S_W[t] + E_W[t] + I_W[t] + N_I[t]
    N_V_M <- N_M_W[t] + N_M_I[t]
    p_F   <- N_I[t]   / (N_V_F + EPS)
    p_M   <- N_M_I[t] / (N_V_M + EPS)
    nu_v  <- isv_nu_eff(p_F, p_M)

    # ── Aquatic dynamics (eggs, larvae, pupae combined) ───────────────────────
    eggs_in  <- efd_v * 7 * N_V_F                          # new eggs per week
    G_t      <- mdr_v * pea_v * 7 * A[t]                   # maturing adults
    comp     <- (A[t]^2) / (K_t + EPS)                     # density competition
    A_next   <- max(A[t] + eggs_in - G_t - MU_A*7*A[t] - comp, 0)

    # Recruit new adult females and males
    G_F      <- G_t * SEX_RATIO
    G_M      <- G_t * (1 - SEX_RATIO)

    # ISV inheritance in recruits (3 routes)
    ISV_F    <- nu_v * G_F;   W_F <- G_F - ISV_F
    ISV_M    <- nu_v * G_M;   W_M <- G_M - ISV_M

    # ── ISV release this week? ─────────────────────────────────────────────────
    rel_F <- if (t == rel_week) N_rel_F else 0
    rel_M <- if (t == rel_week) N_rel_M else 0

    # ── Dengue dynamics in wild pool (HUMAN→MOSQUITO FEEDBACK ENABLED) ────────
    # lambda_V(t) = a(T) * c(T) * I_H(t) / N_H(t) — supplied by caller
    # Probability a susceptible wild female becomes exposed this week:
    p_inf_V  <- 1 - exp(-lambda_V_vec[t] * 7)
    new_E_W  <- p_inf_V * S_W[t]          # new dengue exposures this week
    new_I_W  <- (1 - exp(-pdr_v * 7)) * E_W[t]   # EIP completion: E_W → I_W

    if (t < NW) {
      A[t+1]    <- A_next
      S_W[t+1]  <- max(S_W[t]*sv - new_E_W + W_F, 0)
      E_W[t+1]  <- max(E_W[t]*sv + new_E_W - new_I_W, 0)
      I_W[t+1]  <- max(I_W[t]*sv + new_I_W, 0)
      N_I[t+1]  <- max(N_I[t]*sv + ISV_F + rel_F, 0)
      N_M_W[t+1]<- max(N_M_W[t]*sv + W_M, 0)
      N_M_I[t+1]<- max(N_M_I[t]*sv + ISV_M + rel_M, 0)
    }
  }

  # ISV fraction of adult females each week
  p_ISV <- N_I / (S_W + E_W + I_W + N_I + EPS)

  list(p_ISV = p_ISV, A = A,
       S_W = S_W, E_W = E_W, I_W = I_W, N_I = N_I,
       N_M_W = N_M_W, N_M_I = N_M_I,
       N_V_F = S_W + E_W + I_W + N_I)
}

# ── Quick test ─────────────────────────────────────────────────────────────────
if (interactive() || sys.nframe() == 0) {
  suppressPackageStartupMessages({library(readxl); library(dplyr)})
  df_raw <- read_excel("../00_Data/D1_Weekly_Cases_Weather.xlsx")
  df_raw <- df_raw[df_raw$City=="Rawalpindi",]
  df_raw <- df_raw[order(df_raw$Year,df_raw$Week),]

  T23 <- df_raw$Temperature[df_raw$Year==2023]
  R23 <- df_raw$Rainfall[df_raw$Year==2023]
  R23_lag <- c(rep(NA, 7), R23[1:(52 - 7)])   # 7w optimal lag from Rawalpindi grid search

  sim <- simulate_mosquitoes(
    T_vec = T23, R_vec = R23_lag,
    K0 = 1e6, k_R = 0.02,
    rel_week = 10L, N_rel_F = 0L, N_rel_M = 50000L,
    M0_F = 20000, I0W_f = 0.001
  )
  cat("\n=== Mosquito Model Test — 2023 ===\n")
  cat(sprintf("Peak adult females: %.0f\n", max(sim$N_V_F, na.rm=TRUE)))
  cat(sprintf("ISV fraction: Mar=%.1f%%  Jul=%.1f%%  Sep=%.1f%%  Oct=%.1f%%\n",
    sim$p_ISV[10]*100, sim$p_ISV[27]*100, sim$p_ISV[36]*100, sim$p_ISV[40]*100))
  cat("✓ 02_ISV_MosquitoModel.R OK\n")
} else {
  cat("02_ISV_MosquitoModel.R sourced OK\n")
}
