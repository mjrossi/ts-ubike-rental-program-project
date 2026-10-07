# UBike survey analysis
# Run this a few lines at a time (select, then Cmd+Enter). The other .R files
# just define the helpers used here.

# Setup ------------------------------------------------------------------------

library(dplyr)
library(forcats)
library(readxl)

source("survey_codebook.R") # column names and answer labels
source("chart_style.R") # colours and theme for the charts
source("plots.R") # the plot_*() functions

# Data -------------------------------------------------------------------------

survey <- read_excel("./data/TS_Project_SurveyUBike_final (local).xlsx") |>
  label_survey()

# Just the students. fct_match() works like == but stops with an error on a
# typo ("Studnet") instead of quietly returning zero rows.
students <- survey |>
  filter(fct_match(role, "Student"))

View(students)

# Charts -----------------------------------------------------------------------
# These all take any survey table, so plot_modes(students) works too.
# save_chart() also writes each one to output/ as a PNG.

plot_willingness_by(survey, role, "Willingness to use UBike, by role") |>
  save_chart("willingness_by_role")
plot_willingness_by(
  survey,
  urban_cycling,
  "Willingness to use UBike, by urban cycling experience"
) |>
  save_chart("willingness_by_urban_cycling")
plot_willingness_by(
  survey,
  bike_parking_home,
  "Willingness to use UBike, by bike parking at home"
) |>
  save_chart("willingness_by_bike_parking")
plot_willingness_by_distance(survey) |> save_chart("willingness_by_distance")
plot_modes(survey) |> save_chart("modes")
plot_municipalities(survey) |> save_chart("municipalities")
