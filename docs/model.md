# Model specification

This is the specification of the model in `R/model.R`. The narrative version is the site,
built from `docs/index.Rmd`.

**Question:** how does the rebound of ICEV-to-BEV switchers develop as the fleet
electrifies? The only behavioural heterogeneity assumed is in the disutility of driving an
ICEV.

## Households and driving

A household $i$ owns one car and has type $(\psi_i, k_i, g_i)$. All components are drawn
independently:

| Symbol | Meaning | Distribution |
|---|---|---|
| $\psi_i$ | disutility per km driven with an ICEV (e.g. climate) | lognormal, mean `psi_mean`, sdlog `psi_sdlog` |
| $k_i$ | annual km with the ICEV | lognormal, mean `km_mean`, sdlog `km_sdlog` |
| $g_i$ | lump-sum EV taste (warm glow, model fit); does not affect driving | $N(0, \sigma_g^2)$, $\sigma_g$ calibrated |

The cost per km is $c^I_i = p_f + \psi_i$ for an ICEV and $c^E$ for an EV. Demand for km
has a common elasticity $\varepsilon$ (calibrated):

$$
v_i(c) = k_i\left(\frac{c}{c^I_i}\right)^{-\varepsilon}, \qquad
r_i = \ln v_i(c^E) - \ln v_i(c^I_i) = \varepsilon \ln\frac{c^I_i}{c^E}.
$$

## Adoption

The gain from switching is

$$
G_i = A \int_{c^E}^{c^I_i} v_i(c)\,dc + g_i
= A\,\frac{k_i\,c^I_i}{1-\varepsilon}\left[1-\left(\frac{c^E}{c^I_i}\right)^{1-\varepsilon}\right] + g_i,
\qquad A = \sum_{s=1}^{H}(1+\delta)^{-s}.
$$

Each year, a household replaces its car with probability $\lambda$. If it has not yet
adopted, it then switches if $G_i \ge F_t$. The BEV stock share follows

$$
S_t = S_{t-1} + \lambda \Pr(G_i \ge F_t,\ \text{not adopted}),
$$

so the observed $S_t$ identifies $F_t$ year by year.

The benchmark without selection ("random timing") draws the same number of adopters at
random from the households that replace their car.

## Implication for rebound over time

Both the gain and the rebound rise in the ICEV disutility:

$$
\partial G_i/\partial\psi_i = A\,v_i(c^I_i) > 0, \qquad
\partial r_i/\partial\psi_i = \varepsilon/c^I_i > 0.
$$

With a falling $F_t$, adoption moves to households with a lower $\psi$, so the cohort
rebound declines. The variation in $k_i$ and $g_i$ and the random timing of replacement
weaken this. With a homogeneous $\psi$, the rebound is the same for every cohort.

## Calibration

| Target | Data | Parameter |
|---|---|---|
| BEV share of cars in use, 2015–2026 | StatLine 83703NED, 85405NED; 2025–2026 extended with 85898NED new BEV sales | $F_t$ (exact) |
| rebound of the 2020 cohort = 10 log points | **placeholder, fictitious** | $\varepsilon$ |
| mean km of BEVs / all cars in use, 2024 | StatLine 85405NED | $\sigma_g$ |

The calibration is nested: an outer root search on $\sigma_g$ around an inner root search
on $\varepsilon$, each solving the $F_t$ path. Common random numbers keep the objective
smooth.
