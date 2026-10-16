# Decision tree ----------------------------------------------------------------
# Task 2 (brief, section 4 and Figure 1): how likely each person is to shift to
# cycling.
#   survey |> add_tier() |> adjust_tier() |> add_shift_probability()
# Uses the grouped columns from read_survey() (can_ride, distance_group, ...).

library(dplyr)

## Tiers and probabilities -----------------------------------------------------

# Least to most likely to shift
tier_levels <- c("Very low", "Low", "Moderate", "Mod-high", "High")

# Starting values from Figure 1
tier_probabilities <- c(
  "Very low" = 0.05,
  "Low" = 0.20,
  "Moderate" = 0.40,
  "Mod-high" = 0.60,
  "High" = 1.00
)

# Q23 weights for add_shift_probability(). Names match the Q23 labels.
# TODO: pick the values.
willingness_weights <- c(
  "Not Interested" = NA_real_,
  "Unsure" = NA_real_,
  "Yes_electric" = NA_real_,
  "Yes_all bikes" = NA_real_
)

## add_tier() ------------------------------------------------------------------

# Adds tier (a factor with tier_levels). Gates from the brief:
#   Gate 1   can_ride (Q20)                 no -> Gate 2, yes -> Gate 3
#   Gate 2   distance_km < 5 (Q17)          no -> Very low, yes -> Gate 2a
#   Gate 2a  parking (Q21) and floor (Q22)  no -> Low, yes -> Moderate
#   Gate 3   distance_group                 -> Gate 3a / 3b / 3c
#   Gate 3a  confident (Q20) and parking    no -> Moderate, yes -> High
#   Gate 3b  low floor and not car-only     no -> Low, yes -> Moderate
#   Gate 3c  transit_card (Q16), car-light  no -> Very low, yes -> Low
add_tier <- function(data) {
  stop("add_tier() is not written yet")
}

## adjust_tier() ---------------------------------------------------------------

# Moves tier one step up or down for the modifiers (the brief asks for at least
# two, e.g. young_children, intermediate_stop, travel_time_min, campus). Stays
# within "Very low" to "High".
adjust_tier <- function(data) {
  stop("adjust_tier() is not written yet")
}

## add_shift_probability() -----------------------------------------------------

# Adds p_shift (0 to 1) from tier_probabilities and willingness_weights.
# TODO: decide how they combine (multiply, or let Q23 move the tier).
add_shift_probability <- function(data) {
  stop("add_shift_probability() is not written yet")
}
