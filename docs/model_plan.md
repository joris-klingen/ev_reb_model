# EV rebound across adoption cohorts: model plan

## Question

Rebound (the change in vehicle-km after switching from an ICEV to an EV) falls with each
later adoption cohort. Hypothesis: the households that switch first are the ones the ICEV
constrains most, through fuel cost and through climate disutility per km driven. Selection
along the diffusion curve then produces the cohort gradient.

Formally, this is **selection on gains** (a Roy model) embedded in a **rank/probit diffusion
model**. The heterogeneity distribution that produces the S-curve also produces the decline
in rebound across cohorts.

## Literature map

### 1. Diffusion / S-curve
- **Rank/probit (threshold) models**: David (1969), Davies (1979); survey in Geroski (2000),
  [Models of technology diffusion](https://consensus.app/papers/details/e034aee1875356b48442448e7a03cd43/).
  Heterogeneous reservation thresholds and a falling cost/price give an S-curve, which is the
  CDF of the threshold distribution. Adoption order is *systematic* by type. This is the
  backbone of our model.
- **Epidemic/Bass models**: Bass (1969). Adoption timing comes from information or contagion
  and is (roughly) *random with respect to type*, so they predict **no** cohort gradient in
  rebound. The two classes therefore give a test that tells them apart.
- Bridging micro models: Chatterjee & Eliashberg (1990),
  [Innovation diffusion in a heterogeneous population](https://consensus.app/papers/details/32b2969947ec5f9e905ffba0ed3d1f4f/);
  Heiman et al. (2022), [Imitation vs threshold models](https://consensus.app/papers/details/f21499a26a355958a9e3dd809b064a48/);
  Karshenas & Stoneman on rank, stock and order effects.
- Griliches (1957, hybrid corn): profitability drives the timing of adoption.

### 2. Selection on gains / heterogeneous treatment effects
- Generalised Roy model and marginal treatment effects (MTE): Heckman & Vytlacil (2005).
  A declining MTE curve is exactly "later adopters have smaller effects".
- Suri (2009, Econometrica), [hybrid maize adoption](https://nber.org/system/files/working_papers/w15346/w15346.pdf):
  the households with low returns are the ones that don't adopt. This is the closest analogue
  in technology adoption.
- Andresen (2018), [MTE in Stata](https://ageconsearch.umn.edu/record/340232/files/Andresen.pdf).

### 3. Rebound and discrete–continuous vehicle choice
- Dubin & McFadden (1984): a joint model of the discrete choice (which technology) and the
  continuous choice (how much use). This is the standard structure for "adopt, then drive".
- Frondel, Martínez Flores & Vance,
  [Heterogeneous rebound effects: discrete-continuous models](https://eldorado.tu-dortmund.de/items/630805bf-5edf-4446-8582-13c944f66855):
  the rebound estimates depend strongly on the selection correction used.
- Gillingham, Rapson & Wagner (2016), *The rebound effect and energy efficiency policy*
  (REEP): survey and definitions. In particular, the price-based rebound differs from the
  rebound induced by an efficiency gain.

### 4. EV use: evidence
- Davis (2019), [How much are EVs driven?](https://ideas.repec.org/a/taf/apeclt/v26y2019i18p1497-1502.html):
  EVs are driven about 30% less in the 2017 NHTS. Doshi & Metcalf (2023),
  [Depends on the EV](https://ceepr.mit.edu/workingpaper/how-much-are-electric-vehicles-driven-depends-on-the-ev).
- Burlig, Bushnell, Rapson & Wolfram (2021), [Low Energy](https://www.nber.org/papers/w28451):
  the charging data imply low VKT among early EVs.
- NL: [EV use and VKT in the Netherlands](https://www.sciencedirect.com/science/article/pii/S0965856424003732)
  finds no rebound after controls. Fallah et al. (UK MOT),
  [big-data rebound](https://www.researchgate.net/publication/365391211_A_Big-data_Analysis_of_the_Potential_Rebound_Effect_of_Electric_Vehicles_on_Vehicle_Kilometers_Travelled).
- Review: [EV usage and VKT, literature review (2026)](https://www.sciencedirect.com/science/article/pii/S1361920926000829).
  It names early-adopter self-selection, range limits and allocation within the household as
  reasons for low EV VKT.
- Adopter heterogeneity: [high-end vs low-end early adopters](https://www.sciencedirect.com/science/article/pii/S0965856416302208);
  Plötz et al. (2014) find German early adopters are high-mileage suburban commuters;
  Archsmith, Muehlegger & Rapson (2021), *Future paths of EV adoption* (later adopters differ).
- Xing, Leard & Li (2021), *What does an EV replace?*: matters for the counterfactual VKT.

**Gap**: none of the papers above connects the shape of the diffusion curve to the cohort
gradient in rebound. Most EV-rebound studies are cross-sectional, and the gradient across
adoption cohorts has not been studied as an object. That gap is the contribution.

## Model

### Stage 1: static Roy/rank model (analytical)

For household i with type θ_i = (a_i, ε_i, ψ_i, ρ_i, g_i):

- Demand for km: v_i(c) = a_i c^{-ε_i}, where c is the perceived cost per km.
- ICEV: c_i^I = p_f/η_I + ψ_i. Here ψ_i is the **per-km climate disutility**, a
  "moral tax" that rises with use.
- EV: c^E = p_e/η_E, plus a range/charging penalty ρ_i that is strictly increasing in the
  long-trip share.
- Adoption gain: G_i = CS_i(c^E) − CS_i(c_i^I) + g_i − ρ_i − F_t, where
  - CS is the consumer surplus from driving,
  - g_i is a *lump-sum* warm glow,
  - F_t is the purchase premium, which falls over time (learning curve, subsidies).
- Adopt in the first period t with G_i > 0 (conditional on a replacement event).
- Individual rebound: R_i = v_i(c^E) − v_i(c_i^I). In log terms: ε_i · ln(c_i^I / c^E).

The key results to derive are:

1. **P1 (gradient)**: the gain ΔCS_i rises in a_i, ε_i and ψ_i. R_i also rises in ε_i and
   ψ_i. Under a single-crossing or positive-dependence condition, E[R | adopt at t] falls as
   F_t falls. The marginal adopter at t has the MTE at the threshold F_t.
2. **P2 (climate channel)**: ψ_i raises *both* adoption and rebound, because removing a
   per-km cost acts like a price drop. A lump-sum warm glow g_i raises adoption but **not**
   rebound. The model can therefore separate the two "green" mechanisms.
3. **P3 (counter-forces)**: ρ_i is correlated with a_i. If high-km drivers are held back by
   range, the gradient can reverse or become non-monotone. This is a testable sign
   condition.
4. **P4 (S-curve link)**: the adoption share S(t) = P(G_i > F_t) = 1 − H(F_t). Its shape
   identifies the distribution H of the gain. Combined with P1, the slope of the S-curve maps
   to the steepness of the rebound gradient. A Bass-type model with type-independent timing
   predicts a flat gradient instead.

### Stage 2: dynamic diffusion simulation

- A household panel with an exogenous car-replacement hazard. Switching is possible only at
  replacement. This matters because timing is then partly random, which dampens selection.
- Add F_t falling, EV range rising, charging network N_t, fuel and electricity prices, and
  optionally a social-learning term (a hybrid of rank and epidemic models).
- Simulate S(t) and the cohort profile E[R | cohort]. Then decompose the cohort decline
  into four parts:
  1. selection (composition of θ),
  2. technology (range ↑, which raises VKT and works *against* the observed decline),
  3. prices,
  4. policy.

### Stage 3: empirical identification / estimation

**Data candidates (NL)**: CBS microdata linking RDW registrations to households, NAP
odometer readings for VKT before and after the switch, and income/wealth, commute and
home-charging proxies.

Steps:

1. **Descriptive**: stacked event study around the switch, by cohort, using Callaway &
   Sant'Anna or Sun & Abraham estimators.
   - Control group: **ICEV→ICEV replacers** at the same time. Replacing any car is itself a
     VKT shock (moving house, a new job).
2. **Separate cohort from period and duration effects**: this is an age-period-cohort
   problem. Fix it with calendar-time controls from ICE replacers, plus a model restriction
   (e.g. a common duration profile).
3. **Test selection**:
   - Compare the cohort gradient with and without conditioning on observables (pre-switch
     VKT, income, green-vote share in the municipality as a proxy for ψ).
   - If observables absorb the gradient, it is selection on observables.
4. **MTE**: use policy shifters of adoption propensity as instruments: SEPP subsidy rounds,
   company-car tax (bijtelling) steps, and the local rollout of charging points. Estimate
   rebound as a function of the unobserved resistance to adopting.
5. **Structural**: estimate the Stage-1/2 model by SMM on (i) S(t), (ii) rebound by cohort
   and (iii) the joint distribution of pre-switch VKT. Then run counterfactuals: rebound of
   the *remaining* ICEV owners under a 2030/2035 mandate. That is the policy-relevant
   marginal rebound.

**NL-specific confounders to handle**:
- Company/lease cars: the private cost per km is about zero, and bijtelling changed over
  2019–2025. Model them as a separate segment.
- Second-car allocation within multi-car households.
- Used-EV market entry of later cohorts.
- Range improvements across cohorts.

## Work plan

| Step | Output |
|---|---|
| 1. Literature deep-dive (rank vs Bass; MTE; EV VKT) | annotated bibliography |
| 2. Stage-1 derivations (P1–P4) | note with propositions and proofs |
| 3. Simulation code (R, data.table) | S-curve and cohort rebound plots, decomposition |
| 4. Data scoping (CBS/RDW/NAP access, cohort sizes) | data memo |
| 5. Reduced-form event study | cohort gradient with ICE-replacer controls |
| 6. MTE / structural estimation | estimates, counterfactual marginal rebound |
