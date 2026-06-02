df_raw <- read.csv("../03_Results/MonteCarlo_Efficacy_N2000.csv")
march_res <- subset(df_raw, Timing == "March")
cat("Median March Reduction:", median(march_res$Reduction), "%\n")

# To get average cases prevented, we need the baseline cases vs ISV cases from Script 10
source("10_Fig5_Yearly_Prevention_Facet.R")
# df_all has Baseline and ISV_Cases for March release.
yr_sums <- aggregate(cbind(Baseline, ISV_Cases) ~ Year, data=df_all, sum)
yr_sums$Reduction <- 100 * (yr_sums$Baseline - yr_sums$ISV_Cases) / yr_sums$Baseline
cat("\nYearly March Reductions (%):\n")
print(yr_sums)

cat("\nAverage cases prevented per year:\n")
cat(mean(yr_sums$Baseline - yr_sums$ISV_Cases), "\n")
