# UBike emission savings
# From the survey to the emissions saved by a shift to cycling. The charts are
# in make_charts.R.

# Setup ------------------------------------------------------------------------

library(dplyr)

source("R/survey_codebook.R") # read_survey(), column names and answer labels
source("R/decision_tree.R") # shift_model(), score_shift(), compare_models()
source("R/shift_models.R") # model_v1, model_v2, model_brief and their parts
source("R/emission_factors.R") # the g/p.km table for every mode
source("R/emissions.R") # add_main_mode(), add_current_emissions(), ...

# Data -------------------------------------------------------------------------

survey <- read_survey()

# Decision tree ----------------------------------------------------------------

# Mean p_shift and people per tier for each model
compare_models(
  survey,
  list(v1 = model_v1, v2 = model_v2, brief = model_brief)
)

# TODO: model_v1 or model_v2? model_brief is the brief's scaffold.
model <- model_v1
survey <- score_shift(survey, model)

# People per gate and leaf, against the diagram
tree_table(model$tree, survey$path)
count(survey, base_tier, tier)

# Emission factors -------------------------------------------------------------

mode_factors <- read_mode_factors(survey_path)
# TODO: placeholder numbers until the COPERT v25 export exists
copert_path <- "data/copert_placeholder.csv"
factors <- combine_factors(
  mode_factors,
  copert_factors(copert_path, select(mode_factors, mode, occupancy))
)

# Emissions --------------------------------------------------------------------

# TODO: one-way or round trip? One-way for now (see docs/methods.md).
# If the brief means a daily commute, use trips_per_day = 2.
survey <- survey |>
  add_main_mode(factors) |>
  add_current_emissions(factors, trips_per_day = 1) |>
  add_savings()

total_savings(survey, role)
total_savings(survey, main_mode)
