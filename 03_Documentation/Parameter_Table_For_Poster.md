# Parameter Table for Poster / Paper Results Section

## Table 1. Model Parameters

| Parameter (Symbol) [Ref] | Value (Unit) — Source |
| :--- | :--- |
| **FITTED — via Nelder-Mead on 2013–2022 training data** | |
| Transmission scaling ($\kappa$) | 126.23 (dimensionless) — Fitted |
| Reporting fraction ($\rho$) | 0.196 (probability) — Fitted, bounded 15–25% [6] |
| Baseline coefficient ($b_0$) | −5.05 (dimensionless) — Fitted |
| Rainfall coefficient ($b_R$) | 0.190 (per z-score) — Fitted |
| Temperature coefficient ($b_T$) | 1.990 (per z-score) — Fitted |
| Temperature quadratic ($b_{T^2}$) | −1.167 (per z-score²) — Fitted, constrained negative [3] |
| Rainfall lag | 7 (weeks) — Grid search, max train $r$ |
| Temperature lag | 6 (weeks) — Grid search, max train $r$ |
| **FIXED — Human Epidemiology** | |
| Human incubation ($1/\sigma_H$) [1] | 6 (days) — WHO standard |
| Human infectious period ($1/\gamma_H$) [1] | 5 (days) — WHO standard |
| Waning immunity ($1/\omega$) [1] | 5 (years) — Multi-serotype assumption |
| Background mortality ($1/\mu_H$) | 68 (years) — Pakistan census |
| Human population ($N_H$, 2017) | 2.32 (million) — Rawalpindi city census |
| Importation rate ($\lambda$) [5] | 5 (cases/week) — Travel-driven, Wesolowski 2015 |
| **FIXED — Mosquito Vector Biology (Mordecai 2017)** | |
| Biting rate $a(T)$ [3] | Briere curve (bites/day) — Mordecai 2017 |
| Transmission probabilities $b(T), c(T)$ [3] | Quadratic curves (probability) — Mordecai 2017 |
| Extrinsic incubation $PDR(T)$ [3] | Briere curve (1/days) — Mordecai 2017 |
| Adult lifespan $lf(T)$ [3] | Quadratic, peak ~21 °C (days) — Mordecai 2017 |
| Fecundity $EFD(T)$ [3] | Quadratic curve (eggs/female/day) — Mordecai 2017 |
| Larval maturation $MDR(T)$ [3] | Briere curve (1/days) — Mordecai 2017 |
| Larval survival $pEA(T)$ [3] | Quadratic curve (probability) — Mordecai 2017 |
| Aquatic mortality ($\mu_A$) | 0.01 (per day) — Standard assumption |
| Overwintering survival floor | 0.20 (per week) — Urban heat-island assumption |
| **FIXED — Mosquito Ecology (Field Calibrated)** | |
| Carrying capacity ($K_0$) [7] | $1.0 \times 10^6$ (females) — Focks 1995, ratio 0.43/human |
| Rainfall–K coefficient ($k_R$) | 0.02 (per mm) — Field calibration |
| Initial wild females ($M_0$) [4] | 20,000 (females) — Overwintering estimate, Mukhtar 2011 |
| **FIXED — ISV (CFAV) Transmission (Baidaliuk 2019)** | |
| Maternal vertical ($\nu_M$) [2] | 0.93 (probability) — Baidaliuk 2019 |
| Paternal vertical ($\nu_P$) [2] | 0.76 (probability) — Baidaliuk 2019 |
| Venereal sexual ($\nu_V$) [2] | 0.31 (probability) — Baidaliuk 2019 |
| Combined paternal+venereal ($\nu_{PV}$) [2] | 0.829 (probability) — Derived from Baidaliuk |
| Blocking efficacy ($\varepsilon$) [2] | Beta(2,2) on [0.05, 0.95] — Monte Carlo, Baidaliuk CIs |
| **INTERVENTION DESIGN** | |
| Released CFAV-infected males ($N_{rel}$) | 25,000 (males) — Design, 1.25:1 release ratio |
| Release timing | Week 10 (early March) — Pre-monsoon optimization |
| Monte Carlo iterations | 24,000 per timing — 2,000 × 12 years |

---

## SHORT VERSION (Poster Space-Saving)

| Parameter (Symbol) [Ref] | Value (Unit) — Source |
| :--- | :--- |
| **Fitted via Nelder-Mead** | |
| Reporting fraction ($\rho$) | 0.196 (probability) — Fitted [6] |
| Transmission scaling ($\kappa$) | 126.23 (dimensionless) — Fitted |
| Climate coefficients ($b_0, b_R, b_T, b_{T^2}$) | −5.05, 0.19, 1.99, −1.17 — Fitted |
| Rainfall / temperature lags | 7 / 6 (weeks) — Grid search |
| **Fixed: Biological** | |
| Maternal / paternal / venereal CFAV ($\nu_M, \nu_P, \nu_V$) [2] | 0.93 / 0.76 / 0.31 (probabilities) — Baidaliuk 2019 |
| All thermal traits ($EFD, MDR, lf, PDR$, etc.) [3] | Briere / Quadratic curves — Mordecai 2017 |
| Importation rate ($\lambda$) [5] | 5 (cases/week) — Wesolowski 2015 |
| Incubation / infectious / immunity periods [1] | 6 / 5 (days), 5 (years) — WHO / Anderson & May |
| **Fixed: Ecological / Operational** | |
| Carrying capacity ($K_0$) [7] | $10^6$ (females) — Focks 1995 |
| Initial wild females ($M_0$) [4] | 20,000 (females) — Mukhtar 2011 |
| Released ISV males ($N_{rel}$) | 25,000 (males) — Design |
| ISV blocking efficacy ($\varepsilon$) [2] | Beta(2,2) on [0.05, 0.95] — Monte Carlo |

---

## References (Cited by Number)

1. **Anderson, R. M., & May, R. M. (1991).** *Infectious Diseases of Humans: Dynamics and Control.* Oxford University Press.
2. **Baidaliuk, A., et al. (2019).** Cell-Fusing Agent Virus Reduces Arbovirus Dissemination in *Aedes aegypti* Mosquitoes In Vivo. *Journal of Virology*, 93(18), e00705-19.
3. **Mordecai, E. A., et al. (2017).** Detecting the impact of temperature on transmission of Zika, dengue, and chikungunya using mechanistic models. *PLOS Neglected Tropical Diseases*, 11(4), e0005568.
4. **Mukhtar, M., et al. (2011).** Entomological investigations of dengue vectors in epidemic-prone districts of Pakistan. *Dengue Bulletin*, 35, 99–115.
5. **Wesolowski, A., et al. (2015).** Impact of human mobility on the emergence of dengue epidemics in Pakistan. *PNAS*, 112(38), 11887–11892.
6. **Bhatt, S., et al. (2013).** The global distribution and burden of dengue. *Nature*, 496(7446), 504–507.
7. **Focks, D. A., et al. (1995).** A simulation model of the epidemiology of urban dengue fever. *American Journal of Tropical Medicine and Hygiene*, 53(5), 489–506.
8. **Diekmann, O., Heesterbeek, J. A. P., & Metz, J. A. J. (1990).** On the definition and computation of the basic reproduction ratio $R_0$. *Journal of Mathematical Biology*, 28(4), 365–382.
9. **Marino, S., et al. (2008).** A methodology for performing global uncertainty and sensitivity analysis. *Journal of Theoretical Biology*, 254(1), 178–196. *(PRCC method)*
