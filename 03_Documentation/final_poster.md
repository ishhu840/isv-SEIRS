# Weather-Driven SEIRS Modelling to Evaluate Insect-Specific Virus Interventions for Dengue Control: A Rawalpindi, Pakistan Case Study

## Introduction

Most of the world's population is at risk of DENGUE (400 million infections/year)¹. 

*(Note for poster assembly: Place Figure 1 and 2 here)*
**[INSERT IMAGE: Map of countries affected]**
**Figure 1:** Map of countries affected by dengue worldwide in 2023.
**[INSERT IMAGE: Mosquito species]**
**Figure 2:** Responsible mosquito species transmitting Dengue virus. A: *Aedes albopictus*, and B: *Aedes aegypti*.

### Background Context
*   Dengue virus is transmitted by *Aedes aegypti* & *Aedes albopictus* mosquitoes².
*   The virus causes severe Dengue Haemorrhagic Fever, and **no effective vaccine** is universally available.
*   In tropical climates, mosquitoes hatch between 20°C to 26°C and require high humidity.
*   In **Pakistan**, Dengue is endemic, peaking heavily during the Monsoon season (July to September).
*   Current Vector Control (Chemical Spray) is entirely reactive, happening *after* Dengue cases are already reported.

### The Research Question
What if early, targeted biological interventions could neutralize the vector *before* an outbreak? Can Insect-Specific Viruses (ISVs) be a useful solution via super-infection exclusion? Here, we use mathematical simulations to test the utility of ISVs in mosquitoes for reducing Dengue outbreaks.

### Objectives
1.  **To predict** climate-driven Dengue outbreaks via SEIRS modeling.
2.  **To neutralize** Dengue transmission via targeted ISV releases.

---

## Materials & Methodology

We developed a robust mathematical framework mechanically coupling 12 years of climate-driven human Dengue epidemiology with the temperature-dependent biological life-cycle of *Aedes aegypti* mosquitoes.

### Statistical Calibration & Data Acquisition

*   **Optimization Algorithm:** Evaluated 35 distinct climate lag combinations using the **Nelder-Mead Simplex Algorithm** to minimize the Root Mean Square Error (RMSE) against a strict training dataset (2013–2022).
*   **Statistical Validation:** To prevent data leakage, optimized models were rigorously validated out-of-sample against testing data (2023–2024) using **Pearson correlation ($r$)**. 
*   **Optimal Identification:** Statistically established a 7-week rainfall lag and a 6-week temperature lag as the optimal biological drivers of local Dengue transmission.

### Integrated Mathematical Framework

*(Note for poster assembly: Place Figure 2 below this sub-header)*
**[INSERT IMAGE: `../02_Figures/POSTER_Fig0_Integrated_Updated.png`]**
**Figure 2:** Integrated mathematical framework coupling climate-driven Human SEIRS dynamics with temperature-dependent vector life-cycles and ISV transmission pathways.

The full coupled vector-host system is defined by the following mechanistic equations:

#### 1. Host (Human) SEIRS Dynamics
Discrete-time transitions driven by weather-lagged infection force $E_{\text{new}}(t) = \beta_t \frac{S_t I_t}{N_t} (1 - \varepsilon \cdot p_{\text{ISV}}) + \lambda$:
$$
\begin{aligned}
S_{t+1} &= S_t - E_{\text{new}} + \omega R_t + \mu_H (N_t - S_t) \\
E_{t+1} &= E_t + E_{\text{new}} - (\sigma_H + \mu_H) E_t \\
I_{t+1} &= I_t + \sigma_H E_t - (\gamma_H + \mu_H) I_t \\
R_{t+1} &= R_t + \gamma_H I_t - (\omega + \mu_H) R_t
\end{aligned}
$$
*(Background human population $N_t$ scales at $2.1\%$ annually).*

#### 2. Climate-Driven Transmission Force ($\beta_t$)
Non-linear exponential function of standardized, optimal climate lags:
$$\beta_t = \kappa \exp(b_0 + b_R R_{t-5} + b_T T_{t-10} + b_{T^2} T_{t-10}^2)$$

#### 3. Aquatic Vector Limits ($A_t$)
Temperature-driven maturation ($G_t$) and rainfall-driven carrying capacity ($K_t$):
$$A_{t+1} = A_t + \text{EFD}(T_t) \cdot 7 N_{V,F} - G_t - \mu_A \cdot 7 A_t - \frac{A_t^2}{K_t}$$
*(Recruitment $G_t = \text{MDR} \cdot \text{pEA} \cdot 7 A_t$, carrying capacity $K_t = K_0 \exp(k_R R_{t-5})$).*

#### 4. Adult Mosquito Dynamics (Wild vs. ISV-Infected)
Parallel equations track wild vs. infected females ($S_W, N_I$), subject to an overwintering survival floor $\text{surv}_V = \max(\exp(-7/\text{lf}), 0.20)$:
$$
\begin{aligned}
S_{W, t+1} &= S_{W, t} \cdot \text{surv}_V + (1 - \nu_{\text{eff}}) \cdot 0.5 G_t \\
N_{I, t+1} &= N_{I, t} \cdot \text{surv}_V + \nu_{\text{eff}} \cdot 0.5 G_t
\end{aligned}
$$
*(Male dynamics are identical, but infected males $N_{MI}$ receive the $\text{Released}_M(t)$ interventions).*

#### 5. CFAV 3-Route Transmission Kinetics
Effective vertical inheritance ($\nu_{\text{eff}}$) incorporates the full mating cascade (maternal $\nu_M$, paternal $\nu_P$, venereal $\nu_V$):
$$\nu_{\text{eff}} = \nu_M p_F + \nu_{\text{PV}} (1 - p_F) p_M + \nu_V p_M (1 - p_F) (1 - p_M)$$
*(Where $p_F, p_M$ are infected female/male proportions, and $\nu_{\text{PV}} = \nu_P + (1 - \nu_P)\nu_V\nu_M$).*

---

### Mathematical Equations (Quick Reference)

This snapshot serves as a high-impact, condensed operational card summarizing the core mathematical framework of the study:

```
  ┌────────────────────────────────────────────────────────────────────────────────────────┐
  │                           COUPLED VECTOR-HOST EQUATION SNAPSHOT                        │
  ├────────────────────────────────────────────────────────────────────────────────────────┤
  │ 1. HOST DYNAMICS (SEIRS):                                                              │
  │    • S[t+1] = S[t] - E_new[t] + ω R[t] + μ_H (N[t] - S[t])                             │
  │    • E_new[t] = [ β[t] (S[t] I[t] / N[t]) (1 - ε · p_ISV[t]) ] + λ                       │
  │                                                                                        │
  │ 2. CLIMATE ENGINE:                                                                     │
  │    • β[t] = κ exp( b0 + b_R R[t-5] + b_T T[t-10] + b_T² T[t-10]² )                     │
  │                                                                                        │
  │ 3. VECTOR RECRUITMENT & AQUATIC LIMIT (Mordecai 2017 Thermal Drivers):                 │
  │    • A[t+1] = A[t] + Eggs[t] - Recruits[t] - Mortality[t] - A[t]² / K[t]                 │
  │    • Recruits[t] = MDR(T[t]) · pEA(T[t]) · 7 · A[t]                                    │
  │                                                                                        │
  │ 4. ISV TRANSMISSION KINETICS (Baidaliuk 2019 Mating Cascade):                          │
  │    • Offspring infected fraction:                                                      │
  │      ν_eff[t] = ν_M p_F[t] + ν_PV (1 - p_F[t]) p_M[t] + ν_V p_M[t] (1 - p_F[t]) (1 - p_M) │
  │    • p_F[t] = N_I[t] / N_V_F[t],   p_M[t] = N_MI[t] / N_V_M[t]                         │
  │                                                                                        │
  │ 5. UNCERTAINTY PROPAGATION (Monte Carlo):                                              │
  │    • Blocking Efficacy: ε ~ U(0.65, 0.95),  n = 2,000 iterations                       │
  └────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Results

### Targeted Male-Only ISV Inundation Strategy
We designed a single-pulse release of **25,000 CFAV-infected males** targeting the city's winter minimum (20,000 wild females). This **>1.25:1 ratio** guarantees infected males mathematically outcompete wild males for mating before the monsoon explosion.

*(Note for poster assembly: Place Figure 3 here)*
**[INSERT IMAGE: `../02_Figures/POSTER_Fig4_Efficacy_v3.png`]**
**Figure 3:** Monte Carlo evaluation demonstrating massive case reductions following a March ISV release.

*   **Epidemiological Impact:** A March release achieves a **91.4% median case reduction** (95% CI: 54.6–96.7%). Pre-monsoon timing is the single most critical factor for Dengue suppression — late releases (June–August) drop sharply to 39–48% median reduction with much wider uncertainty intervals.

*(Note for poster assembly: Place Figure 4 here)*
**[INSERT IMAGE: `../02_Figures/POSTER_Fig3_R0ISV.png`]**
**Figure 4:** $R_{0,ISV}$ Threshold viability proving ISV survival during Rawalpindi's post-monsoon climate.

*   **Biological Viability:** The virus exceeds the establishment threshold ($R_{0,ISV} > 1$) at temperatures above **20.3°C** (per-generation $R_{0,ISV} = 1.21$ at Rawalpindi's mean 21.9°C), spreading via mating throughout the warm season without requiring continuous factory releases.
---

## Conclusion & Discussion

This study establishes Insect-Specific Viruses (ISVs) as a highly viable, proactive biological control for Dengue in Pakistan. Rather than relying on reactive chemical fogging, our models prove that a targeted pre-monsoon (March) release of CFAV-infected males can establish self-sustaining transmission chains ($R_{0,ISV} > 1$), suppressing the explosive monsoon vector population and reducing annual human cases by a median **91.4%**.

While our SEIRS-ISV framework powerfully demonstrates this weather-driven strategy, predictive models cannot capture all real-world complexities. Therefore, this framework is limited by:
*   **Spatial Homogeneity:** The model assumes well-mixed transmission and does not currently account for neighborhood-level variations in mosquito dispersal or local ISV establishment failure.
*   **Extreme Outlier Epidemics:** While macro-climate features explain the vast majority of variance, the model occasionally smooths out hyper-localized, sudden spikes driven by unpredictable indoor breeding.
*   **Surveillance Constraints:** Our baseline calibration relies on hospital reporting, which systematically undercounts asymptomatic or mild Dengue infections across the broader region.

### Future Directions: Increasing Precision
To increase predictive precision, future modeling efforts should:
*   **Track Micro-Climates:** Use neighborhood-level weather data.
*   **Monitor Human Mobility:** Track population movement between high-risk zones.
*   **Active Surveillance:** Deploy real-time mosquito traps.
*   **Map Local Breeding:** Identify hyper-local container breeding sites.
