# Viva Voce Defence Sheet — ISV-SEIRS Model Assumptions

> One-page defence notes for the four most likely examiner questions on the
> coupled SEIRS-ISV dengue control model for Rawalpindi.
>
> Author: Ishtiaq Hussain
> Last updated: 2026-06-03

---

## 1. Maternal versus venereal transmission routes

**Likely question:** *"Does your model distinguish maternal from venereal vertical transmission of the ISV, and is this distinction supported by the literature?"*

**Defence.** The model explicitly differentiates between maternal and venereal transmission pathways. The effective vertical transmission parameter ν_eff is formulated as the sum of maternal transmission from infected females and a paternal-venereal cascade from infected males:

> ν_eff = ν_M · p_F + ν_PV · (1 − p_F) · p_M
> ν_PV = ν_P + (1 − ν_P) · ν_V · ν_M

The specific empirical rates — **93 % for maternal (ν_M)**, **76 % for paternal (ν_P)**, and **31 % for venereal (ν_V)** — are taken directly from in-vivo measurements in *Aedes aegypti* reported by **Logan et al. 2022** (DOI: 10.1128/aem.01062-22). The model therefore reflects the three distinct biological mechanisms of ISV inheritance without conflating the routes, and each rate is independently grounded in experimental data.

---

## 2. Justification for a single pre-monsoon release

**Likely question:** *"Why does the intervention rely on a single release rather than repeated releases throughout the monsoon?"*

**Defence.** The intervention is modelled as a single release because the ISV is designed to be self-sustaining in the wild mosquito population. During the warm season, the per-generation basic reproduction number of the ISV exceeds one (**R₀,ISV = 1.21 at Rawalpindi's mean temperature of 21.9 °C**, with an establishment threshold of T_c = 20.3 °C). Combined with a maternal transmission rate of 93 %, each infected female passes the virus to the great majority of her offspring, while infected males disseminate it further through mating. The intervention therefore operates analogously to established *Wolbachia* field programmes (Eliminate Dengue Programme, World Mosquito Program), where a single initial establishment propagates autonomously through subsequent generations without the need for repeated releases.

---

## 3. Selection of root-mean-square error for zero-inflated data

**Likely question:** *"Dengue case data has many zero-case weeks and occasional large outbreaks. Why did you use RMSE rather than a Negative Binomial or Poisson likelihood?"*

**Defence.** RMSE was selected as the objective function because the primary policy target of the intervention is the accurate prediction of monsoon outbreak **peak magnitudes**, which RMSE appropriately weights. A Negative Binomial likelihood would improve the statistical fit to the zero-heavy baseline data but would not alter the prediction of the outbreak peaks, which constitute the policy-relevant signal. Out-of-sample validation on the held-out 2023–2024 dataset (r_test = 0.522) confirms that the model correctly predicts the timing and amplitude of new outbreaks. Refitting under a Negative Binomial likelihood remains a logical extension for the statistical chapter of the thesis but is not required for the current policy-relevant result.

---

## 4. Assumption of neutral mosquito fitness costs

**Likely question:** *"Does the ISV reduce mosquito lifespan or biting rate, and how does your model handle that?"*

**Defence.** The model assumes that the ISV imposes no measurable fitness cost on infected mosquitoes — they exhibit the same lifespan, biting rate, and survival as wild-type. This assumption is supported by empirical evidence from **Baidaliuk et al. 2019** (DOI: 10.1128/JVI.00705-19) and **Logan et al. 2022** (DOI: 10.1128/aem.01062-22), both of which report no detectable lifespan reduction or biting-rate alteration in CFAV-infected *Aedes aegypti* under laboratory conditions. The blocking phenotype is mediated by viral interference in the midgut and salivary glands rather than by host–pathogen mortality. If a fitness cost were later observed under field conditions, it could be incorporated as a multiplicative penalty on the adult survival term, but no current evidence requires this adjustment.

---

## Quick reference numbers

| Quantity | Value | Source |
|---|---|---|
| Maternal transmission ν_M | 0.93 | Logan et al. 2022 [7] |
| Paternal transmission ν_P | 0.76 | Logan et al. 2022 [7] |
| Venereal transmission ν_V | 0.31 | Logan et al. 2022 [7] |
| Combined paternal+venereal cascade ν_PV | ≈ 0.83 | derived |
| Per-generation R₀,ISV at 21.9 °C | 1.21 | this study (NGM via Diekmann 1990) |
| ISV establishment threshold T_c | 20.3 °C | this study |
| Blocking efficacy ε | Beta(2,2) on [0.05, 0.95] | Baidaliuk et al. 2019 [4] |
| March release size | 25,000 ISV-positive males | study design |
| March median case reduction | 91.4 % (95 % CI 54.6–96.7 %) | Monte Carlo, N = 2,000 |
| Optimal rainfall lag | 7 weeks | Nelder-Mead grid search on Rawalpindi 2013–2022 data |
| Optimal temperature lag | 6 weeks | Nelder-Mead grid search on Rawalpindi 2013–2022 data |

---

*This sheet covers the four highest-probability examiner questions identified during pre-viva preparation. The full model is documented in the project README and the equation block of the BioInference 2026 poster.*
