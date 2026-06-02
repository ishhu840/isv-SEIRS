suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(readxl); library(scales)
})

cat("=== Generating POSTER_Fig1_Burden.png ===\n")

BF <- "sans"
PT <- theme_minimal(base_size = 16, base_family = BF) +
  theme(
    plot.title        = element_text(size = 22, face = "bold", family = BF,
                                     margin = margin(b = 6)),
    plot.subtitle     = element_text(size = 14, colour = "grey40", family = BF,
                                     margin = margin(b = 14)),
    plot.caption      = element_text(size = 12, colour = "#2255AA",
                                     face = "bold.italic", hjust = 0, family = BF),
    axis.title        = element_text(size = 16, face = "bold", family = BF),
    axis.text         = element_text(size = 14, face = "bold", colour = "grey20"),
    legend.title      = element_text(size = 15, face = "bold", family = BF),
    legend.text       = element_text(size = 14, family = BF),
    legend.position   = "bottom",
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(colour = "grey90", linewidth = 0.5),
    plot.background   = element_rect(fill = "white", colour = NA),
    panel.background  = element_rect(fill = "white", colour = NA),
    plot.margin       = margin(24, 28, 18, 24)
  )

DATA_PATH <- "../00_Data/D1_Weekly_Cases_Weather.xlsx"

df_raw <- read_excel(DATA_PATH) %>%
  filter(City == "Rawalpindi") %>%
  arrange(Year, Week)

df_ann <- df_raw %>%
  group_by(Year) %>%
  summarise(Cases = sum(`Number of Dengue Cases`, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    Period = ifelse(Year <= 2022, "Training (2013-2022)", "Testing (2023-2024)"),
    MA3    = stats::filter(Cases, rep(1/3, 3), sides = 2) %>% as.numeric()
  )

peak_yr  <- df_ann$Year[which.max(df_ann$Cases)]
peak_cas <- max(df_ann$Cases)

p1 <- ggplot(df_ann, aes(x = Year, y = Cases, fill = Period)) +
  geom_col(colour = "white", linewidth = 0.5, width = 0.72) +
  geom_text(
    data = df_ann %>% filter(Cases > 2500),
    aes(y = Cases + 180, label = comma(Cases)),
    size = 5.5, fontface = "bold", colour = "grey20", family = BF
  ) +
  annotate("text", x = 2013.3, y = peak_cas * 0.92,
           label = "Total: 26,994 confirmed cases\nRawalpindi 2013-2024",
           hjust = 0, size = 6, fontface = "bold", colour = "grey15", family = BF) +
  scale_fill_manual(
    values = c("Training (2013-2022)" = "#7B99CB",
               "Testing (2023-2024)"  = "#E86A58"),
    name = NULL
  ) +
  scale_x_continuous(breaks = 2013:2024) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.14))) +
  labs(
    title    = "Escalating Dengue Burden - Rawalpindi, Pakistan",
    subtitle = "Annual confirmed cases | Blue bars = training period | Red bars = test period",
    x = "Year", y = "Confirmed Dengue Cases"
  ) +
  PT +
  theme(
    legend.position = c(0.02, 0.97),
    legend.justification = c(0, 1),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

OUT_DIR <- "../02_Figures"
dir.create(OUT_DIR, showWarnings = FALSE)

ggsave(file.path(OUT_DIR, "POSTER_Fig1_Burden.png"), p1, width = 12, height = 8, dpi = 300, bg = "white")
ggsave("/Users/ishtiaq/.gemini/antigravity-ide/brain/cfc319e1-f47b-4462-b409-79bdc3f1beaa/POSTER_Fig1_Burden.png", p1, width = 12, height = 8, dpi = 300, bg = "white")

cat("Saved: POSTER_Fig1_Burden.png\n")
