# Method and assumptions

How `main.R` gets from the survey to emission savings: the equations, where
each input comes from, and the choices that change the results.

Brief references are to `docs/project_brief.pdf`.

## Pipeline

```r
survey <- read_survey() |>           # R/survey_codebook.R
  add_tier() |>                      # R/decision_tree.R
  adjust_tier() |>
  add_shift_probability() |>         # p_shift
  add_main_mode(factors) |>          # R/emissions.R
  add_current_emissions(factors) |>
  add_savings()

total_savings(survey, role)
```

`factors` is the emission factor table built in `R/emission_factors.R`.

## 1. Emission factors

Every factor is well-to-wheel, in g/p.km (brief, section 5), for six gases:
CO2, CH4, N2O, CO2eq, NOx and PM.

### Bus, ferry, rail, metro, shuttle, walk, bike

These come from the course workbook's "Emission factors" sheet as they are
(`read_mode_factors()`). Walking and cycling are 0.

### Car, carpool, taxi, motorbike

These come from a COPERT export with one row per vehicle (car, motorbike)
and fuel, in g per vehicle-km (`copert_factors()`). Each row gets its
upstream emissions added and is then divided by the occupancy of each mode
it covers:

$$
EF_{mode,fuel} = \frac{EF^{tailpipe}_{vehicle,fuel} + U_{fuel}}{occupancy_{mode}}
$$

The car rows serve car, carpool and taxi, which differ only in occupancy.
The occupancies come from the workbook: car 1.6, carpool 2.5, taxi 1.4,
motorbike 1.1.

Upstream (well-to-tank) emissions $U$, in g CO2eq/km:

$$
U_{fuel} = \frac{fuel\_g\_km}{1000} \times LHV_{fuel} \times WTT_{fuel}
\qquad
U_{Electric} = kWh\_km \times 119
$$

| Fuel | LHV (MJ/kg) | WTT (g CO2eq/MJ) |
|---|---|---|
| Diesel | 43.1 | 18.9 |
| Petrol | 43.2 | 17.0 |
| LPG | 46.0 | 17.0 (petrol's: LPG isn't on the slide) |

- WTT values are from JRC (2021), as given on L4 slide 69. LHVs are from JEC.
- 119 g CO2eq/kWh is Portugal's 2023 grid intensity (EEA). It covers
  generation only, without grid losses or the upstream emissions of the fuels
  burnt.
- Upstream emissions are only available as CO2eq, so they're added to CO2.
  The workbook does the same for electric rail and metro. CO2eq stays
  correct, but the CO2 column includes a little upstream CH4 and N2O.
- Electric vehicles have zero tailpipe emissions, so all of their emissions
  are upstream.

### CO2eq

$$
CO_2eq = CO_2 + 29.8 \cdot CH_4 + 273 \cdot N_2O
$$

These are the 100-year GWPs from IPCC AR6 (Forster et al., 2021, Table 7.15),
recomputed for every mode, the workbook's included. Tailpipe CH4 comes from
burning fossil fuel, so it uses the fossil CH4 value (29.8) rather than the
non-fossil one (27.0).

The upstream factors (JRC, EEA) are already in CO2eq, computed by their
sources with their own GWPs, so they aren't recomputed.

## 2. Current emissions per respondent

### Main mode

Q14 allows several modes. Following the brief (section 5), each person's
main mode is the one with the highest CO2eq factor (`add_main_mode()`). For
car, carpool and taxi, the highest factor across fuels is used for this
comparison.

Car and motorbike owners (Q12, 290 and 29 people) list only their own vehicle
in Q14, so that is their main mode.

### Factor for each person

The car, carpool, taxi and motorbike factors depend on fuel:

- People with a Q18 fuel get that fuel's row.
- Everyone else gets the average over fuels, weighted by car owners' fuel mix
  (Diesel 176, Petrol 110, LPG 4, Electric 0).

Only Q12 owners answered Q18. So the 129 non-owners whose main mode is car,
carpool, taxi or motorbike all get the average. The one Diesel
motorbike has no COPERT row, so it also gets the average. Since no car owner
reported Electric, that average is the Petrol motorbike factor.

### Emissions

$$
commute\_km = distance\_km \times trips\_per\_day
\qquad
E_{current,gas} = EF_{main\,mode,gas} \times commute\_km
$$

`trips_per_day = 1`: Q17 asks for "the travel distance of your commuting
trip", and the brief (section 5) works in grams per trip. See
[open decisions](#5-open-decisions).

## 3. Probability of shifting

`p_shift` comes from the decision tree (brief, section 4 and Figure 1). It
isn't written yet: the structure, tiers and scaffold probabilities are in
`R/decision_tree.R`.

| Tier | Very low | Low | Moderate | Mod-high | High |
|---|---|---|---|---|---|
| Scaffold P | 0.05 | 0.20 | 0.40 | 0.60 | 1.00 |

- `adjust_tier()` moves a tier up or down one step for the modifiers. The
  brief asks for at least two.
- `add_shift_probability()` combines the tier with a weight for each Q23
  answer. The weights, and how the two combine, are still to be decided.

## 4. Savings

$$
E_{saved,gas} = E_{current,gas} \times p_{shift}
\qquad
km\_shifted = commute\_km \times p_{shift}
\qquad
E_{total} = \sum E_{saved}
$$

`total_savings()` sums these by any grouping, with a count of people. The
brief asks for role (student, faculty, staff); main mode is another option.

Walkers and cyclists add to `km_shifted` (the brief asks for km shifted from
every mode) but save no emissions, since their factors are 0.

## 5. Open decisions

- **Trips per day.** One-way for now. If the brief means a daily commute,
  `trips_per_day = 2` doubles every total.
- **COPERT export.** Car and motorbike factors are placeholders
  (`data/copert_placeholder.csv`). The brief names COPERT 5.3, while the
  `main.R` TODO says v25: confirm which.
- **Decision tree.** Gates, leaf probabilities, at least two modifiers, Q23
  weights and how they combine. Each gate needs a reason based on the
  Hierarchy of Cycling Needs.

## 6. Limitations

- The main-mode rule counts each multimodal commute as entirely its most
  polluting mode, so savings are an upper bound for those people.
- Fuel is known only for owners. Non-owners who use cars get the owners' fuel
  mix.
- Diesel and petrol hybrids are counted as Diesel and Petrol: the sheet's Q18
  codes don't separate them.
- Q19 (vehicle type: city car, SUV, ...) isn't used. COPERT factors are per
  fuel, not per segment.
- Upstream emissions are only available as CO2eq, so CO2 includes some
  upstream CH4 and N2O.
- Q23 codes differ between the brief (Not interested 0, Yes all bikes 1, Yes
  electric 2, Unsure 3) and the sheet header (Not Interested 1, Unsure 2,
  Yes_electric 3, Yes_all bikes 4). The code follows the sheet header.
- The sheet's `Speed (km/h)` doesn't match distance / time for IDs 643 and
  846. Nothing in the pipeline uses it.

## Sources

- Course workbook, "Emission factors" sheet: sheet-mode factors and
  occupancies
- COPERT (EMISIA): car and motorbike tailpipe factors
- JRC (2021), via L4 slide 69: well-to-tank factors
- JEC: lower heating values
- EEA, greenhouse gas emission intensity of electricity generation (Portugal,
  2023):
  <https://www.eea.europa.eu/en/analysis/indicators/greenhouse-gas-emission-intensity-of-1-1751032678/greenhouse-gas-emission-intensity-of-electricity-generation-country-level>
- GWPs, from Table 7.15 (GWP-100: CH4-fossil 29.8 ± 11, N2O 273 ± 130):
  Forster, P. et al. (2021) 'The Earth's energy budget, climate feedbacks,
  and climate sensitivity', in Masson-Delmotte, V. et al. (eds) *Climate
  Change 2021: The Physical Science Basis. Contribution of Working Group I to
  the Sixth Assessment Report of the Intergovernmental Panel on Climate
  Change*. Cambridge: Cambridge University Press, pp. 923–1054.
  doi:10.1017/9781009157896.009.
  <https://www.ipcc.ch/report/ar6/wg1/chapter/chapter-7/>
- Félix, Moura and Clifton (2025): Hierarchy of Cycling Needs (cited in the
  brief's Figure 1)
