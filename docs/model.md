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

The cost per km in year $t$ is $c^I_{it} = p^f_t + \psi_i$ for an ICEV and $c^E_t + \kappa$ for
an EV, where $\kappa$ (`ev_hassle`, estimated) is a hassle cost per EV km and

- $p^f_t$ = `fuel_l_per_km` × the annual Euro95 price (StatLine 80416ned);
- $c^E_t$ = `ev_kwh_per_km` × (marginal household electricity price + `charge_markup`). The
  marginal price is the variable delivery tariff plus energy tax and ODE incl. VAT (84672NED,
  85592NED), backcast for 2015–2017 (`R/fetch_prices.R`).

Demand for km has a common elasticity $\varepsilon$ (calibrated), with $k_i$ the km at the
2015 ICEV cost:

$$
v_{it}(c) = k_i\left(\frac{c}{c^I_{i,2015}}\right)^{-\varepsilon}, \qquad
r_{it} = \ln v_{it}(c^E_t + \kappa) - \ln v_{it}(c^I_{it}) = \varepsilon \ln\frac{p^f_t + \psi_i}{c^E_t + \kappa}.
$$

A cohort's rebound is evaluated at the prices of its switch year. Its change over cohorts
combines selection (who switches) and prices (the cost gap in the switch year).

## Adoption

The gain from switching is

$$
G_{it} = A \int_{c^E_t + \kappa}^{c^I_{it}} v_{it}(c)\,dc + \phi(S_{t-1})\,g_i
= A\,\frac{k_i\,(c^I_{i,2015})^{\varepsilon}}{1-\varepsilon}\left[(c^I_{it})^{1-\varepsilon}-(c^E_t + \kappa)^{1-\varepsilon}\right] + \phi(S_{t-1})\,g_i,
\qquad A = \sum_{s=1}^{H}(1+\delta)^{-s},
$$

where $\phi(S) = 0.5^{S/\bar S}$ makes status fade with last year's BEV share, halving with
every $\bar S$ (`status_halving_share`, assumed 0.10).

Each year, a household replaces its car with probability $\lambda$. If it has not yet
adopted, it then switches if $G_{it} \ge F_t$. The net EV premium follows a smooth decline,
lowered by the SEPP purchase subsidy with pass-through $\omega$:

$$
F_t = F_\infty + (F_0 - F_\infty)\,e^{-\gamma (t - 2016)} - \omega\,\text{SEPP}_t ,
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
\partial G_{it}/\partial\psi_i > 0, \qquad
\partial r_{it}/\partial\psi_i = \varepsilon/c^I_{it} > 0.
$$

With a falling $F_t$, adoption moves to households with a lower $\psi$, so the cohort
rebound declines. The variation in $k_i$ and $g_i$ and the random timing of replacement
weaken this. With a homogeneous $\psi$, the rebound is the same for every cohort.

## Calibration

Simulated method of moments (`R/calibrate.R`). Estimated: $\varepsilon$, $\sigma_g$, the
sdlog of $\psi$, $\kappa$, and $F_0, F_\infty, \gamma, \omega$.

The simulator smooths the threshold rule: a household that replaces its car adopts with
probability $\Lambda((G_{it} - F_t)/\tau)$, $\tau$ = `smooth_tau`, and the model tracks
the adopted probability mass per household and cohort. This makes the moments continuous in
the parameters.

| Moment | Data |
|---|---|
| BEV share of cars in use, 2016–2026, relative deviations | StatLine 83703NED, 85405NED; 2025–2026 extended with 85898NED new BEV sales |
| rebound of the 2015 cohort (all adopters up to 2015) = 15 log points | **placeholder, fictitious** |
| rebound of the 2025 cohort = 0 log points | **placeholder, fictitious** |
| mean km of BEVs / all cars in use, 2024 | StatLine 85405NED |

The rebound moments are absolute deviations scaled by 10 log points; the km ratio is a
relative deviation. Both are weighted by 5, so they are matched closely. The
share path is fitted by the premium path and the dispersion of the gain. The objective is
minimised with Nelder–Mead (with one restart) on `n_agents_est` simulated households with common
random numbers; the final results use `n_agents`. The homogeneous-$\psi$ variant is
re-estimated with the sdlog of $\psi$ fixed at 0, so the two fits can be compared. Optionally (`restart = TRUE`, slow), because
the heterogeneous model nests it, the heterogeneous estimation is restarted from the
homogeneous solution, and the better fit is kept.
