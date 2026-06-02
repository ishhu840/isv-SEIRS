################################################################################
# 09_Fig4_Efficacy_v3_Cropped.R
# PURPOSE: Improved violin figure — zoomed y-axis removes 0–30% dead space.
#          Original POSTER_Fig4_Efficacy_v2.png is NOT overwritten.
################################################################################
suppressPackageStartupMessages({
  library(dplyr); library(ggplot2)
})

res_file <- "../03_Results/MonteCarlo_Efficacy_N2000.csv"
if (!file.exists(res_file)) {
  stop("Run 07_Fig4_Efficacy_Violin.R first to generate the Monte Carlo cache.")
}

df4 <- read.csv(res_file)
df4$Timing <- factor(df4$Timing,
  levels = c("March","April","May","June","July","August"))

# ── Summarise ─────────────────────────────────────────────────────────────────
df4s <- df4 %>%
  filter(Year != 2013) %>%   # match the violin geom which excludes 2013
  group_by(Timing) %>%
  summarise(
    Med   = median(Reduction),
    CI_lo = quantile(Reduction, 0.025),
    CI_hi = quantile(Reduction, 0.975),
    Max_v = max(Reduction, na.rm=TRUE),   # actual violin top
    .groups = "drop"
  ) %>%
  mutate(
    Lbl_Med  = sprintf("%.1f%%", Med),
    Lbl_CI   = sprintf("[%.1f\u2013%.1f%%]", CI_lo, CI_hi),
    label_y  = pmin(Max_v + 4, 103)       # 4pt above the violin top
  )

cat("=== Violin summary (cropped figure) ===\n")
print(df4s)

# ── Colour palette: gradient from deep green (early) to amber (late) ─────────
timing_cols <- c(
  March  = "#1B7C4B",   # deep green — best timing
  April  = "#2EAA6A",
  May    = "#85C441",
  June   = "#F0B429",   # amber — weakening
  July   = "#E07B2B",
  August = "#C0392B"    # red — latest/worst
)

BF <- "sans"

PT <- theme_minimal(base_size = 16, base_family = BF) +
  theme(
    plot.title    = element_text(size = 21, face = "bold", margin = margin(b = 6)),
    plot.subtitle = element_text(size = 12, colour = "grey40", margin = margin(b = 14)),
    plot.caption  = element_text(size = 11, colour = "#1A5C9B", face = "bold.italic", hjust = 0),
    axis.title    = element_text(size = 15, face = "bold"),
    axis.text     = element_text(size = 13, face = "bold", colour = "grey20"),
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(colour = "grey91", linewidth = 0.4),
    plot.background   = element_rect(fill = "white", colour = NA),
    panel.background  = element_rect(fill = "white", colour = NA),
    plot.margin       = margin(20, 32, 18, 28),
    legend.position   = "none"
  )

p4v3 <- ggplot(df4 %>% filter(Year != 2013), aes(x = Timing, y = Reduction, fill = Timing, colour = Timing)) +
  # Violin
  geom_violin(alpha = 0.55, trim = TRUE, width = 0.72, adjust = 2.5,
               colour = NA) +
  # Boxplot on top
  geom_boxplot(width = 0.11, outlier.shape = NA,
               colour = "white", fill = "white",
               linewidth = 0.7, alpha = 0.85) +
  # Median label — ABOVE each violin (above CI_hi)
  geom_label(data = df4s,
    aes(x = Timing, y = label_y, label = Lbl_Med),
    fill = "white", colour = "grey10",
    size = 5.2, fontface = "bold", family = BF,
    label.r = unit(0.18, "lines"), label.padding = unit(0.3, "lines"),
    label.size = 0.35,
    vjust = 0,
    inherit.aes = FALSE) +
  # CI label — BOTTOM just above 20% baseline
  geom_text(data = df4s,
    aes(x = Timing, y = 21.5, label = Lbl_CI),
    colour = "grey35", size = 4.0, fontface = "italic", family = BF,
    vjust = 0,
    inherit.aes = FALSE) +
  scale_fill_manual(values = timing_cols)   +
  scale_colour_manual(values = timing_cols) +
  scale_x_discrete(labels = c(
    March = "March\n(Pre-monsoon)", April = "April", May = "May",
    June = "June", July = "July", August = "August\n(Post-onset)"
  )) +
  scale_y_continuous(
    limits = c(20, 108),
    breaks = seq(20, 100, 10),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0.01))
  ) +
  labs(
    title   = sprintf("Early Release is Critical: March Reduces Cases by %s", df4s$Lbl_Med[df4s$Timing == "March"]),
    subtitle = paste0(
      "Monte Carlo uncertainty (N\u202f=\u202f24,000) | \u03b5\u2009\u223c\u2009U(0.65, 0.95) | ",
      "2013\u20132024 Rawalpindi weather | Box\u2009=\u2009IQR | Whiskers\u2009=\u200995% CI"
    ),
    x       = "ISV Release Timing",
    y       = "Annual Case Reduction (%)",
    caption = paste0(
      "Pre-monsoon (March) male-only release [N\u202f=\u202f25,000] provides robust >90% reduction across normal climate years. ",
      "Colour gradient: green (best) \u2192 red (latest/worst timing)."
    )
  ) +
  PT

OUT_FIG <- "../02_Figures"
dir.create(OUT_FIG, showWarnings = FALSE)
ggsave(file.path(OUT_FIG, "POSTER_Fig4_Efficacy_v3.png"),
       p4v3, width = 11, height = 8, dpi = 300, bg = "white")
cat("Saved: POSTER_Fig4_Efficacy_v3.png (cropped to 30%, colour-coded)\n")
