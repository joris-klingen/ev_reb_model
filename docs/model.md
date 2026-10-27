# Model specification

This is the specification of the model in `R/model.R`. The narrative version is the site,
built from `docs/index.Rmd`.

## Households and driving

A household $i$ owns one car and has type $(k_i, \varepsilon_i, \psi_i, h_i)$. All
components are drawn independently:

| Symbol | Meaning | Distribution |
|---|---|---|
| $k_i$ | annual km with the ICEV | lognormal, mean `km_mean`, sdlog `km_sdlog` (calibrated) |
| $\varepsilon_i$ | price elasticity of km | lognormal, mean `eps_mean` (calibrated), sdlog `eps_sdlog`, capped below 1 |
| $\psi_i$ | climate disutility per km driven with an ICEV | lognormal, mean `psi_mean`, sdlog `psi_sdlog` |
| $h_i$ | access to home charging | Bernoulli(`home_share`) |

The cost per km is

$$
c^I_i = p_f + \psi_i, \qquad c^E_i = h_i\,p_{home} + (1-h_i)\,p_{public}.
$$

Demand for km and the rebound are

$$
v_i(c) = k_i\left(\frac{c}{c^I_i}\right)^{-\varepsilon_i}, \qquad
r_i = \ln v_i(c^E_i) - \ln v_i(c^I_i) = \varepsilon_i \ln\frac{c^I_i}{c^E_i}.
$$

## Adoption

Adoption depends only on the utility from driving. The gain is

$$
G_i = A \int_{c^E_i}^{c^I_i} v_i(c)\,dc
= A\,\frac{k_i\,c^I_i}{1-\varepsilon_i}\left[1-\left(\frac{c^E_i}{c^I_i}\right)^{1-\varepsilon_i}\right],
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

## Cohort gradient

The components $\varepsilon_i$, $\psi_i$ and $h_i$ raise both $G_i$ and $r_i$. The
component $k_i$ raises $G_i$ only. Hence $E[r \mid G \ge F]$ rises in $F$, and with a
falling $F_t$ the mean rebound per cohort declines. Dispersion in $k_i$ and the random
timing of replacement flatten the gradient.

## Calibration

| Target | Data | Parameter |
|---|---|---|
| BEV share of cars in use, 2015–2026 | StatLine 83703NED, 85405NED; 2025–2026 extended with 85898NED new BEV sales | $F_t$ (exact) |
| rebound of the 2020 cohort = 10 log points | **placeholder, fictitious** | `eps_mean` |
| mean km of BEVs / all cars in use, 2024 | StatLine 85405NED | `km_sdlog` |

The calibration is nested: an outer root search on `km_sdlog` around an inner root search
on `eps_mean`, each solving the $F_t$ path. Common random numbers keep the objective
smooth.
