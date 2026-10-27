# Model: selection on gains along the EV diffusion curve

This is the technical specification of the model in `R/model.R`. The narrative version, with
derivations and results, is the GitHub Pages site (`docs/index.html`, built from
`docs/index.Rmd`).

## Households

There is a continuum of car-owning households $i$, each with one car. A household's type is

$$
\theta_i = (k_i, \varepsilon_i, \psi_i, h_i, g_i),
$$

where:

| Symbol | Meaning | Distribution |
|---|---|---|
| $k_i$ | annual km driven at the ICEV cost per km | lognormal, mean `km_mean`, sdlog `km_sdlog` |
| $\varepsilon_i$ | price elasticity of km | lognormal, mean `eps_mean` (calibrated), sdlog `eps_sdlog`, capped at `eps_max` < 1 |
| $\psi_i$ | climate disutility per km driven with an ICEV (euro/km) | lognormal, mean `psi_mean`, sdlog `psi_sdlog` |
| $h_i$ | access to home charging | Bernoulli(`home_share`) |
| $g_i$ | lump-sum EV taste: warm glow, range and charging hassle, model fit (PV euro) | $N(0, \sigma_g^2)$, $\sigma_g$ calibrated |

All components are drawn independently. Any selection on one component therefore comes
purely from the adoption rule.

## Driving demand and rebound

The perceived cost per km is

$$
c^I_i = p_f + \psi_i \qquad \text{(ICEV)}, \qquad
c^E_i = h_i\, p_{home} + (1-h_i)\, p_{public} \qquad \text{(EV)}.
$$

The climate disutility $\psi_i$ is a *per-km* moral cost: it falls away when the household
drives electric. Demand has constant elasticity:

$$
v_i(c) = k_i \left(\frac{c}{c^I_i}\right)^{-\varepsilon_i}.
$$

The **rebound** of household $i$ is the log change in km when it switches:

$$
r_i \equiv \ln v_i(c^E_i) - \ln v_i(c^I_i) = \varepsilon_i \ln\frac{c^I_i}{c^E_i}.
$$

## Adoption gain

The annual consumer surplus gain from cheaper km is

$$
\Delta CS_i = \int_{c^E_i}^{c^I_i} v_i(c)\, dc
= \frac{k_i\, c^I_i}{1-\varepsilon_i}\left[1 - \left(\frac{c^E_i}{c^I_i}\right)^{1-\varepsilon_i}\right].
$$

The total gain in present value is

$$
G_i = A\, \Delta CS_i + g_i, \qquad A = \sum_{s=1}^{H} (1+\delta)^{-s}.
$$

## Diffusion (rank / probit model)

- Each year, a household replaces its car with probability $\lambda$ (`replace_rate`),
  independently of its type.
- A household that replaces its car in year $t$ and has not yet adopted switches to an EV if
  $G_i \ge F_t$.
- $F_t$ is the net EV premium: the purchase premium net of subsidies, plus the mean
  non-pecuniary cost. EV adoption is absorbing.

The BEV stock share then evolves as

$$
S_t = S_{t-1} + \lambda \Pr\left(G_i \ge F_t,\ \text{not adopted by } t-1\right).
$$

Given the distribution of $G$, the observed path $S_t$ identifies $F_t$ year by year. This
is the rank/probit model of diffusion (David 1969; Davies 1979): the S-curve is the
distribution of $G$ traced out by a falling threshold.

As a benchmark without selection ("random timing", epidemic/Bass type), the same number of
adopters is drawn at random among the households that replace their car.

## Why rebound falls across cohorts

The adoption gain $G_i$ and the rebound $r_i$ share three components:

| Component | Effect on the gain $\Delta CS_i$ | Effect on the rebound $r_i$ |
|---|---|---|
| $\varepsilon_i$ | $\partial \Delta CS_i/\partial\varepsilon_i > 0$, since $(c/c^I)^{-\varepsilon}$ rises in $\varepsilon$ for $c < c^I$ | $\partial r_i/\partial\varepsilon_i = \ln(c^I/c^E) > 0$ |
| $\psi_i$ | $\partial \Delta CS_i/\partial\psi_i = v_i(c^I_i) > 0$ | $\partial r_i/\partial\psi_i = \varepsilon_i/c^I_i > 0$ |
| $h_i$ | a lower $c^E$ raises both | a lower $c^E$ raises both |

The two remaining components affect only the gain:

- $k_i$ raises $\Delta CS_i$ but leaves the log rebound $r_i$ unchanged.
- $g_i$ shifts $G_i$ but not $r_i$.

Because $G$ and $r$ are positively associated, $E[r \mid G \ge F]$ is increasing in $F$. As
$F_t$ falls, the marginal adopter has a lower rebound, so the mean rebound per cohort
declines. Under random timing, $E[r \mid \text{cohort}] = E[r]$ is flat.

The dispersion of the components that move only $G$ ($k_i$ and $g_i$) weakens the gradient.

## Calibration (`R/calibrate.R`)

| Target | Data | Parameter |
|---|---|---|
| BEV share of passenger cars in use, 2015–2026 | StatLine 83703NED / 85405NED; 2025–2026 extended with new BEV sales from 85898NED | $F_t$, exactly, year by year |
| Mean rebound of the 2020 cohort = 10 log points | **placeholder, fictitious**; to be replaced by the register-data estimates | `eps_mean` |
| Mean km of BEVs in use / all cars in use, 2024 = 1.47 | StatLine 85405NED | $\sigma_g$ (strength of selection) |

The calibration is nested: an outer root search on $\sigma_g$ (km ratio) around an inner
root search on `eps_mean` (rebound). Each evaluation solves the $F_t$ path. Common random
numbers keep the objective smooth.

## Assumed parameters

| Parameter | Value | Note |
|---|---|---|
| `km_mean` | 13,000 | CBS mean annual km of all cars ≈ 12,300 |
| `km_sdlog` | 0.55 | |
| `eps_sdlog` | 0.60 | |
| `c_fuel` | 0.12 €/km | 6.5 l/100 km at 1.85 €/l |
| `psi_mean`, `psi_sdlog` | 0.02 €/km, 1.0 | |
| `c_home`, `c_public` | 0.04, 0.09 €/km | 0.24 and 0.55 €/kWh at 0.17 kWh/km |
| `home_share` | 0.60 | |
| `replace_rate` | 0.12 | |
| `horizon`, `disc` | 8 years, 4% | |
| `n_agents` | 1,000,000 | |
