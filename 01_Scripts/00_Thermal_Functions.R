################################################################################
# 00_Thermal_Functions.R
# ISV_VectorHost_Model — Script 00
#
# PURPOSE:
#   Define ALL temperature-dependent biological functions for Aedes aegypti
#   dengue transmission, sourced entirely from Mordecai et al. (2017).
#   This is the single source of truth for thermal biology in the project.
#
# REFERENCE:
#   Mordecai EA, Cohen JM, Evans MV, et al. (2017).
#   Detecting the impact of temperature on transmission of Zika, dengue,
#   and chikungunya using mechanistic models.
#   PLOS Neglected Tropical Diseases 11(4): e0005568.
#
# FUNCTIONAL FORMS:
#   Briere:    f(T) = c * T * (T - T_min) * sqrt(T_max - T)  for T in (T_min, T_max)
#   Quadratic: f(T) = c * (T - T_min) * (T_max - T)          for T in (T_min, T_max)
#   Both return 0 outside thermal limits.
#
# USAGE:
#   source("00_Thermal_Functions.R")
#   All functions accept scalar or vector T in degrees Celsius.
################################################################################

# ── Functional forms ──────────────────────────────────────────────────────────

#' Briere thermal performance curve
#' @param T temperature (°C)
#' @param c  scaling constant
#' @param T_min lower thermal limit
#' @param T_max upper thermal limit
briere <- function(T, c, T_min, T_max) {
  val <- c * T * (T - T_min) * sqrt(pmax(T_max - T, 0))
  ifelse(T > T_min & T < T_max, pmax(val, 0), 0)
}

#' Quadratic thermal performance curve
#' @param T temperature (°C)
#' @param c  scaling constant
#' @param T_min lower thermal limit
#' @param T_max upper thermal limit
quadratic <- function(T, c, T_min, T_max) {
  val <- c * (T - T_min) * (T_max - T)
  ifelse(T > T_min & T < T_max, pmax(val, 0), 0)
}

# ── Aedes aegypti thermal functions (Mordecai 2017, Table 1) ─────────────────

#' Biting rate — a(T) [bites per day]
#' Briere. Peaks ~29°C.
a_T <- function(T) briere(T, c=2.02e-4, T_min=13.35, T_max=40.08)

#' Probability of transmission: infectious mosquito → susceptible human — b(T)
#' Quadratic. Peaks ~26°C.
b_T <- function(T) quadratic(T, c=8.49e-4, T_min=17.05, T_max=35.83)

#' Probability of transmission: infectious human → susceptible mosquito — c(T)
#' Quadratic. Peaks ~24°C.
c_T <- function(T) quadratic(T, c=4.91e-4, T_min=12.22, T_max=37.46)

#' Parasite development rate in mosquito — PDR(T) [1/days = 1/EIP]
#' Briere. EIP is the Extrinsic Incubation Period.
#' Peaks ~35°C.
PDR_T <- function(T) briere(T, c=6.65e-5, T_min=10.68, T_max=45.90)

#' Adult mosquito lifespan — lf(T) [days]
#' Quadratic. Peaks ~21°C. Minimum floor at 0.01 days to prevent Inf.
#' This is IDENTICAL to the function used in BioInference2026 (validated).
lf_T <- function(T) pmax(-0.148*T^2 + 8.78*T - 110, 0.01)

#' Adult mosquito daily mortality rate — mu_V(T) [per day]
mu_V_T <- function(T) 1 / lf_T(T)

#' Adult mosquito weekly survival probability — surv_V(T)
#' Minimum floor = 0.20 per week (represents sheltering in warm microhabitats,
#' urban heat island effect; justified by observed dengue cases at cool T).
SURV_MIN <- 0.20
surv_V_T <- function(T) pmax(exp(-7 * mu_V_T(T)), SURV_MIN)

#' Eggs per female per day — EFD(T)
#' Quadratic.
EFD_T <- function(T) quadratic(T, c=8.56e-3, T_min=14.58, T_max=34.61)

#' Larval-to-adult maturation rate — MDR(T) [per day]
#' Briere (mosquito development rate).
MDR_T <- function(T) briere(T, c=1.00e-4, T_min=14.58, T_max=34.61)

#' Probability of egg/larva survival to adult — pEA(T)
#' Quadratic. Represents combined survival across aquatic stages.
pEA_T <- function(T) quadratic(T, c=5.99e-3, T_min=13.56, T_max=38.29)

# ── Derived quantities ────────────────────────────────────────────────────────

#' Basic reproduction number R0(T) for dengue — Ae. aegypti
#' R0 = a² * b * c * exp(-mu/PDR) * lf / (N_H * gamma_H)
#' Proportional form (Mordecai 2017 Eq. 1):
R0_dengue_T <- function(T, gamma_H = 7/5) {
  a   <- a_T(T)
  b   <- b_T(T)
  cv  <- c_T(T)
  pdr <- PDR_T(T)
  mu  <- mu_V_T(T)
  lf  <- lf_T(T)
  surv_eip <- exp(-mu / pmax(pdr, 1e-9))  # prob mosquito survives EIP
  sqrt(a^2 * b * cv * surv_eip * lf / gamma_H)  # proportional R0
}

#' Weekly recruitment rate of new adult mosquitoes from aquatic stage
#' = maturation rate × aquatic survival probability × 7 days
weekly_recruits_per_larva <- function(T) {
  MDR_T(T) * pEA_T(T) * 7
}

# ── Verification: print key values at mean Rawalpindi temperature ─────────────
if (interactive() || sys.nframe() == 0) {
  T_mean <- 21.9   # mean annual temperature, Rawalpindi
  cat("=== Thermal Functions at T =", T_mean, "°C (mean Rawalpindi) ===\n")
  cat(sprintf("  Biting rate a(T)        = %.4f bites/day\n",          a_T(T_mean)))
  cat(sprintf("  Transmission b(T)       = %.4f (mosq→human)\n",       b_T(T_mean)))
  cat(sprintf("  Transmission c(T)       = %.4f (human→mosq)\n",       c_T(T_mean)))
  cat(sprintf("  PDR(T)                  = %.5f /day  → EIP=%.1f days\n",
              PDR_T(T_mean), 1/max(PDR_T(T_mean),1e-9)))
  cat(sprintf("  Adult lifespan lf(T)    = %.1f days\n",                lf_T(T_mean)))
  cat(sprintf("  Weekly survival surv(T) = %.3f\n",                     surv_V_T(T_mean)))
  cat(sprintf("  Eggs/female/day EFD(T)  = %.3f\n",                     EFD_T(T_mean)))
  cat(sprintf("  Larval maturation MDR(T)= %.5f /day\n",                MDR_T(T_mean)))
  cat(sprintf("  Larval survival pEA(T)  = %.3f\n",                     pEA_T(T_mean)))
  cat(sprintf("  Proportional R0(T)      = %.4f (arbitary units)\n",    R0_dengue_T(T_mean)))
  cat("\n=== Thermal optima (where each function peaks) ===\n")
  T_grid <- seq(10, 40, 0.1)
  cat(sprintf("  Peak a(T)   at T = %.1f°C\n", T_grid[which.max(a_T(T_grid))]))
  cat(sprintf("  Peak b(T)   at T = %.1f°C\n", T_grid[which.max(b_T(T_grid))]))
  cat(sprintf("  Peak c(T)   at T = %.1f°C\n", T_grid[which.max(c_T(T_grid))]))
  cat(sprintf("  Peak PDR(T) at T = %.1f°C\n", T_grid[which.max(PDR_T(T_grid))]))
  cat(sprintf("  Peak lf(T)  at T = %.1f°C\n", T_grid[which.max(lf_T(T_grid))]))
  cat(sprintf("  Peak R0(T)  at T = %.1f°C\n", T_grid[which.max(R0_dengue_T(T_grid))]))
  cat("\n✓ 00_Thermal_Functions.R sourced OK\n")
} else {
  cat("00_Thermal_Functions.R sourced OK\n")
}
