# Model specification

This is the specification of the model in `R/model.R`. The narrative version with results is
the vignette, [`vignettes/ev_rebound.md`](../vignettes/ev_rebound.md).

**Question:** how does the rebound of ICEV-to-BEV switchers develop as the fleet
electrifies?

## Households and driving

A household $i$ owns one car and has type $(\psi_i, k_i, g_i)$. The key assumption is that
households differ in their disutility of driving an ICEV ($\psi_i$). All components are drawn
independently:

| Symbol | Meaning | Distribution |
|---|---|---|
| $\psi_i$ | disutility per km driven with an ICEV (e.g. climate) | lognormal, mean `psi_mean`, sdlog `psi_sdlog` |
| $k_i$ | annual km with the ICEV | lognormal, mean `km_mean`, sdlog `km_sdlog` |
| $g_i$ | status utility of owning an EV, dispersed across households; fades with EV penetration; does not affect driving | $N(0, \sigma_g^2)$, $\sigma_g$ calibrated |

The cost per km is $c^I_i = p_f + \psi_i$ for an ICEV and $c^E$ for an EV. Demand for km
has a common elasticity $\varepsilon$ (calibrated):

$$
v_i(c) = k_i\left(\frac{c}{c^I_i}\right)^{-\varepsilon}, \qquad
r_i = \ln v_i(c^E) - \ln v_i(c^I_i) = \varepsilon \ln\frac{c^I_i}{c^E}.
$$

## Adoption

The gain from switching is

$$
G_{it} = A \int_{c^E}^{c^I_i} v_i(c)\,dc + \phi(S_{t-1})\,g_i
= A\,\frac{k_i\,c^I_i}{1-\varepsilon}\left[1-\left(\frac{c^E}{c^I_i}\right)^{1-\varepsilon}\right] + \phi(S_{t-1})\,g_i,
\qquad A = \sum_{s=1}^{H}(1+\delta)^{-s},
$$

where $\phi(S) = 0.5^{S/\bar S}$ makes status fade with last year's BEV share, halving with
every $\bar S$ (`status_halving_share`, assumed 0.10).

Each year, a household replaces its car with probability $\lambda$. If it has not yet
adopted, it then switches if $G_{it} \ge F_t$. The net EV premium follows a smooth decline,
lowered by the SEPP purchase subsidy:

$$
F_t = F_\infty + (F_0 - F_\infty)\,e^{-\gamma (t - 2016)} - \text{SEPP}_t ,
$$

and the BEV stock share follows

$$
S_t = S_{t-1} + \lambda \Pr(G_{it} \ge F_t,\ \text{not adopted}).
$$

The benchmark without selection ("random timing") draws the same number of adopters as
observed at random from the households that replace their car.

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

Simulated method of moments (`R/calibrate.R`). Estimated: $\varepsilon$, $\sigma_g$, the
sdlog of $\psi$, and $F_0, F_\infty, \gamma$.

| Moment | Data |
|---|---|
| BEV share of cars in use, 2016–2026, relative deviations | StatLine 83703NED, 85405NED; 2025–2026 extended with 85898NED new BEV sales |
| rebound of the 2015 cohort (all adopters up to 2015) = 10 log points | **placeholder, fictitious** |
| mean km of BEVs / all cars in use, 2024 | StatLine 85405NED |

The rebound and km-ratio moments are weighted by 5, so they are matched almost exactly. The
share path is fitted by the premium path and the dispersion of the gain. The objective is
minimised with Nelder–Mead (with one restart) on 250,000 simulated households with common
random numbers; the final results use 1,000,000. The homogeneous-$\psi$ variant is
re-estimated with the sdlog of $\psi$ fixed at 0, so the two fits can be compared.
