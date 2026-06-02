################################################################################
# 14_Fig5_ReleaseTiming_Combined.R
# Single-panel "release timing" figure built around one bar chart, with all
# supporting context shown as background shading and per-bar labels.
#
# Y-axis  : Annual case reduction (%) — the actual result of interest
# X-axis  : Calendar week (Jan-Dec) — bars positioned at the six release weeks
# Bars    : Coloured by efficacy outcome (green = optimal, orange = marginal,
#           red = late). Error bars are Monte Carlo 95% CI.
# Labels  : Month + median %, and on a second line R0_ISV and temperature at
#           that release week.
# Bands   : Green = optimal release window. Red = dengue outbreak season.
# Reference line: 60% control target.
################################################################################
suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(ggplot2); library(scales)
})

source("00_Thermal_Functions.R")

NU_M <- 0.93; NU_P <- 0.76; NU_V <- 0.31
NU_PV <- NU_P + (1 - NU_P) * NU_V * NU_M
GONO_DAYS <- 4

R0_ISV_NGM <- function(T) {
  P_repro <- exp(-GONO_DAYS / lf_T(T))
  tr_K  <- NU_M + NU_P
  det_K <- NU_M*NU_P - NU_PV*NU_M
  disc  <- pmax(tr_K^2 - 4*det_K, 0)
  rho_K <- (tr_K + sqrt(disc)) / 2
  P_repro * rho_K
}

# --- Weekly climatology -----------------------------------------------------
df_raw <- read_excel("../00_Data/D1_Weekly_Cases_Weather.xlsx") %>%
  filter(City == "Rawalpindi") %>% arrange(Year, Week) %>%
  rename(cases = `Number of Dengue Cases`)

weekly <- df_raw %>%
  group_by(Week) %>%
  summarise(
    T_mean = mean(Temperature, na.rm = TRUE),
    cases_mean = mean(cases, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(R0_ISV = R0_ISV_NGM(T_mean))

month_ticks <- data.frame(
  Week  = c(1, 5, 9, 14, 18, 23, 27, 31, 36, 40, 44, 49),
  Label = c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
)

# --- Efficacy by release timing ---------------------------------------------
df_mc <- read.csv("../03_Results/MonteCarlo_Efficacy_N2000.csv")
TIMING_WEEK <- c(March=10, April=14, May=18, June=23, July=27, August=31)

eff <- df_mc %>%
  group_by(Timing) %>%
  summarise(
    Med   = median(Reduction),
    CI_lo = quantile(Reduction, 0.025),
    CI_hi = quantile(Reduction, 0.975),
    .groups = "drop"
  ) %>%
  mutate(
    Week   = TIMING_WEEK[Timing],
    Timing = factor(Timing, levels = c("March","April","May","June","July","August"))
  ) %>%
  arrange(Week) %>%
  mutate(
    R0_at = R0_ISV_NGM(weekly$T_mean[match(Week, weekly$Week)]),
    T_at  = weekly$T_mean[match(Week, weekly$Week)]
  )

eff$Outcome <- cut(eff$Med,
                   breaks = c(-Inf, 60, 80, Inf),
                   labels = c("Late (< 60%)",
                              "Marginal (60-80%)",
                              "Optimal (> 80%)"))
outcome_cols <- c("Optimal (> 80%)"   = "#1E8449",
                  "Marginal (60-80%)" = "#F39C12",
                  "Late (< 60%)"      = "#C0392B")

# --- Climate context zones --------------------------------------------------
opt_start <- min(eff$Week[eff$Outcome == "Optimal (> 80%)"]) - 1.8
opt_end   <- max(eff$Week[eff$Outcome == "Optimal (> 80%)"]) + 1.8

peak_cases <- max(weekly$cases_mean, na.rm = TRUE)
outbreak_weeks <- weekly$Week[weekly$cases_mean > 0.25 * peak_cases]
outbreak_start <- min(outbreak_weeks); outbreak_end <- max(outbreak_weeks)

BF <- "sans"
PT <- theme_minimal(base_size = 15, base_family = BF) +
  theme(
    plot.title       = element_text(size = 20, face = "bold"),
    plot.subtitle    = element_text(size = 13, colour = "grey40", margin = margin(b = 12)),
    plot.caption     = element_text(size = 11, colour = "#2255AA", face = "bold.italic", hjust = 0),
    axis.title       = element_text(size = 14, face = "bold"),
    axis.text        = element_text(size = 12, face = "bold", colour = "grey20"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.4),
    plot.background  = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    legend.position  = "top",
    legend.title     = element_blank(),
    legend.text      = element_text(size = 12, colour = "grey25"),
    legend.margin    = margin(b = 6),
    plot.margin      = margin(20, 30, 18, 22)
  )

p <- ggplot(eff, aes(x = Week, y = Med, fill = Outcome)) +
  # Background context bands
  annotate("rect", xmin = opt_start, xmax = opt_end, ymin = -Inf, ymax = Inf,
           fill = "#27AE60", alpha = 0.12) +
  annotate("rect", xmin = outbreak_start - 0.5, xmax = outbreak_end + 0.5,
           ymin = -Inf, ymax = Inf, fill = "#C0392B", alpha = 0.10) +

  # 60% control target reference line
  geom_hline(yintercept = 60, linetype = "dashed",
             colour = "grey45", linewidth = 0.7) +
  annotate("text", x = 51.8, y = 63,
           label = "60% control target",
           colour = "grey35", fontface = "italic", size = 3.6, hjust = 1) +

  # Bars + error bars
  geom_col(width = 3.0, alpha = 0.92, colour = "white", linewidth = 0.4) +
  geom_errorbar(aes(ymin = CI_lo, ymax = CI_hi),
                width = 1.4, linewidth = 0.7, colour = "grey25") +

  # Top label: month + efficacy
  geom_text(aes(y = pmin(Med + 6, 102),
                label = sprintf("%s\n%.0f%%", Timing, Med)),
            fontface = "bold", size = 4.6, colour = "grey10", lineheight = 0.95) +

  # Bottom label: R0 and temperature at release week
  geom_text(aes(y = -7,
                label = sprintf("R0=%.2f\n%.1fdegC", R0_at, T_at)),
            size = 3.6, colour = "grey30", lineheight = 0.95, fontface = "italic") +

  # Band labels (placed inside their bands, far from bars)
  annotate("text", x = (opt_start + opt_end)/2, y = 102,
           label = "OPTIMAL RELEASE WINDOW",
           colour = "#1E8449", fontface = "bold", size = 4.2) +
  annotate("text", x = (outbreak_start + outbreak_end)/2, y = 102,
           label = "DENGUE OUTBREAK SEASON",
           colour = "#922B21", fontface = "bold", size = 4.2) +
  annotate("text", x = (outbreak_start + outbreak_end)/2, y = 95,
           label = "monsoon peak Sep-Oct",
           colour = "#922B21", fontface = "italic", size = 3.5) +

  scale_x_continuous(breaks = month_ticks$Week, labels = month_ticks$Label,
                     limits = c(0.5, 52.5),
                     expand = expansion(mult = c(0.005, 0.005))) +
  scale_y_continuous(name = "Annual case reduction (%)",
                     limits = c(-14, 108),
                     breaks = seq(0, 100, 20),
                     labels = function(x) paste0(x, "%"),
                     expand = expansion(mult = c(0, 0))) +
  scale_fill_manual(values = outcome_cols, name = NULL) +
  labs(
    title    = "Pre-monsoon release (March-April) gives over 90% control",
    subtitle = "R0_ISV > 1 all summer, but only early releases give CFAV enough generations to build coverage before the outbreak.",
    x = "Calendar week (release timing)",
    caption = "Bars: median Monte Carlo case reduction with 95% CI, 25,000 CFAV-positive males released. R0_ISV and weekly mean temperature labelled below each bar."
  ) +
  PT

OUT <- "../02_Figures"
dir.create(OUT, showWarnings = FALSE)
ggsave(file.path(OUT, "POSTER_Fig5_ReleaseTiming_Combined.png"),
       p, width = 14, height = 8, dpi = 300, bg = "white")
cat("Saved POSTER_Fig5_ReleaseTiming_Combined.png (clean bar-chart design)\n")
