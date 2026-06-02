suppressPackageStartupMessages({library(ggplot2);library(dplyr)})
BF  <- "sans"
OUT <- "../02_Figures"

PT <- theme_minimal(base_size=16, base_family=BF) +
  theme(
    plot.title   = element_text(size=22,face="bold",margin=margin(b=6)),
    plot.subtitle= element_text(size=13,colour="grey40",margin=margin(b=14)),
    plot.caption = element_text(size=11,colour="#2255AA",face="bold.italic",hjust=0),
    axis.title   = element_text(size=16,face="bold"),
    axis.text    = element_text(size=13,face="bold",colour="grey20"),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour="grey90",linewidth=0.5),
    plot.background  = element_rect(fill="white",colour=NA),
    panel.background = element_rect(fill="white",colour=NA),
    plot.margin = margin(24,32,18,28),
    legend.position  = "top",
    legend.title     = element_blank(),
    legend.text      = element_text(size=14, face="plain", family=BF, colour="grey20"),
    legend.margin    = margin(b = 10)
  )

# ── CFAV ISV Parameters [Baidaliuk et al. 2019, mBio] ───────────────────────
NU_M  <- 0.93   # maternal vertical transmission probability
NU_P  <- 0.76   # paternal vertical transmission probability
NU_V  <- 0.31   # venereal (sexual) transmission probability
# Combined paternal+venereal cascade (Baidaliuk 2019, eq. derived):
# If female is uninfected and mates with infected male:
#   - With prob NU_P: paternal route succeeds
#   - With prob (1-NU_P)*NU_V*NU_M: venereal then maternal amplification
NU_PV <- NU_P + (1 - NU_P) * NU_V * NU_M  # = 0.8259

# ── Per-Generation Next-Generation Matrix R0_ISV ─────────────────────────────
#
# REFERENCES:
#   Diekmann O, Heesterbeek JAP, Metz JAJ (1990). J. Math. Biology 28:365-382.
#   Caspari E, Watson GS (1959). Evolution 13:568-570. (vertical symbiont dyn.)
#   Turelli M (1994). Evolution 48:1500-1513. (Wolbachia frequency dynamics)
#
# FRAMEWORK (per-generation, dimensionless):
#
#   Each NGM entry K_ij counts the EXPECTED FRACTION of next-generation type-i
#   individuals produced by one type-j individual, in a population near zero
#   prevalence (invasion analysis).
#
#   Under replacement dynamics (each mosquito produces ~1 surviving offspring of
#   each sex in a stable population), the entries are pure probabilities:
#
#   K_FF = nu_M               (infected ♀ → infected ♀ via maternal route)
#   K_FM = nu_PV              (infected ♂ → infected ♀ via paternal+venereal)
#   K_MF = nu_M               (infected ♀ → infected ♂ via maternal route)
#   K_MM = nu_P               (infected ♂ → infected ♂ via paternal route)
#
#   Temperature enters via survival-to-reproduction:
#   P_repro(T) = exp(-gono_days / lf(T))
#   where gono_days = 4 (one full gonotrophic cycle, conservative)
#
#   R0(T) = P_repro(T) × rho(K)  where rho is the dominant eigenvalue
#
# This formulation matches the Wolbachia/symbiont literature, is dimensionally
# consistent (K entries are probabilities, R0 is dimensionless), and gives
# biologically interpretable values near the establishment threshold.
#
lf_T  <- function(T) pmax(-0.148*T^2 + 8.78*T - 110, 0.001)  # Adult lifespan (days)

GONO_DAYS <- 4  # gonotrophic cycle: days needed from emergence to first egg batch

R0_ISV_NGM <- function(T) {
  # Survival-to-reproduction factor (dimensionless, ≤ 1)
  P_repro <- exp(-GONO_DAYS / lf_T(T))
  # Per-generation NGM entries (all probabilities, dimensionless)
  K11 <- NU_M    # infected ♀ → infected ♀ offspring (maternal)
  K12 <- NU_PV   # infected ♂ → infected ♀ offspring (paternal + venereal)
  K21 <- NU_M    # infected ♀ → infected ♂ offspring (maternal)
  K22 <- NU_P    # infected ♂ → infected ♂ offspring (paternal)
  tr_K  <- K11 + K22
  det_K <- K11*K22 - K12*K21
  disc  <- pmax(tr_K^2 - 4*det_K, 0)
  rho_K <- (tr_K + sqrt(disc)) / 2
  P_repro * rho_K   # temperature-dependent per-generation R0
}

temps  <- seq(14, 40, 0.2)
Tc_val <- uniroot(function(T) R0_ISV_NGM(T) - 1, lower=17, upper=24)$root
R0_rp  <- R0_ISV_NGM(21.9)
R0_max <- max(R0_ISV_NGM(temps))

cat(sprintf("NGM R0_ISV at Rawalpindi mean T (21.9C) = %.3f\n", R0_rp))
cat(sprintf("Threshold temperature Tc = %.2f C\n", Tc_val))
cat(sprintf("Maximum R0_ISV = %.3f at optimal T\n", R0_max))

df3 <- data.frame(T=temps, R0=R0_ISV_NGM(temps))

rect_df <- data.frame(
  xmin = c(14, Tc_val, 18.8),
  xmax = c(Tc_val, 40, 23.1),
  ymin = c(0, 0, 0),
  ymax = c(Inf, Inf, Inf),
  Zone = factor(c("Fails (R\u2080 < 1)", "Establishes (R\u2080 \u2265 1)", "March Release Window"),
                levels = c("Fails (R\u2080 < 1)", "March Release Window", "Establishes (R\u2080 \u2265 1)"))
)

p3 <- ggplot(df3, aes(x=T, y=R0)) +
  geom_rect(data=rect_df, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, fill=Zone),
            alpha=0.12, inherit.aes=FALSE) +
  scale_fill_manual(values = c("Fails (R\u2080 < 1)" = "#E74C3C",
                               "March Release Window" = "#3498DB",
                               "Establishes (R\u2080 \u2265 1)" = "#27AE60")) +
  geom_hline(yintercept=1, linetype="dashed", linewidth=1.2, colour="grey30") +
  geom_line(linewidth=1.5, colour="#2C3E50") +
  geom_vline(xintercept=Tc_val, linetype="dotted", linewidth=1.3, colour="#E74C3C") +
  annotate("point", x=21.9, y=R0_rp,
           shape=21, size=8, fill="#FF6D01", colour="white", stroke=2.5) +
  annotate("text",
           x     = 21.9 + 0.5,
           y     = R0_rp,
           hjust = 0, size=5.5, fontface="plain",
           colour="#FF6D01", family=BF,
           label = paste0("21.9\u00b0C\nR\u2080_ISV = ", round(R0_rp,2))) +
  annotate("label",
           x     = Tc_val - 0.2,
           y     = 2.0,
           hjust = 1, size=5.5, fontface="bold",
           colour="#E74C3C", family=BF,
           fill  = "white", label.size = 0,
           label = paste0("Tc = ", round(Tc_val,1), "\u00b0C")) +
  scale_x_continuous(breaks=seq(14,40,4),
                     labels=function(x) paste0(x,"\u00b0C")) +
  scale_y_continuous(limits=c(0, R0_max*1.12),
                     expand=expansion(mult=c(0,0.02))) +
  guides(fill = guide_legend(override.aes = list(alpha = 0.5))) +
  labs(
    title   = "CFAV Establishes Above the Critical Temperature in Rawalpindi",
    subtitle= paste0("Per-generation R\u2080_ISV via Next-Generation Matrix [Diekmann 1990; Turelli 1994] | ",
                     "All 3 CFAV routes [\u03bd_M=0.93, \u03bd_P=0.76, \u03bd_V=0.31, Baidaliuk 2019] | ",
                     "Tc=",round(Tc_val,1),"\u00b0C"),
    x=paste0("Ambient Temperature (\u00b0C)"),
    y=expression(bold(R[0]^ISV)),
    caption=paste0("R\u2080_ISV = dominant eigenvalue of the 2\u00d72 per-generation NGM K, ",
                   "scaled by mosquito survival to reproductive age. ",
                   "Dimensionless; R\u2080>1 implies CFAV establishes.")
  ) + PT

dir.create(OUT, showWarnings = FALSE)
ggsave(file.path(OUT,"POSTER_Fig3_R0ISV.png"), p3, width=13, height=8, dpi=300, bg="white")
cat("Generated POSTER_Fig3_R0ISV.png with complete NGM R0_ISV formula\n")
