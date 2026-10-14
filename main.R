# UBike emission savings
# From the survey to the emissions saved by a shift to cycling. The charts are
# in make_charts.R.

# Setup ------------------------------------------------------------------------

library(dplyr)

source("R/survey_codebook.R") # read_survey(), column names and answer labels
source("R/decision_tree.R") # add_tier(), adjust_tier(), add_shift_probability()
source("R/emission_factors.R") # the g/p.km table for every mode
source("R/emissions.R") # add_main_mode(), add_current_emissions(), ...

# Data -------------------------------------------------------------------------

survey <- read_survey()

# Decision tree ----------------------------------------------------------------

# survey <- survey |>
#   add_tier() |>
#   adjust_tier() |>
#   add_shift_probability()

# Emission factors -------------------------------------------------------------

mode_factors <- read_mode_factors(survey_path)
# TODO: placeholder numbers until the COPERT v25 export exists
copert_path <- "./data/copert_placeholder.csv"
factors <- combine_factors(
  mode_factors,
  copert_factors(copert_path, select(mode_factors, mode, occupancy))
)

# Emissions --------------------------------------------------------------------

# TODO: one-way or round trip? Q17 asks for "the travel distance of your
# commuting trip" and the brief (section 5) works in grams per trip, so we
# count one trip as one-way for now. If the brief means a daily commute, use
# trips_per_day = 2.
survey <- survey |>
  add_main_mode(factors) |>
  add_current_emissions(factors, trips_per_day = 1) |>
  add_savings()

total_savings(survey, role)
total_savings(survey, main_mode)
