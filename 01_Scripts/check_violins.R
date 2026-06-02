df <- read.csv("../03_Results/MonteCarlo_Efficacy_N2000.csv")
cat("Summary of March reductions:\n")
summary(df$Reduction[df$Timing=="March"])

cat("\nSummary of all reductions:\n")
summary(df$Reduction)

# Look at the bottom 10%
cat("\nBottom 5% of March reductions:\n")
head(sort(df$Reduction[df$Timing=="March"]), 20)
