# Decision tree ----------------------------------------------------------------
# Task 2 of the brief (docs/project_brief.pdf, section 4 and Figure 1): how
# likely each respondent is to shift to cycling, whatever they answered in Q23.
# Each function adds columns to the survey table, so they chain:
#   survey |> add_tier() |> adjust_tier() |> add_shift_probability()
#
# Needs survey_codebook.R sourced first, and the table from read_survey(): the
# gates use its grouped columns (can_ride, distance_group, floor_group, ...).

library(dplyr)

## Tiers and probabilities -----------------------------------------------------

# The tiers a leaf can give, from least to most likely to shift. adjust_tier()
# moves people one step along this list.
tier_levels <- c("Very low", "Low", "Moderate", "Mod-high", "High")

# Probability of shifting for each tier. These are the brief's scaffold values
# (Figure 1): justify them on the slides or change them.
tier_probabilities <- c(
  "Very low" = 0.05,
  "Low" = 0.20,
  "Moderate" = 0.40,
  "Mod-high" = 0.60,
  "High" = 1.00
)

# Weight for each Q23 answer, used by add_shift_probability(). The names have
# to match the labels in survey_codebook.R. Not decided yet.
willingness_weights <- c(
  "Not Interested" = NA_real_,
  "Unsure" = NA_real_,
  "Yes_electric" = NA_real_,
  "Yes_all bikes" = NA_real_
)

## add_tier() ------------------------------------------------------------------

# Adds tier, a factor with tier_levels, by walking each person through the
# gates. Scaffold from the brief, to adapt:
#   Gate 1   can_ride (Q20)                 no -> Gate 2, yes -> Gate 3
#   Gate 2   distance_km < 5 (Q17)          no -> Very low, yes -> Gate 2a
#   Gate 2a  parking (Q21) and floor (Q22)  no -> Low, yes -> Moderate
#   Gate 3   distance_group                 -> Gate 3a / 3b / 3c
#   Gate 3a  confident (Q20) and parking    no -> Moderate, yes -> High
#   Gate 3b  low floor and not car-only     no -> Low, yes -> Moderate
#   Gate 3c  transit_card (Q16), car-light  no -> Very low, yes -> Low
# Each gate needs its reason against the Hierarchy of Cycling Needs.
add_tier <- function(data) {
  stop("add_tier() is not written yet")
}

## adjust_tier() ---------------------------------------------------------------

# Moves tier one step up or down for the modifier variables (the brief asks
# for at least two, e.g. young_children, intermediate_stop, travel_time_min,
# campus). Kept apart from add_tier() so the slides can compare the plain tree
# with the adjusted one. A tier never goes past "Very low" or "High".
adjust_tier <- function(data) {
  stop("adjust_tier() is not written yet")
}

## add_shift_probability() -----------------------------------------------------

# Adds p_shift, between 0 and 1, from tier_probabilities and the person's Q23
# answer (willingness_weights). Still to decide: how the two combine, e.g.
# multiplied, or the Q23 answer moving the tier.
add_shift_probability <- function(data) {
  stop("add_shift_probability() is not written yet")
}
