################################################################################
# 13b_PRCC_Replot.R — Replot PRCC tornado from existing results
# Updates the x-axis to start at -0.25 so smaller bars are more visible.
################################################################################
suppressPackageStartupMessages({ library(ggplot2); library(dplyr) })

prcc_df <- read.csv("../03_Results/PRCC_Sensitivity_Results.csv", check.names=FALSE)
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
  geom_col(width = 0.65, alpha = 0.75, colour = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%+.3f %s", PRCC, Significant),
                hjust = ifelse(PRCC > 0, -0.10, 1.10)),
            size = 4.6, fontface = "bold", colour = "grey15", family = BF) +
  scale_fill_manual(values = c("Increases efficacy" = "#8FC9A5",   # soft sage green
                               "Decreases efficacy" = "#E8A8A0")) + # soft coral
  scale_x_continuous(limits = c(-0.25, 1.10), breaks = seq(-0.25, 1.00, 0.25),
                     expand = expansion(mult = c(0.02, 0.02))) +
  labs(
    title    = "Sensitivity of March Efficacy to Input Parameters (PRCC)",
    subtitle = "Latin Hypercube Sampling | N = 500 samples × 12 years | Output = annual case reduction (%)",
    x = "Partial Rank Correlation Coefficient (PRCC)",
    y = NULL,
    caption = "Dashed lines at ±0.2 = strong-influence threshold. *** p<0.01  * p<0.05  ns p≥0.05"
  ) + PT

ggsave("../02_Figures/POSTER_Fig6_PRCC_Sensitivity.png", p,
       width = 12, height = 7, dpi = 300, bg = "white")
cat("Saved: POSTER_Fig6_PRCC_Sensitivity.png (x-axis now starts at -0.25)\n")
