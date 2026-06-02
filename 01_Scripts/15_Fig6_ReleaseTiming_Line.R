################################################################################
# 15_Fig6_ReleaseTiming_Line.R
# Line-graph companion to the bar chart (Fig5).
# Single panel, two y-axes, but colour-identity is strict:
#   - Temperature line and its left axis    = orange
#   - R0_ISV line, its right axis, threshold = dark blue
#   - Dengue case curve (soft area)         = red
#   - Release dots colour-coded by efficacy outcome (green/orange/red)
# The R0_ISV = 1 threshold line is drawn in the same blue as the R0 curve so it
# unambiguously belongs to the right axis, not the left.
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

# --- Weekly climatology + outbreak season ------------------------------------
df_raw <- read_excel("../00_Data/D1_Weekly_Cases_Weather.xlsx") %>%
  filter(City == "Rawalpindi") %>% arrange(Year, Week) %>%
  rename(cases = `Number of Dengue Cases`)

weekly <- df_raw %>%
  group_by(Week) %>%
  summarise(
    T_mean = mean(Temperature, na.rm = TRUE),
    T_lo   = quantile(Temperature, 0.10, na.rm = TRUE),
    T_hi   = quantile(Temperature, 0.90, na.rm = TRUE),
    cases_mean = mean(cases, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(R0_ISV = R0_ISV_NGM(T_mean))

month_ticks <- data.frame(
  Week  = c(1, 5, 9, 14, 18, 23, 27, 31, 36, 40, 44, 49),
  Label = c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
)

# --- Release-timing efficacy -------------------------------------------------
df_mc <- read.csv("../03_Results/MonteCarlo_Efficacy_N2000.csv")
TIMING_WEEK <- c(March=10, April=14, May=18, June=23, July=27, August=31)

eff <- df_mc %>%
  group_by(Timing) %>%
  summarise(Med = median(Reduction), .groups = "drop") %>%
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

opt_start <- min(eff$Week[eff$Outcome == "Optimal (> 80%)"]) - 1.8
opt_end   <- max(eff$Week[eff$Outcome == "Optimal (> 80%)"]) + 1.8

peak_cases <- max(weekly$cases_mean, na.rm = TRUE)
outbreak_weeks <- weekly$Week[weekly$cases_mean > 0.25 * peak_cases]
outbreak_start <- min(outbreak_weeks); outbreak_end <- max(outbreak_weeks)

# --- Colour identity (used everywhere consistently) --------------------------
COL_TEMP  <- "#F39C12"   # orange  - temperature
COL_R0    <- "#1A5276"   # deep blue - R0_ISV
COL_CASES <- "#C0392B"   # red - dengue cases

# --- Dual-axis mapping --------------------------------------------------------
# Temperature on the left axis uses native degC values.
# R0_ISV on the right axis uses 0-1.5; we plot it as y = R0 * R0_SCALE.
# R0_SCALE is chosen so the visual range of R0 fills the same plot height
# as temperature (~10 to 36 degC). The R0=1 threshold falls at y = R0_SCALE.
TEMP_MIN <- 8;  TEMP_MAX <- 36
R0_MIN   <- 0;  R0_MAX   <- 1.5
R0_SCALE <- (TEMP_MAX - TEMP_MIN) / (R0_MAX - R0_MIN)
to_y     <- function(R0) TEMP_MIN + (R0 - R0_MIN) * R0_SCALE
from_y   <- function(y)  R0_MIN  + (y  - TEMP_MIN) / R0_SCALE

# Dengue cases drawn small at the very bottom (visual cue, no axis).
CASES_SCALE <- (TEMP_MIN + 5 - TEMP_MIN) / peak_cases   # peak reaches y = TEMP_MIN+5

BF <- "sans"
PT <- theme_minimal(base_size = 15, base_family = BF) +
  theme(
    plot.title       = element_text(size = 19, face = "bold"),
    plot.subtitle    = element_text(size = 12.5, colour = "grey40", margin = margin(b = 10)),
    plot.caption     = element_text(size = 11, colour = "#2255AA", face = "bold.italic", hjust = 0),
    axis.title.x     = element_text(size = 13, face = "bold"),
    axis.text        = element_text(size = 12, face = "bold", colour = "grey20"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(colour = "grey92", linewidth = 0.3),
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.4),
    plot.background  = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    legend.position  = "top",
    legend.title     = element_blank(),
    legend.text      = element_text(size = 12, colour = "grey25"),
    legend.margin    = margin(b = 6),
    plot.margin      = margin(20, 32, 18, 22)
  )

p <- ggplot(weekly, aes(x = Week)) +
  # Context bands
  annotate("rect", xmin = opt_start, xmax = opt_end, ymin = -Inf, ymax = Inf,
           fill = "#27AE60", alpha = 0.10) +
  annotate("rect", xmin = outbreak_start - 0.5, xmax = outbreak_end + 0.5,
           ymin = -Inf, ymax = Inf, fill = COL_CASES, alpha = 0.07) +

  # Temperature: ribbon + line (orange, left axis)
  geom_ribbon(aes(ymin = T_lo, ymax = T_hi), fill = COL_TEMP, alpha = 0.18) +
  geom_line(aes(y = T_mean, colour = "Weekly temperature (left axis)"),
            linewidth = 1.25) +

  # R0_ISV: line (deep blue, right axis)
  geom_line(aes(y = to_y(R0_ISV), colour = "R0_ISV per generation (right axis)"),
            linewidth = 1.7) +

  # R0_ISV = 1 threshold - drawn in the SAME BLUE as the R0 curve so it
  # unambiguously belongs to the right axis, not the temperature axis.
  geom_hline(yintercept = to_y(1), linetype = "dashed",
             colour = COL_R0, linewidth = 0.9) +
  annotate("label", x = 52, y = to_y(1),
           label = "R0_ISV = 1",
           colour = COL_R0, fontface = "bold", size = 4.0, hjust = 1,
           fill = "white", label.size = 0.6, label.r = unit(0.15, "lines")) +

  # Release-week markers (on R0_ISV curve) - show only the temperature at each dot
  geom_point(data = eff, aes(x = Week, y = to_y(R0_at), fill = Outcome),
             shape = 21, size = 7.5, stroke = 1.6, colour = "white") +
  geom_text(data = eff,
            aes(x = Week, y = to_y(R0_at) + 1.6,
                label = sprintf("%.1f°C", T_at)),
            size = 4.0, fontface = "bold", colour = "grey15") +

  # Band labels in clean white space (below temperature line)
  # Pushed to the right edge of the green band so it clears the early-March
  # temperature line jump on the left side of the band.
  annotate("text", x = opt_end + 1.5, y = TEMP_MIN + 2.0,
           label = "OPTIMAL RELEASE WINDOW",
           colour = "#1E8449", fontface = "bold", size = 3.9, hjust = 1) +
  annotate("text", x = (outbreak_start + outbreak_end)/2, y = TEMP_MIN + 2.0,
           label = "DENGUE OUTBREAK SEASON",
           colour = "#922B21", fontface = "bold", size = 3.9) +

  scale_x_continuous(breaks = month_ticks$Week, labels = month_ticks$Label,
                     limits = c(0.5, 52.5),
                     expand = expansion(mult = c(0.005, 0.005))) +
  scale_y_continuous(
    name = "Weekly mean temperature (°C)",
    limits = c(TEMP_MIN, TEMP_MAX + 1),
    breaks = seq(10, 35, 5),
    sec.axis = sec_axis(~ from_y(.), name = "R0_ISV (per-generation)",
                        breaks = seq(0, 1.5, 0.25)),
    expand = expansion(mult = c(0, 0.02))
  ) +
  scale_colour_manual(
    values = c("Weekly temperature (left axis)"      = COL_TEMP,
               "R0_ISV per generation (right axis)"  = COL_R0)
  ) +
  scale_fill_manual(values = outcome_cols, name = NULL) +
  guides(
    colour = guide_legend(order = 1, override.aes = list(linewidth = 1.4)),
    fill   = guide_legend(order = 2, override.aes = list(size = 5))
  ) +
  labs(
    title    = "When and why: temperature, R0_ISV and dengue outbreak vs release timing",
    subtitle = "Pre-monsoon (March-April) wins not because R0_ISV is highest then, but because CFAV gets months to spread before the outbreak.",
    x = "Month",
    caption = "Orange = weekly temperature (left axis). Blue = R0_ISV (right axis). Release dots are colour-coded by Monte Carlo efficacy outcome (green/orange/red) and labelled with the weekly mean temperature at release."
  ) +
  PT +
  theme(
    axis.title.y.left  = element_text(colour = COL_TEMP, face = "bold"),
    axis.title.y.right = element_text(colour = COL_R0,   face = "bold"),
    axis.text.y.left   = element_text(colour = COL_TEMP),
    axis.text.y.right  = element_text(colour = COL_R0)
  )

OUT <- "../02_Figures"
dir.create(OUT, showWarnings = FALSE)
ggsave(file.path(OUT, "POSTER_Fig6_ReleaseTiming_Line.png"),
       p, width = 14, height = 8, dpi = 300, bg = "white")
cat("Saved POSTER_Fig6_ReleaseTiming_Line.png\n")
