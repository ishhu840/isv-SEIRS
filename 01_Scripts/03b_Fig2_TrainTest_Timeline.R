suppressPackageStartupMessages({
  library(dplyr); library(readxl); library(ggplot2); library(scales)
})

source("00_Coupled_Engine.R")   # Testing_Study: coupled bidirectional engine
source("00_SEIR_Engine.R")

BF <- "sans"
PT <- theme_minimal(base_size = 14, base_family = BF) +
  theme(
    plot.title        = element_text(size = 20, face = "bold", family = BF, margin = margin(b = 6)),
    plot.subtitle     = element_text(size = 14, colour = "grey40", family = BF, margin = margin(b = 14)),
    axis.title        = element_text(size = 14, face = "bold", family = BF),
    axis.text         = element_text(size = 12, face = "bold", colour = "grey20"),
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(colour = "grey90", linewidth = 0.5),
    plot.background   = element_rect(fill = "white", colour = NA),
    panel.background  = element_rect(fill = "white", colour = NA)
  )

params_df <- read.csv("../03_Results/SEIR_optimal_params.csv")
RAIN_LAG  <- params_df$rain_lag
TEMP_LAG  <- params_df$temp_lag
p_exact   <- as.numeric(params_df[, c("log_kappa","b0","bR","bT","bT2",
                                      "logit_rho","log_lambda","logit_E0f","logit_I0f")])

df_raw <- read_excel("../00_Data/D1_Weekly_Cases_Weather.xlsx") %>%
  filter(City == "Rawalpindi") %>% arrange(Year, Week) %>%
  rename(cases = `Number of Dengue Cases`) %>%
  mutate(Nh = case_when(
    Year <= 2017 ~ 2100000 * (1 + 0.0252)^(Year - 2013),
    TRUE         ~ 2430423 * (1 + 0.0252)^(Year - 2017)
  ))

train_mask <- df_raw$Year <= 2022
test_mask  <- df_raw$Year >= 2023

df_all <- prepare_data(df_raw, RAIN_LAG, TEMP_LAG, train_mask)
sim    <- run_coupled(p_exact, df_all, RAIN_LAG, TEMP_LAG, p_ISV_vec=NULL, eps=0)

df_plot <- df_raw %>%
  mutate(
    Index = row_number(),
    Obs   = cases,
    Pred  = sim$pred,
    Period = ifelse(train_mask, "Training (2013-2022)", "Testing (2023-2024)")
  )

# Calculate metrics including RMSE and NSE
metrics <- df_plot %>%
  group_by(Period) %>%
  summarise(
    r = cor(Obs, Pred, use = "complete.obs"),
    MAE = mean(abs(Obs - Pred), na.rm = TRUE),
    RMSE = sqrt(mean((Obs - Pred)^2, na.rm = TRUE)),
    NSE = 1 - (sum((Obs - Pred)^2, na.rm = TRUE) / sum((Obs - mean(Obs, na.rm = TRUE))^2, na.rm = TRUE))
  )
print(metrics)

# Advanced styling with ribbons and professional aesthetics
qticks <- df_plot %>%
  group_by(Year) %>% slice(1) %>% ungroup() %>%
  mutate(Lbl = as.character(Year))

split_index <- max(df_plot$Index[df_plot$Year == 2022]) + 0.5
max_index   <- max(df_plot$Index)

p <- ggplot(df_plot, aes(x = Index)) +
  # Background shading for the testing period
  annotate("rect", xmin = split_index, xmax = max_index, ymin = -Inf, ymax = Inf, 
           fill = "#3498DB", alpha = 0.08) +
  # Observed cases as solid bars
  geom_col(aes(y = Obs, fill = Period), width = 1, alpha = 0.85, colour = NA) +
  # Prediction shading
  geom_ribbon(aes(ymin = pmin(Obs, Pred), ymax = pmax(Obs, Pred), fill = "Prediction Error Gap"),
              alpha = 0.15) +
  # Prediction line
  geom_line(aes(y = Pred, colour = "Model Prediction"), linewidth = 1.2) +
  # Split line
  geom_vline(aes(xintercept = split_index, colour = "Train/Test Split"), 
             linetype = "twodash", linewidth = 1.2) +
  
  # Custom, explicit colors and legend
  scale_fill_manual(
    values = c("Training (2013-2022)" = "#A0AAB5", 
               "Testing (2023-2024)"  = "#2980B9",
               "Prediction Error Gap" = "#34495E"),
    name = "Data & Shading:"
  ) +
  scale_colour_manual(
    values = c("Model Prediction" = "#1A252F", 
               "Train/Test Split" = "#C0392B"),
    name = "Model Overlays:"
  ) +
  
  # Annotations for metrics — placed in the top left and right
  annotate("label",
           x = 5, y = 1250, hjust = 0, vjust = 1,
           label = sprintf(
             "TRAINING (2013\u20132022)\nr\u202f=\u202f%.3f   |   NSE\u202f=\u202f%.3f\nMAE\u202f=\u202f%.0f cases/wk   |   RMSE\u202f=\u202f%.0f",
             metrics$r[2], metrics$NSE[2], metrics$MAE[2], metrics$RMSE[2]),
           fill = "white", colour = "grey20", fontface = "plain",
           family = BF, size = 4.3, label.padding = unit(0.4, "lines"),
           label.r = unit(0.2, "lines")) +
  annotate("label",
           x = max_index - 2,
           y = 1250, hjust = 1, vjust = 1,
           label = sprintf(
             "TESTING (2023\u20132024)\nr\u202f=\u202f%.3f   |   NSE\u202f=\u202f%.3f\nMAE\u202f=\u202f%.0f cases/wk   |   RMSE\u202f=\u202f%.0f",
             metrics$r[1], metrics$NSE[1], metrics$MAE[1], metrics$RMSE[1]),
           fill = "#EBF5FB", colour = "#1A6FAF", fontface = "plain",
           family = BF, size = 4.3, label.padding = unit(0.4, "lines"),
           label.r = unit(0.2, "lines")) +
  # Axes
  scale_x_continuous(breaks = qticks$Index, 
                     labels = qticks$Lbl,
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0))) +
  coord_cartesian(ylim = c(0, 1300)) +
  labs(
    title = "SEIR Continuous Model Fit: Proving Predictive Power via Lag Optimization",
    subtitle = "Comparing model accuracy between trained historical data and unseen future outbreaks",
    x = "Timeline (Years)",
    y = "Weekly Dengue Cases"
  ) +
  PT + 
  theme(
    legend.position = "top",
    legend.box = "horizontal",
    legend.justification = "center",
    legend.margin = margin(b = 10),
    axis.text.x = element_text(angle=0, hjust=0.5, vjust=1)
  )

dir.create("../02_Figures", showWarnings = FALSE)
ggsave("../02_Figures/POSTER_Fig2b_TrainTest_Combined.png", p, width = 16, height = 7, dpi = 300, bg = "white")
ggsave("/Users/ishtiaq/.gemini/antigravity/brain/0c1ca6ed-e859-4d3b-98ca-121a0325dbaa/POSTER_Fig2b_TrainTest_Combined.png", p, width = 16, height = 7, dpi = 300, bg = "white")

cat("Done\n")
