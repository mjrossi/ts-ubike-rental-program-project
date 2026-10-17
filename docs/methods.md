# Method and assumptions

How `main.R` gets from the survey to emission savings: the equations, where
each input comes from, and the choices that change the results.

Brief references are to `docs/project_brief.pdf`.

## Pipeline

```r
survey <- read_survey() |>           # R/survey_codebook.R
  score_shift(model_v1) |>           # R/decision_tree.R, R/shift_models.R
  add_main_mode(factors) |>          # R/emissions.R
  add_current_emissions(factors) |>
  add_savings()

total_savings(survey, role)
```

`factors` is the emission factor table from `R/emission_factors.R`. The
sections below follow the order the numbers are needed in: factors (1),
current emissions (2), the probability of shifting (3), then savings (4).

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

$$
p_{shift} = M[\text{tier}, \text{Q23}], \quad
M[t, w] = P_{tier}(t) \times P_{willingness}(w) \text{ to start}
$$

The decision tree places each person in a tier from their circumstances,
leaving out their stated willingness (brief, section 4). $p_{shift}$ is then
the cell of the probability matrix $M$ (`shift_probabilities` in
`R/shift_models.R`) for their tier and Q23 answer. $M$ starts as the product
of the two tables below, and any cell can be set by hand.

| Tier | Very low | Low | Moderate | High | Very high |
|---|---|---|---|---|---|
| $P_{tier}$ | 0.05 | 0.20 | 0.40 | 0.60 | 1.00 |

| Q23 | Not interested | Unsure | Yes, if electric | Yes, any bike |
|---|---|---|---|---|
| $P_{willingness}$ | 0.05 | 0.30 | 0.70 | 1.00 |

Nobody gets 0: the lowest $p_{shift}$ is $0.05 \times 0.05 = 0.0025$.
`check_matrix()` stops on a cell outside 0 to 1, and warns if $p_{shift}$
falls as the tier or willingness rises (the brief asks for coherent
probabilities, section 6, criterion 2).

### The model

A shift model has four parts, each in `R/shift_models.R` and each swappable
on its own: a tree, an optional adjustment (`tree_v1`'s Gate 3), modifiers
picked by name from `modifier_library`, and the matrix. `shift_model()`
checks and bundles them, `score_shift()` runs one, and `compare_models()`
lists the mean $p_{shift}$ and the people per tier for several side by side.

| Model | Tree | Adjustment | Modifiers |
|---|---|---|---|
| `model_v1` | `tree_v1` | Gate 3, `trip_chain_v1` | no parking, age 50+ |
| `model_v2` | `tree_v2` | None | escort stop, age 50+ |
| `model_brief` | `tree_brief` | None | None |

### The trees

The trees are tables in `R/shift_models.R`, and `R/decision_tree.R` walks
them. Each tree lists its gates (the question and the column it reads), its
branches (one row per answer, leading to a gate or a leaf) and its leaves (a
tier). A `reason` column next to each gate, leaf, Gate 3 value and modifier
holds the justification against the Hierarchy of Cycling Needs.

| Tree | Gates | After the tree, in its model |
|---|---|---|
| `tree_v1` | Distance (Q17); urban cycling (Q20); if 15 km+ and able to cycle, rail, metro or ferry (Q14) | Gate 3, trip chain (Q15 × Q12, children's ages Q7–Q11): caps or one tier down. Modifiers: no bike parking (Q21), age 50+ (Q4) |
| `tree_v2` | Distance (Q17); urban cycling (Q20); bike parking (Q21) for everyone under 5 km and for those who cycle at 5 to 15 km; rail, metro or ferry (Q14) for those who cycle at 15 km+ | Modifiers: escort stop (Q15 children or older adults), age 50+ (Q4) |
| `tree_brief` | The brief's Figure 1 scaffold, for comparison | None |

### Adjusting the tier

`adjust_tier()` changes the tree's tier in this order, staying within Very
low to Very high at each step:

1. Gate 3's step (`tree_v1`: one tier down for shopping by car or motorbike,
   or for escorting only children aged 11+).
2. The modifiers: one tier per modifier that applies, net at most one tier.
   Gate 3's step doesn't count toward this limit.
3. Gate 3's cap (`tree_v1`: at most Very low for 2+ children under 11 or
   older adults, at most Low for one child under 11). The cap applies
   last, so it's a true maximum.

The brief asks for ±1-tier modifiers. Gate 3's caps can move someone further
(Very high to Very low), so they need their own justification.

### Answers the gates read

`add_groups()` (R/survey_codebook.R, run by `read_survey()`) derives every
gate's and modifier's input, so the thresholds are in one place. A blank
answer stays blank (except Q20's), and the model stops on it and names the
ids rather than guess. Only Q20 has blanks today.

- Distance bands: under 5, 5 to 15, and 15 km or more (`[0, 5)`, `[5, 15)`,
  `[15, ∞)`). `tree_brief` uses Figure 1's under 5, 5 to 10, and over 10 km.
- The 2 blank Q20 answers count as "No", as in the group's diagrams.
- Bike parking: any answer to Q21 other than "No".
- Rail, metro or ferry: any of the three in Q14.
- Trip chain: shopping counts as a vehicle trip only for car or motorbike
  commuters (Q12). Shopping on foot or by transit is left unchanged.
- Gate 3 (`tree_v1`) is one column, `trip_chain`, with a row per value in
  the tree. 8 people escort children but list none in Q7–Q11. They're treated
  as "1 child under 11", as in the diagram.
- `tree_brief` thresholds that Figure 1 leaves open: a low floor is the 2nd
  or below (Q22); car-light means a commute that isn't only by car;
  confident means Q20 "Yes". Gate 3a's High is for people with one of
  confidence or parking.

`tree_table(tree, survey$path)` lists each gate and leaf with its label,
reason and number of people, for the slides. Each person's `path` column
shows the route that put them in their tier, like `gate1 > gate2a > A3`.

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
- **Decision tree.** `model_v1` or `model_v2` (`main.R` uses `model_v1`). The
  brief's ±1-tier modifiers are children, stops, travel time or campus:
  `model_v2`'s escort stop fits that, while `model_v1` treats children and
  stops as Gate 3 caps and uses bike parking as a modifier. The `reason`
  cells in `R/shift_models.R` are TODOs: each gate, leaf and modifier needs a
  reason based on the Hierarchy of Cycling Needs. Decide whether `tree_v1`'s
  Gate 3 caps stay as caps or become one-tier steps (see
  [Adjusting the tier](#adjusting-the-tier)).

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
