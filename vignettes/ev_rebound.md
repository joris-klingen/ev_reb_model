EV rebound in an electrifying fleet
================
Working draft, 27 October 2026

- [Question](#question)
- [Model](#model)
  - [Driving](#driving)
  - [Adoption](#adoption)
  - [What the model implies for rebound over
    time](#what-the-model-implies-for-rebound-over-time)
  - [Assumptions](#assumptions)
- [Calibration](#calibration)
- [Results](#results)
  - [Rebound over time](#rebound-over-time)
  - [Who switches](#who-switches)
  - [Untargeted check: km of BEVs over
    time](#untargeted-check-km-of-bevs-over-time)
- [Next steps](#next-steps)

> **Status.** This is a working model. The rebound target (10 log points
> for the 2015 cohort) is a **fictitious placeholder**, to be replaced
> by register-data estimates per cohort. The levels are illustrative. A
> [PDF version](ev_rebound.pdf) is also available.

# Question

How does the driving rebound of households that switch from an ICEV to a
BEV develop over time as the fleet electrifies?

# Model

## Driving

The model makes one behavioural assumption about heterogeneity:
**households differ in their disutility from driving an ICEV**, for
example because of climate concerns. Who switches when, and each
cohort’s rebound, follow from optimising behaviour and the observed
diffusion of BEVs.

A household $i$ owns one car. The perceived cost per km is

$$
c^I_i = p_f + \psi_i \quad\text{(ICEV)}, \qquad c^E \quad\text{(EV)},
$$

where $\psi_i \ge 0$ is the household’s disutility per km driven with an
ICEV. This is the heterogeneous primitive. Demand for km has a common
elasticity, $v_i(c) = k_i (c/c^I_i)^{-\varepsilon}$, where $k_i$ is the
household’s km with the ICEV.

The rebound is the log change in km on switching:

$$
r_i = \varepsilon \ln\frac{c^I_i}{c^E}.
$$

## Adoption

The gain from switching is the present value of the extra surplus from
driving, plus the **status** that owning an EV gives. Households value
this status differently, $g_i \sim N(0,\sigma_g^2)$. Status is
positional: it fades as EVs become common, with weight $\phi(S_{t-1})$
in last year’s BEV share. Status affects the decision to switch, but not
how much the household drives:

$$
G_{it} = A \int_{c^E}^{c^I_i} v_i(c)\,dc + \phi(S_{t-1})\,g_i
= A\,\frac{k_i\,c^I_i}{1-\varepsilon}\left[1-\left(\frac{c^E}{c^I_i}\right)^{1-\varepsilon}\right] + \phi(S_{t-1})\,g_i ,
\qquad \phi(S) = 0.5^{\,S/\bar S}.
$$

Here:

- $A$ is an annuity factor over $8$ years at $4\%$;
- status halves with every $\bar S = 10$ percentage points of BEV share.

A household can only switch when it replaces its car, which it does with
probability $\lambda = 0.12$ per year. It then switches if
$G_{it} \ge F_t$. The net EV premium $F_t$ declines smoothly, and is
lowered by the SEPP purchase subsidy (2020–2024) with pass-through
$\omega$. The pass-through is below one because SEPP was budget-capped
and only for private buyers:

$$
F_t = F_\infty + (F_0 - F_\infty)\,e^{-\gamma (t - 2016)} - \omega\,\text{SEPP}_t .
$$

As status fades, the driving gain weighs more in the decision, which
sharpens selection on $\psi$ in later cohorts. Up to 2026 the effect is
small, because the BEV share stays below 10%.

## What the model implies for rebound over time

Both the gain and the rebound rise in $\psi_i$:

$$
\frac{\partial G_i}{\partial \psi_i} = A\,v_i(c^I_i) > 0, \qquad
\frac{\partial r_i}{\partial \psi_i} = \frac{\varepsilon}{c^I_i} > 0 .
$$

Households with a high ICEV disutility therefore switch earlier *and*
rebound more. As $F_t$ falls, adoption moves to households with a lower
$\psi$, and the cohort rebound declines.

How strong this is depends on how much of the variation in $G$ comes
from $\psi$ rather than from $k$ and $g$. Those two shift adoption but
not the rebound. With a homogeneous $\psi$, or with adoption timing
unrelated to type, rebound is the same for every cohort.

## Assumptions

| Parameter                                                        | Value                                             | Basis                                            |
|------------------------------------------------------------------|---------------------------------------------------|--------------------------------------------------|
| fuel cost $p_f$                                                  | €0.12/km                                          | 6.5 l/100 km at €1.85/l                          |
| EV cost $c^E$                                                    | €0.06/km                                          | mix of home and public charging, about €0.35/kWh |
| ICEV disutility $\psi$                                           | lognormal, mean €0.02/km, sdlog **estimated**     | mean: about €130/tCO<sub>2</sub> at 0.15 kg/km   |
| km $k$                                                           | lognormal, mean 13,000, sdlog 0.55                | CBS: about 12,300 km                             |
| elasticity $\varepsilon$                                         | common, **estimated**                             |                                                  |
| status sd $\sigma_g$                                             | **estimated**                                     |                                                  |
| status halving share $\bar S$                                    | 10% BEV share                                     | assumption                                       |
| SEPP subsidy                                                     | €4,000 (2020–21), €3,350 (2022), €2,950 (2023–24) | RVO                                              |
| premium path $F_0, F_\infty, \gamma$, SEPP pass-through $\omega$ | **estimated**                                     |                                                  |
| replacement rate $\lambda$                                       | 0.12                                              |                                                  |

All type components are drawn independently.

# Calibration

The parameters are estimated by simulated method of moments. Because the
premium path is restricted to a smooth decline plus the known SEPP
subsidy, the model no longer matches the BEV share by construction. The
shape of the S-curve, and the response to the subsidy, then inform how
dispersed the adoption gain is.

| Moment                                                               | Source                                                                        |
|----------------------------------------------------------------------|-------------------------------------------------------------------------------|
| BEV share of cars in use, 2016–2026 (relative deviations)            | StatLine 83703NED, 85405NED; 2025–2026 extended with new BEV sales (85898NED) |
| rebound of the 2015 cohort (all adopters up to 2015) = 10 log points | **placeholder**                                                               |
| km of BEVs / all cars in use, 2024 = 1.47                            | StatLine 85405NED                                                             |

| Estimated parameter              | Heterogeneous $\psi$ | Homogeneous $\psi$ |
|----------------------------------|----------------------|--------------------|
| elasticity $\varepsilon$         | 0.101                | 0.118              |
| status sd $\sigma_g$             | €18,778              | €19,709            |
| ICEV disutility sdlog            | 0.84                 | 0 (fixed)          |
| premium $F_0$ / $F_\infty$       | €61,365 / €11,970    | €63,210 / €11,752  |
| premium decline $\gamma$         | 0.200                | 0.195              |
| SEPP pass-through $\omega$       | 0.00                 | 0.00               |
| loss (sum of squared deviations) | 0.0404               | 0.0350             |

The BEV share uses the ‘full elektrisch’ category. The fuel type
‘Elektriciteit’ in the fleet tables includes hybrids.

In the simulation, the threshold rule is smoothed: a household that
replaces its car adopts with probability $\Lambda((G_{it} - F_t)/\tau)$,
with $\tau$ = €1,000. This keeps all moments continuous in the
parameters. The estimation runs on 250,000 simulated households; the
results below use 1,000,000.

<img src="figures/fig_share.png" width="100%" />

<img src="figures/fig_premium.png" width="100%" />

Three findings from the estimation:

- **The share path is fitted well** with a premium that falls from about
  €61k in 2016 towards €12k.
- **The SEPP pass-through is estimated at zero.** The share path shows
  no visible jump when the subsidy started (2020) or stopped (2025).
- **The share path does not tell the two models apart.** The
  heterogeneous and the homogeneous ICEV disutility fit about equally
  well (losses 0.040 and 0.035 on the full population; the small
  difference is simulation noise). So the estimated spread of $\psi$
  (sdlog 0.84) is only weakly identified. The rebound per cohort from
  register data is what will discipline it.

# Results

## Rebound over time

With a heterogeneous ICEV disutility, the cohort rebound falls from 10.2
log points (adopters up to 2015) to 8.8 (2026). Most of the decline
happens before the BEV share reaches about 1% (2019). After that, the
profile is nearly flat.

With a homogeneous disutility, or with random timing, the rebound is
constant. Each scenario is recalibrated to the same 2015 target.

<img src="figures/fig_rebound_cohort.png" width="100%" />

## Who switches

Early cohorts have a high ICEV disutility and drive a lot. Both fall as
the fleet electrifies.

<img src="figures/fig_composition.png" width="100%" />

The figure below shows the rebound each household would have if it
switched, ordered by its gain. The remaining ICEV owners would rebound
somewhat less than the first adopters, but the curve is flat over most
of the population.

<img src="figures/fig_gain_curve.png" width="100%" />

## Untargeted check: km of BEVs over time

The model matches the 2024 ratio. In earlier years, it has BEVs driven
far more than the average car, while StatLine shows a modest ratio that
rises over time. This points to constraints the model leaves out:

- the limited range of early BEVs;
- company cars.

<img src="figures/fig_km_ratio.png" width="100%" />

# Next steps

1.  Target the full **rebound profile per cohort** from register data.
    Whether, and how steeply, it declines identifies how dispersed the
    ICEV disutility is.
2.  Add a **range constraint** that loosens over time, and a **company
    car segment**.
3.  Separate **cohort, period and duration effects**, using ICEV-to-ICEV
    replacers as controls.
4.  Compute the **rebound of the remaining ICEV owners** under a
    phase-out.

------------------------------------------------------------------------

Code: [`R/`](https://github.com/joris-klingen/ev_reb_model/tree/main/R).
Specification:
[`docs/model.md`](https://github.com/joris-klingen/ev_reb_model/blob/main/docs/model.md).
Figures: [ggcpb](https://github.com/joris-klingen/ggcpb), open source
fallback font.
