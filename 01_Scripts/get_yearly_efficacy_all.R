source("10_Fig5_Yearly_Prevention_Facet.R")

get_cases <- function(rw) {
  sv_base <- rep(0, nrow(df_all))
  df_all$Baseline <- run_seir_isv(p_local, df_all, 7, 6, sv_base)
  df_all$ISV_Cases <- 0
  YEARS <- 2013:2024
  K0 <- 1e6; k_R_mosq <- 0.02; M0_F <- 20000; I0W_f <- 0.001
  N_rel_M <- 25000L
  eps_med <- 0.80

  for (yr in YEARS) {
    mask_yr <- df_all$Year == yr
    idx_yr <- which(mask_yr)
    T_yr <- df_raw$Temperature[mask_yr]
    R_lag <- c(rep(NA,7), df_raw$Rainfall[mask_yr][1:45])
    mosq <- simulate_mosquitoes(T_yr, R_lag, K0, k_R_mosq, rel_week=rw, N_rel_F=0L, N_rel_M=N_rel_M, M0_F=M0_F, I0W_f=I0W_f)
    p_ISV_yr <- mosq$p_ISV
    sv <- rep(0, nrow(df_all))
    for(w in 1:52) {
      if(!is.na(p_ISV_yr[w])) {
        sv[idx_yr[w]] <- eps_med * p_ISV_yr[w]
      }
    }
    pp <- run_seir_isv(p_local, df_all, 7, 6, sv)
    df_all$ISV_Cases[mask_yr] <- pp[mask_yr]
  }
  
  yr_sums <- aggregate(cbind(Baseline, ISV_Cases) ~ Year, data=df_all, sum)
  cases_prev = mean(yr_sums$Baseline - yr_sums$ISV_Cases)
  return(cases_prev)
}

cat("June (W23): ", get_cases(23), "\n")
cat("August (W31): ", get_cases(31), "\n")
