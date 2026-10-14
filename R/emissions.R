# Emissions --------------------------------------------------------------------
# Emissions of each person's commute today and how much a shift to cycling
# would save (brief, section 5 "How to Compute Final Weighted Emissions"):
#   E_current = EF_mode * distance
#   E_saved   = E_current * p_shift
# The add_*() functions add columns to the survey table, so they chain:
#   survey |> add_main_mode(factors) |> add_current_emissions(factors) |>
#     add_savings()
#
# factors is the emission factor table from emission_factors.R, and p_shift
# comes from decision_tree.R.

library(dplyr)

# The gases in the factor table, in the order they appear in its columns
gases <- c("co2", "ch4", "n2o", "co2eq", "nox", "pm")

## add_main_mode() -------------------------------------------------------------

# Adds main_mode, the one mode whose emissions count for each person. People
# who come by car or motorbike (private_vehicle, Q12) skipped Q14, so their
# vehicle is the mode. For everyone else it is the Q14 mode with the highest
# co2eq factor, as the brief asks for combined modes (split_modes() lists them).
add_main_mode <- function(data, factors) {
  stop("add_main_mode() is not written yet")
}

## add_current_emissions() -----------------------------------------------------

# Adds current_co2, current_ch4, ... (one per gas): the factor for main_mode
# (and fuel_type for cars) times distance_km, in grams. Still to decide:
# one-way trip or there and back each day.
add_current_emissions <- function(data, factors) {
  stop("add_current_emissions() is not written yet")
}

## add_savings() ---------------------------------------------------------------

# Adds saved_co2, saved_ch4, ...: each current_* column times p_shift.
add_savings <- function(data) {
  stop("add_savings() is not written yet")
}

## total_savings() -------------------------------------------------------------

# Sums the current_* and saved_* columns over groups of people, one row per
# group. Pass the grouping columns without quotes:
#   total_savings(survey, role)
#   total_savings(survey, role, main_mode)
total_savings <- function(data, ...) {
  stop("total_savings() is not written yet")
}
