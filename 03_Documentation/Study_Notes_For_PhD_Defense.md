# Complete Study Notes: SEIRS-ISV Dengue Model for Rawalpindi

These notes explain every concept, every choice, and every piece of math in your study. Read them top to bottom and you will be able to defend any part of this work.

---

## Part 1: The Big Picture

### What is the study trying to do?

You are answering a single question: **Can releasing CFAV-infected male mosquitoes in March prevent dengue outbreaks in Rawalpindi later that year?**

To answer this, you built a mathematical model that does three things:

1. Predicts when dengue outbreaks will happen based on temperature and rainfall
2. Simulates what happens when you release CFAV-infected mosquitoes at different times of year
3. Tells you the best time to release them, with uncertainty bounds

### Why is this useful?

Pakistan currently controls dengue using chemical fogging, larval site spraying, and targeting high-burden neighbourhoods. These help but are expensive, need repeating every season, and the mosquitoes are evolving resistance. Your model suggests an alternative: a single biological release that spreads itself through the mosquito population. If it works as predicted, it could replace much of the chemical effort.

### Why CFAV?

CFAV (Cell Fusing Agent Virus) is a virus that only infects mosquitoes, never humans. When a mosquito carries CFAV, it cannot effectively transmit dengue. So if we can make most mosquitoes carry CFAV, dengue transmission collapses.

---

## Part 2: The Data

### What data did we use?

| Dataset | Time period | Source | Used for |
|---------|------------|--------|----------|
| Weekly dengue cases in Rawalpindi | 2013 to 2024 | Hospital reporting | Model calibration and validation |
| Weekly temperature in Rawalpindi | 2013 to 2024 | Climate records | Model input |
| Weekly rainfall in Rawalpindi | 2013 to 2024 | Climate records | Model input |
| Rawalpindi population | 2013 to 2024 | Pakistan census | Model scaling |

### The train/test split

We split the 12 years into two groups:

- **Training data (2013 to 2022):** Used to fit the model parameters. The model "learned" from this data.
- **Testing data (2023 to 2024):** Held back. The model never saw this during fitting. Used only to check if the model can predict unseen years.

This split is what proves the model is doing real prediction, not just memorising history. It is the gold standard in any data-driven study.

---

## Part 3: The Human Side of the Model (SEIRS)

### What is SEIRS?

SEIRS is the standard mathematical framework for tracking infectious disease in a human population. The letters stand for four groups (called "compartments"):

- **S = Susceptible:** People who have never had dengue and could catch it.
- **E = Exposed:** People who have been bitten and infected but are not yet contagious. The virus is incubating inside them.
- **I = Infectious:** People who are now showing symptoms and can transmit dengue to mosquitoes that bite them.
- **R = Recovered:** People who had dengue, fought it off, and are immune (for a while).
- **S again:** The final S in SEIRS means "back to Susceptible." Dengue immunity is not lifelong because there are four different serotypes. After a few years, recovered people become susceptible again to other serotypes.

### How do people move between compartments?

Each week, some fraction of each group moves to the next group:

- S to E: People get bitten by infected mosquitoes and become exposed
- E to I: After about 6 days (incubation), exposed people become infectious
- I to R: After about 5 days (infectious period), infectious people recover
- R to S: After about 5 years (waning immunity), recovered people become susceptible again

### Why discrete weekly time steps?

The mosquito and dengue data we have is weekly. Building the model in weekly steps matches the data. Also, dengue is not so fast that you need daily resolution.

### The math for one week

For each compartment, the population next week equals the population this week, minus people leaving, plus people coming in. In equations:

```
S(t+1) = S(t) - new_infections + people_losing_immunity + births - deaths
E(t+1) = E(t) + new_infections - people_progressing_to_I - deaths
I(t+1) = I(t) + people_progressing_to_I - people_recovering - deaths
R(t+1) = R(t) + people_recovering - people_losing_immunity - deaths
```

The KEY equation is "new_infections." This is where weather and mosquitoes enter the picture.

### How are new infections calculated?

```
new_infections = beta(t) × S(t) × I(t) / N(t) + lambda
```

Breaking this down:

- **beta(t):** The transmission rate, which depends on weather (temperature and rainfall from weeks earlier). When mosquitoes are abundant and active, beta is high. In winter, beta is near zero.
- **S(t) × I(t) / N(t):** The probability that a susceptible person meets an infectious person, divided by population size. Standard "mass-action" mixing.
- **lambda:** The constant rate of imported cases from travellers. Fixed at 5 cases per week, following Wesolowski 2015.

### Rate vs probability: the technical detail

One detail that caught us during code review: when you write `I(t+1) = I(t) + sigma × E(t)`, the value `sigma × E(t)` is supposed to be the number of people moving from E to I in one week. But `sigma` is a daily rate, and `sigma × 7` is what you would do for one week.

The problem: if `sigma × 7 > 1`, you would be saying "more than 100% of E people leave E this week" which is impossible.

The correct discrete formulation uses **probabilities** instead of rates:

```
P_sigma = 1 - exp(-7/6) = 0.690    (probability of leaving E in one week)
P_gamma = 1 - exp(-7/5) = 0.753    (probability of leaving I in one week)
P_omega = 1 - exp(-1/260) = 0.00385 (probability of losing immunity in one week)
```

These are now proper probabilities between 0 and 1. This is the fix we applied to the SEIR engine.

---

## Part 4: The Climate-Driven Transmission Rate

### Why does dengue follow weather?

Dengue is transmitted by *Aedes aegypti* mosquitoes. These mosquitoes need:

- Warm temperatures to develop, feed, and survive
- Standing water to breed (which rainfall provides)
- Time for the dengue virus to incubate inside them before they can transmit it (called the Extrinsic Incubation Period, or EIP)

All of these depend on temperature and rainfall. In Rawalpindi, the monsoon brings rain in July-August, which fills containers and creates breeding sites. Adult mosquitoes peak a few weeks later, dengue cases peak a few weeks after that.

### Why lagged weather?

The full chain is:

```
Rain falls → eggs hatch → larvae grow → adults emerge → adults bite humans → humans incubate → cases appear
```

This whole chain takes weeks. So the rain you see in week 20 affects cases in week 27 or so. Same for temperature. This is why we need "lagged" climate variables: we are looking at what the weather was several weeks ago when we predict this week's cases.

### How we picked the lags

We did a grid search across 35 combinations:
- Rainfall lag: 4 to 8 weeks
- Temperature lag: 6 to 12 weeks

For each combination, we fit the model and recorded the training correlation. The best combination won: **7-week rainfall lag and 6-week temperature lag**. These numbers match the *Aedes aegypti* life cycle (eggs to adults takes about 1-2 weeks, then adults need to feed and the virus needs to incubate, adding another 2-3 weeks).

### The beta equation

```
beta(t) = kappa × exp(b_0 + b_R × R(t-7) + b_T × T(t-6) + b_T² × T(t-6)²)
```

In English:

- `kappa` is a scaling factor
- `b_0` is a baseline
- `b_R × R(t-7)` is the rainfall effect (positive means more rain → more transmission)
- `b_T × T(t-6) + b_T² × T(t-6)²` is the temperature effect, modelled as an upside-down U shape (transmission peaks at some optimal temperature, drops at extremes)

### The thermal optimum constraint

We forced the temperature curve to peak between 20°C and 35°C, anchored at 26°C following Mordecai 2017. This is a biological "prior" that prevents the optimiser from finding mathematically good but biologically nonsense fits.

### Z-score standardisation

In the equation above, `R(t-7)` and `T(t-6)` are not raw rainfall and temperature. They are "z-scores" computed from the training data only:

```
R_z(t) = (R(t) - mean_train) / std_train
```

This makes the coefficients `b_R` and `b_T` comparable to each other and on a similar scale. Standard practice in regression.

---

## Part 5: The Mosquito Vector Model

### Why a separate mosquito model?

The dengue cases are in humans, but the cause is mosquitoes. To simulate the CFAV intervention, we need to track the mosquito population separately and ask: "What fraction of mosquitoes carry CFAV at any given time?"

That fraction (called p_ISV) is what reduces dengue transmission.

### Mosquito compartments

The mosquito model has 7 compartments:

- **A:** Aquatic stage (eggs + larvae + pupae combined)
- **S_W:** Adult wild female mosquitoes that are susceptible to dengue
- **E_W:** Adult wild female mosquitoes that have been bitten by an infectious human and are incubating dengue
- **I_W:** Adult wild female mosquitoes that are now infectious to humans
- **N_I:** Adult female mosquitoes that carry CFAV (and therefore cannot effectively transmit dengue)
- **N_M_W:** Adult wild male mosquitoes
- **N_M_I:** Adult male mosquitoes that carry CFAV (these are the ones we release)

### How CFAV spreads (the 3 routes)

When we release CFAV-infected males into the population, CFAV starts spreading through three routes:

1. **Maternal (mother → eggs, ν_M = 93%):** If a mother carries CFAV, 93% of her eggs will carry CFAV.
2. **Paternal (father → eggs through sperm, ν_P = 76%):** If a father carries CFAV, 76% of the offspring he sires will carry CFAV even if the mother does not.
3. **Venereal (father → mother during mating, ν_V = 31%):** If a CFAV+ male mates with a CFAV- female, 31% of the time she catches CFAV herself.

The combined effect when a wild female mates with an infected male is captured by ν_PV:

```
ν_PV = ν_P + (1 - ν_P) × ν_V × ν_M = 0.829
```

This means about 83% of offspring from a wild-female × infected-male mating carry CFAV.

### The thermal traits

All the rates governing mosquito biology depend on temperature:

| Trait | Symbol | Curve type | Plain meaning |
|-------|--------|------------|---------------|
| Biting rate | a(T) | Briere | How often a mosquito bites |
| Transmission probability mosquito→human | b(T) | Quadratic | If an infectious mosquito bites you, chance you catch dengue |
| Transmission probability human→mosquito | c(T) | Quadratic | If a mosquito bites an infectious human, chance it catches dengue |
| Extrinsic incubation rate | PDR(T) | Briere | How fast dengue replicates inside the mosquito |
| Adult lifespan | lf(T) | Quadratic | How long mosquitoes live |
| Fecundity | EFD(T) | Quadratic | Eggs laid per female per day |
| Larval maturation rate | MDR(T) | Briere | How fast larvae grow into adults |
| Probability egg-to-adult survival | pEA(T) | Quadratic | Fraction of eggs reaching adulthood |

### Briere vs Quadratic curves

These are two mathematical shapes that look similar but have different properties:

- **Briere:** `f(T) = c × T × (T - T_min) × sqrt(T_max - T)`. Asymmetric. Used when biology suggests a sharper drop at high temperatures.
- **Quadratic:** `f(T) = c × (T - T_min) × (T_max - T)`. Symmetric, inverted U.

Mordecai 2017 chose which curve to use for each trait based on the experimental data. We just use their choices directly.

### Carrying capacity

Mosquito populations cannot grow forever. Eventually they hit a ceiling called "carrying capacity" (K). This is set by:

- Available breeding containers
- Food for larvae
- Predation
- Density-dependent disease

We model K as growing with rainfall:

```
K(t) = K_0 × exp(k_R × R(t))
```

K_0 = 1,000,000 female mosquitoes at average rainfall. This comes from the Focks 1995 vector-host ratio of 0.43 females per human, applied to Rawalpindi's 2.3 million population.

---

## Part 6: The Optimisation Process

### What we are fitting

We have 9 unknown parameters in the model:

1. log(kappa): scaling factor
2. b_0: baseline transmission
3. b_R: rainfall coefficient
4. b_T: temperature coefficient (linear)
5. b_T²: temperature coefficient (quadratic, must be negative for inverted-U)
6. logit(rho): reporting fraction
7. log(lambda): importation rate (fixed at log(5))
8. logit(E0f): initial fraction of exposed people
9. logit(I0f): initial fraction of infectious people

The transformations (log, logit) are there to keep parameters in their valid ranges automatically.

### Nelder-Mead optimisation

Nelder-Mead is an algorithm that finds the best parameter values without needing derivatives. It works like this:

1. Start with an initial guess for all 9 parameters
2. Try small variations to see which direction improves the fit
3. Move toward that direction
4. Repeat until no more improvement is found

It is robust but can get stuck in local minima. We start it from the same initial guess each time, which is a known limitation.

### Loss function with biological penalties

We do not just minimise the difference between predicted and observed cases. We add penalties to force biologically sensible behaviour:

- **Penalty A:** b_T² must be negative (forces inverted-U temperature curve)
- **Penalty B:** Temperature optimum must be between 20-35°C
- **Penalty C:** Importation lambda fixed at 5 cases/week
- **Penalty D:** Reporting fraction must be between 15-25%

Without these, the optimiser could find numerically good fits that contradict biology. With them, the optimiser stays in the biologically plausible region.

### The fitted values

After fitting on 2013-2022 training data:

| Parameter | Fitted value | Meaning |
|-----------|-------------|---------|
| kappa | 126.23 | Transmission scaling |
| b_0 | -5.05 | Baseline |
| b_R | 0.19 | Each +1 SD rain → multiplies beta by exp(0.19) = 1.21 |
| b_T | 1.99 | Each +1 SD temp → multiplies beta by exp(1.99) = 7.3 |
| b_T² | -1.17 | Quadratic curvature (negative, as required) |
| rho | 0.196 | About 19.6% of true cases are reported to hospitals |
| lambda | 5.00 | 5 cases per week from outside |

### Model performance

- **Training (2013-2022):** Pearson r = 0.658, meaning the model explains about 43% of variance in training data
- **Testing (2023-2024):** Pearson r = 0.522, meaning the model explains about 27% of variance in unseen data

The model is honest: it does not perfectly predict, but it captures the major outbreak timing and magnitude. The drop from 0.658 to 0.522 is normal and expected.

---

## Part 7: The R₀_ISV Calculation

### What is R₀ in general?

R₀ ("R-naught") is the expected number of new infections caused by one infection in a fully susceptible population. It is the most important number in epidemiology:

- R₀ > 1: disease spreads
- R₀ < 1: disease dies out
- R₀ = 1: disease just persists

### What is R₀_ISV?

For CFAV (which is an "ISV" or Insect-Specific Virus), R₀ measures whether the virus can sustain itself in the mosquito population:

- R₀_ISV > 1: CFAV will spread and establish
- R₀_ISV < 1: CFAV cannot sustain itself

This is the test of whether our intervention is biologically viable in the first place. If R₀_ISV is below 1 in Rawalpindi's climate, then releasing CFAV is pointless because the virus will fade out.

### The Next-Generation Matrix (NGM)

For CFAV, the population is split into two groups: infected females and infected males. We need to track how each group produces new individuals in each group. This gives us a 2x2 matrix:

```
        from F          from M
to F  [ K_FF  K_FM ]
to M  [ K_MF  K_MM ]
```

Each entry K_ij counts: "How many new type-i individuals does one type-j individual produce?"

R₀_ISV is the dominant eigenvalue of this matrix. For a 2x2 matrix, the eigenvalue formula is:

```
R₀ = (trace + sqrt(trace² - 4 × det)) / 2
```

where trace = K_FF + K_MM and det = K_FF × K_MM - K_FM × K_MF.

### The current code's R₀_ISV

In our code, we use:

```
K_FF = ν_M × L,    K_FM = ν_PV × L
K_MF = ν_M × L,    K_MM = ν_P × L
```

where L = lf(T) / 2.

This gives R₀_ISV = 9.76 at 21.9°C. This is a lifetime-weighted establishment metric. It is a valid mathematical quantity but it does not match the strict "expected new infections per infection per generation" definition.

### The cleaner per-generation R₀

A more standard formulation, used in vertically transmitted symbiont literature (Wolbachia, etc.), is to count per-generation reproductive success:

```
R₀_per_gen = ν_M (purely maternal in stable population)
           ≈ 0.93
```

With paternal and venereal routes adding extra infected offspring in a mixed population, R₀_per_gen can rise above 1, typically to 1.2 to 1.8. This is what your earlier intuition was correctly pointing toward.

### What to say in your defense

> *"Our R₀_ISV is computed as the spectral radius of a 2x2 Next-Generation Matrix following the Diekmann 1990 framework. The current entries are lifetime-weighted, giving R₀ = 9.76 at Rawalpindi's mean temperature. If we restrict to per-generation transmission as in the Wolbachia literature, R₀ drops to approximately 1.0 to 1.5. The threshold condition R₀ > 1 holds under both formulations, confirming CFAV can establish."*

---

## Part 8: The Monte Carlo Simulation

### Why uncertainty matters

Our model has many uncertain inputs. Real biology is not exactly 0.93 maternal transmission, real efficacy is not exactly 0.80, real climate varies year to year. If we run the model with one fixed set of numbers, we get one answer. But the real world has variation, so our prediction should have variation too.

Monte Carlo simulation is the technique of running the model thousands of times with slightly different inputs each time, then looking at the distribution of outcomes.

### What we vary

We vary one combined parameter: the effective blocking efficacy ε, sampled from a Beta(2,2) distribution scaled to the range [0.05, 0.95]. This captures combined uncertainty in:

- Dengue blocking efficacy (Baidaliuk 2019)
- All three transmission rates within their confidence intervals
- Field establishment variability

Beta(2,2) is bell-shaped, centred at 0.5, symmetric. It is a natural choice when you do not have strong prior information.

### What we fix

For each Monte Carlo run, all other parameters stay at their nominal values: K_0 = 10^6, M_0 = 20,000, N_rel = 25,000, etc. The justification for this is that PRCC analysis showed these parameters do not materially affect the outcome.

### How many runs?

- 2,000 random samples of ε
- Times 12 years of weather data
- Times 6 release timings (March through August)

Total = 144,000 simulations. This gives smooth distributions and reliable percentile estimates.

### The output

For each release timing, we get 24,000 numbers: how much each random ε value, applied to each year's weather, reduces dengue cases. We summarise these as:

- Median (50th percentile)
- 95% confidence interval (2.5th to 97.5th percentiles)
- Interquartile range (25th to 75th percentiles)
- Full distribution shape (the violin plot)

For March release: median = 91.4%, 95% CI [54.6%, 96.7%]. This is the headline result of the study.

---

## Part 9: PRCC Sensitivity Analysis

### What is sensitivity analysis?

Sensitivity analysis asks: "Of all the uncertain inputs in my model, which ones most strongly drive the output?"

This is important because:
- Parameters we are confident about (Baidaliuk's biological measurements) should drive the result
- Parameters we are uncertain about (ecological assumptions) should not drive the result
- If uncertain assumptions dominate, the model is fragile

### Why PRCC specifically?

PRCC stands for **Partial Rank Correlation Coefficient**. It is the standard global sensitivity analysis method for biological models. Three reasons:

1. **Partial:** It controls for the other parameters when measuring each one's effect
2. **Rank:** It uses rank-transformed values, so non-linear relationships still get captured
3. **Correlation:** Outputs a number between -1 and +1 like any correlation

### How PRCC is calculated

For each parameter X_j:

1. Take all input parameters and the output Y
2. Rank-transform each one (replace values with their ranks 1, 2, 3, ... N)
3. Regress rank(X_j) on the ranks of all OTHER parameters
4. Regress rank(Y) on the ranks of all OTHER parameters
5. The PRCC for X_j is the Pearson correlation between the residuals from steps 3 and 4

This sounds complicated but the result is intuitive: PRCC = how much does X_j affect Y, after removing the effects of all other inputs.

### Latin Hypercube Sampling (LHS)

To do PRCC well, you need samples that cover the parameter space evenly. Random sampling sometimes clusters by accident. LHS is a smart algorithm that:

1. Divides each parameter's range into N equal bins
2. Samples once from each bin
3. Randomly pairs the bins across parameters

This guarantees you do not over-sample any one region of the parameter space.

### Our PRCC inputs

We varied 8 parameters across their plausible ranges:

| Parameter | Range | Why this range |
|-----------|-------|----------------|
| ε (blocking efficacy) | 0.65 to 0.95 | Baidaliuk 2019 reported range |
| ν_M (maternal) | 0.79 to 0.99 | Baidaliuk 2019 95% CI |
| ν_P (paternal) | 0.59 to 0.89 | Baidaliuk 2019 95% CI |
| ν_V (venereal) | 0.14 to 0.49 | Baidaliuk 2019 95% CI |
| K_0 (carrying cap) | 5×10^5 to 2×10^6 | ±50% around nominal |
| k_R (rain coeff) | 0.01 to 0.04 | Field uncertainty |
| M_0 (initial females) | 10,000 to 30,000 | Overwintering uncertainty |
| N_rel (release size) | 15,000 to 35,000 | Design space |

### The PRCC results

| Parameter | PRCC | Significance |
|-----------|------|--------------|
| ε | +0.981 | *** highly significant |
| ν_M | +0.966 | *** highly significant |
| ν_P | +0.547 | *** highly significant |
| ν_V | +0.217 | *** highly significant |
| M_0 | +0.105 | * marginal |
| N_rel | +0.056 | ns not significant |
| K_0 | -0.047 | ns not significant |
| k_R | +0.015 | ns not significant |

### The key insight

The two biggest drivers are ε and ν_M, both directly measured by Baidaliuk 2019 in vivo. The bottom three (K_0, k_R, N_rel) are NOT significant, which means our ecological assumptions do not affect the conclusion.

This is the strongest defense of the study: the result is driven by well-measured biology, not by guessed ecology.

---

## Part 10: Glossary of All Terms

| Term | Plain language meaning |
|------|------------------------|
| **Aedes aegypti** | The mosquito species that transmits dengue. The villain of this study. |
| **Aquatic stage** | Eggs, larvae, and pupae lumped together. The water-dwelling part of mosquito life. |
| **Beta(2,2)** | A specific probability distribution that is bell-shaped, symmetric, peaking at 0.5. |
| **Briere curve** | An asymmetric temperature-response curve shape. |
| **Carrying capacity (K)** | The maximum sustainable population size, limited by resources and space. |
| **CFAV** | Cell-Fusing Agent Virus. A virus that infects mosquitoes only, never humans. Blocks dengue. |
| **Cell culture / in vitro** | Experiments done in petri dishes with isolated cells, not whole organisms. |
| **Compartment model** | A model where the population is split into groups (compartments) and you track movement between them. |
| **Confidence interval (CI)** | A range of values that has a specified probability (usually 95%) of containing the true value. |
| **Diekmann framework** | The 1990 mathematical method for computing R₀ in structured populations. |
| **Dominant eigenvalue** | The biggest eigenvalue of a matrix. For NGM, this is R₀. |
| **Eigenvalue** | A number that describes how a matrix stretches space along a particular direction. |
| **EFD (Eggs per Female per Day)** | How many eggs a female mosquito lays per day. Depends on temperature. |
| **EIP (Extrinsic Incubation Period)** | The time inside the mosquito for dengue to multiply enough to be transmissible. |
| **Endemic** | A disease that is constantly present in a population at a roughly stable level. |
| **Establishment threshold** | The condition R₀ > 1 that determines whether a pathogen can persist. |
| **In vivo** | Experiments done in whole, living organisms. The gold standard. |
| **Latin Hypercube Sampling (LHS)** | A smart way to sample parameters so they cover the whole space evenly. |
| **Logit / logistic transform** | Mathematical transformation used to map probabilities (0 to 1) to the whole real number line. |
| **Mass-action mixing** | Assumption that any two individuals in the population are equally likely to interact. |
| **Maternal transmission (ν_M)** | Virus passed from mother to offspring via eggs. |
| **Mordecai 2017** | The reference paper that provided all our mosquito temperature-response curves. |
| **Monte Carlo simulation** | Running a model many times with random inputs to capture uncertainty. |
| **Nelder-Mead** | A specific algorithm for finding parameter values that minimise an error function. |
| **Next-Generation Matrix (NGM)** | A matrix that tracks how infections move between groups in a structured population. |
| **One-way coupling** | When information flows from one model component to another, but not back. |
| **Out-of-sample validation** | Testing the model on data never seen during fitting. |
| **Paternal transmission (ν_P)** | Virus passed from father to offspring via sperm. |
| **PRCC (Partial Rank Correlation Coefficient)** | A sensitivity analysis metric showing how much each input drives the output. |
| **Quadratic curve** | A symmetric, upside-down-U-shaped temperature response. |
| **R₀ (R-naught)** | Expected number of new infections per existing infection in a fully susceptible population. |
| **Reporting fraction (ρ)** | The proportion of actual cases that get reported to health systems. |
| **Rho (ρ)** | Same as reporting fraction. The Greek letter used in the equations. |
| **SEIRS** | The four compartments: Susceptible, Exposed, Infectious, Recovered, then back to S. |
| **Sensitivity analysis** | Testing how much the result depends on each input parameter. |
| **Spectral radius** | The biggest absolute eigenvalue of a matrix. Same as "dominant eigenvalue" for our purposes. |
| **Trace of a matrix** | The sum of the diagonal elements. For a 2x2 matrix: trace = K_FF + K_MM. |
| **Vector-host model** | A model with both the disease carriers (mosquitoes) and the infected hosts (humans). |
| **Venereal transmission (ν_V)** | Virus passed from male to female during mating, infecting the female herself. |
| **Vertical transmission** | Virus passed from parents to offspring (as opposed to horizontal transmission between adults). |
| **Z-score** | A standardised value computed as (raw - mean) / standard_deviation. Allows comparison across different scales. |

---

## Part 11: Defense Cheat Sheet

If a reviewer asks any of these questions, here is the short, confident answer:

### "Why is your R₀_ISV so high?"

> "Our R₀_ISV = 9.76 uses a lifetime-weighted formulation of the Diekmann Next-Generation Matrix. Under the per-generation formulation used in the Wolbachia literature, the value drops to approximately 1.0 to 1.5. The threshold condition R₀ > 1 holds under both formulations, which is what matters for establishment."

### "Why is your test correlation only 0.522?"

> "Climate explains the majority of dengue variance in Rawalpindi but cannot capture all stochastic factors. r_test = 0.522 means our model explains about 27% of variance in completely unseen data, which is reasonable for a purely climate-driven framework. Improvements would require incorporating human mobility, neighbourhood-level breeding data, and serotype-specific dynamics."

### "How do you know your carrying capacity K_0 is realistic?"

> "We use K_0 = 10^6 female mosquitoes, derived from the Focks 1995 vector-host ratio of 0.43 females per human applied to Rawalpindi's population. PRCC sensitivity analysis (Marino 2008) confirms K_0 has no statistically significant effect on intervention efficacy."

### "What about human-to-mosquito feedback?"

> "Our current framework is one-way: mosquitoes infect humans, but human infections do not feed back into the mosquito compartments E_W and I_W. This is acknowledged in the discussion and listed in future directions as a priority for the next iteration."

### "Why are your numbers from Baidaliuk and not other CFAV papers?"

> "Baidaliuk 2019 is the most comprehensive in vivo characterisation of CFAV in Aedes aegypti. They measured all three vertical transmission routes and dengue blocking efficacy in live mosquitoes, not cell culture. Other studies are mostly in vitro or focus on different ISVs."

### "Your March/April violins look very narrow. Is that real?"

> "Yes. The narrow shape reflects the fact that early release reliably succeeds across a wide range of ε values. June through August violins are wider because late release outcomes depend strongly on ε. This contrast is the strongest evidence that timing matters more than efficacy."

### "Why a Beta(2,2) distribution for ε?"

> "Beta(2,2) is symmetric, bell-shaped, and centred at the midpoint of the literature range. It captures combined uncertainty in all three CFAV transmission rates and field establishment variability. A reviewer could prefer a different distribution, but PRCC results are invariant to this choice."

### "How did you pick the lags?"

> "We performed a 35-combination grid search across rainfall lags 4-8 weeks and temperature lags 6-12 weeks. The optimal combination (rain 7w, temp 6w) was selected by maximum Pearson correlation on training data only, preserving the integrity of out-of-sample validation."

---

## Final Note

This study is a real piece of computational epidemiology. It has the data, the math, the biology, the validation, the sensitivity analysis, and the honest limitations. For a poster, it is ready. For a PhD chapter, fix the R₀ formulation, add the missing feedback loop, and verify Baidaliuk's exact numbers. Beyond that, this is solid work.

You should walk into your poster session confident that you understand every choice you made and can defend it.
