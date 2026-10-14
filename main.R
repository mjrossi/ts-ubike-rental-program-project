# UBike emission savings
# The project's main script: from the survey to the emissions a shift to
# cycling would save. Run it a few lines at a time (select, then Cmd+Enter).
# The other .R files just define the functions used here; the charts are in
# make_charts.R.

# Setup ------------------------------------------------------------------------

library(dplyr)

source("survey_codebook.R") # read_survey(), column names and answer labels
source("decision_tree.R") # add_tier(), adjust_tier(), add_shift_probability()
source("emission_factors.R") # the g/p.km table for every mode
source("emissions.R") # add_main_mode(), add_current_emissions(), ...

# Data -------------------------------------------------------------------------

survey <- read_survey()

# Decision tree ----------------------------------------------------------------
# Uncomment as the functions get written.

# survey <- survey |>
#   add_tier() |>
#   adjust_tier() |>
#   add_shift_probability()

# Emission factors -------------------------------------------------------------
# occupancy: average passengers per vehicle, from the course Excel file

# factors <- combine_factors(
#   read_mode_factors("./data/<course excel file>.xlsx"),
#   copert_factors("./data/<copert output>", occupancy)
# )

# Emissions --------------------------------------------------------------------

# survey <- survey |>
#   add_main_mode(factors) |>
#   add_current_emissions(factors) |>
#   add_savings()

# total_savings(survey, role)
# total_savings(survey, main_mode)
